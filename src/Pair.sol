// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {LPToken} from "./LPToken.sol";

/**
 * @title Pair
 * @dev NFT 与 ETH 的 AMM 交易池合约
 * @author NFT DEX Team
 */
contract Pair is IERC721Receiver, ReentrancyGuard, Ownable, Pausable {
    // 状态变量
    IERC721 public immutable nftContract;
    
    /// @dev 交易手续费 (2% = 200, 10000 = 100%)
    uint256 public constant TRADING_FEE = 200;
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    /// @dev 累积交易费收益 (wei)
    uint256 public accumulatedFees;
    
    /// @dev 池子中的 NFT 数量
    uint256 public nftReserve;
    
    /// @dev LP Token 合约
    LPToken public immutable lpToken;
    
    /// @dev 交易历史记录
    struct Trade {
        address trader;
        bool isBuy; // true = 买入, false = 卖出
        uint256 price;
        uint256 timestamp;
    }
    
    Trade[] public tradeHistory;
    
    // 事件
    event NFTBought(address indexed buyer, uint256 tokenId, uint256 price, uint256 fee);
    event NFTSold(address indexed seller, uint256 tokenId, uint256 price, uint256 fee);
    event PriceUpdated(uint256 newPrice, uint256 ethReserve, uint256 nftReserve);
    event LiquidityAdded(uint256 ethAmount, uint256 nftCount);
    event LPTokensMinted(address indexed to, uint256 amount);
    event LPTokensBurned(address indexed from, uint256 amount);
    event FeesAccumulated(uint256 feeAmount, uint256 totalAccumulatedFees);
    event FeesWithdrawn(address indexed owner, uint256 amount);
    
    // 错误定义
    error InsufficientPayment();
    error InsufficientLiquidity();
    error SlippageExceeded();
    error InvalidTokenId();
    error NotNFTOwner();
    error PoolEmpty();
    
    /**
     * @dev 构造函数
     * @param _nftContract NFT 合约地址
     */
    constructor(address _nftContract) Ownable(msg.sender) {
        nftContract = IERC721(_nftContract);
        
        // 创建独特的 LP Token，基于 NFT 合约地址
        // 由于 IERC721 接口没有 name() 和 symbol() 方法，我们使用合约地址作为标识
        string memory lpName = string(abi.encodePacked("LP-NFT-", _toHexString(_nftContract)));
        string memory lpSymbol = string(abi.encodePacked("LP-", _toHexString(_nftContract)));
        lpToken = new LPToken(lpName, lpSymbol);
    }
    
    /**
     * @dev 添加初始流动性
     * @param nftTokenIds 要添加到池子的 NFT token IDs
     */
    function addInitialLiquidity(uint256[] calldata nftTokenIds) 
        external 
        payable 
        nonReentrant 
    {
        _addInitialLiquidity(nftTokenIds, msg.sender);
    }
    
    
    /**
     * @dev 内部添加初始流动性函数
     * @param nftTokenIds 要添加到池子的 NFT token IDs
     * @param from 转移 NFT 的源地址（用户地址）
     */
    function _addInitialLiquidity(uint256[] calldata nftTokenIds, address from) internal {
        require(nftTokenIds.length > 0, "No NFTs provided");
        require(msg.value > 0, "No ETH provided");
        
        // 转移 NFT 到池子（用户需要预先授权NFT给池子）
        for (uint256 i = 0; i < nftTokenIds.length; i++) {
            nftContract.safeTransferFrom(from, address(this), nftTokenIds[i]);
        }
        
        nftReserve = nftTokenIds.length;
        
        // 计算 LP token 数量（使用几何平均）
        // LP token 数量 = sqrt(ETH_amount * NFT_count)
        uint256 lpAmount = Math.sqrt(msg.value * nftTokenIds.length);
        
        // 铸造 LP token 给流动性提供者
        lpToken.mint(from, lpAmount);
        
        emit LiquidityAdded(msg.value, nftTokenIds.length);
        emit LPTokensMinted(from, lpAmount);
        
        // 优化事件发射 - 减少存储读取，使用净余额
        uint256 netBalance = address(this).balance - accumulatedFees;
        emit PriceUpdated(netBalance / nftReserve, netBalance, nftReserve);
    }
    
    /**
     * @dev 移除流动性
     * @param lpTokenAmount 要销毁的 LP token 数量
     * @param minETH 最小 ETH 数量（滑点保护）
     * @param minNFTs 最小 NFT 数量（滑点保护）
     */
    function removeLiquidity(
        uint256 lpTokenAmount,
        uint256 minETH,
        uint256 minNFTs
    ) external whenNotPaused nonReentrant {
        require(lpTokenAmount > 0, "Amount must be greater than 0");
        require(lpToken.balanceOf(msg.sender) >= lpTokenAmount, "Insufficient LP tokens");
        
        // 计算要移除的 ETH 和 NFT 数量，使用净余额（不包括累积费用）
        uint256 totalLPTokens = lpToken.totalSupply();
        uint256 netBalance = address(this).balance - accumulatedFees;
        uint256 ethToRemove = (netBalance * lpTokenAmount) / totalLPTokens;
        uint256 nftToRemove = (nftReserve * lpTokenAmount) / totalLPTokens;
        
        // 滑点保护
        require(ethToRemove >= minETH, "Insufficient ETH output");
        require(nftToRemove >= minNFTs, "Insufficient NFT output");
        
        // 销毁 LP token
        lpToken.burn(msg.sender, lpTokenAmount);
        
        // 更新储备量
        nftReserve -= nftToRemove;
        
        // 转移 NFT 给用户
        uint256[] memory tokenIds = _getRandomNFTs(nftToRemove);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            nftContract.safeTransferFrom(address(this), msg.sender, tokenIds[i]);
        }
        
        // 转移 ETH 给用户
        payable(msg.sender).transfer(ethToRemove);
        
        emit LPTokensBurned(msg.sender, lpTokenAmount);
        
        // 只有在还有 NFT 储备时才计算价格，重新计算转账后的净余额
        uint256 finalBalance = address(this).balance - accumulatedFees;
        if (nftReserve > 0) {
            emit PriceUpdated(finalBalance / nftReserve, finalBalance, nftReserve);
        } else {
            emit PriceUpdated(0, finalBalance, nftReserve);
        }
    }
    
    /**
     * @dev 购买 NFT
     * @param maxPrice 最大可接受价格（滑点保护）
     */
    function buyNFT(uint256 maxPrice) 
        external 
        payable 
        whenNotPaused 
        nonReentrant 
    {
        _buyNFT(maxPrice, msg.sender);
    }
    
    
    /**
     * @dev 内部购买 NFT 函数
     * @param maxPrice 最大可接受价格（滑点保护）
     * @param buyer 实际购买者地址
     */
    function _buyNFT(uint256 maxPrice, address buyer) internal {
        if (nftReserve == 0) {
            revert PoolEmpty();
        }
        
        // 计算价格时要排除用户刚刚发送的 ETH，并减去累积费用
        uint256 poolBalance = address(this).balance - msg.value - accumulatedFees;
        uint256 currentPrice = poolBalance / nftReserve; // nftReserve 已经检查过不为0
        uint256 fee = (currentPrice * TRADING_FEE) / FEE_DENOMINATOR;
        uint256 totalCost = currentPrice + fee;
        
        
        if (msg.value < totalCost) {
            revert InsufficientPayment();
        }
        
        // 滑点保护：检查实际价格是否超过用户设置的最大价格
        if (currentPrice > maxPrice) {
            revert SlippageExceeded();
        }
        
        // 更新储备量
        nftReserve--;
        
        // 累积交易费收益
        accumulatedFees += fee;
        
        // 记录交易
        tradeHistory.push(Trade({
            trader: buyer,
            isBuy: true,
            price: currentPrice,
            timestamp: block.timestamp
        }));
        
        // 触发累积交易费事件
        emit FeesAccumulated(fee, accumulatedFees);
        
        // 转移 NFT 给买家
        uint256 tokenId = _getFirstNFTInPool();
        nftContract.safeTransferFrom(address(this), buyer, tokenId);
        
        // 退还多余的 ETH（只退还超过 totalCost 的部分）
        // 手续费部分保留在池子中
        if (msg.value > totalCost) {
            payable(buyer).transfer(msg.value - totalCost);
        }
        
        emit NFTBought(buyer, tokenId, currentPrice, fee);
        
        // 优化事件发射 - 减少函数调用，使用净余额
        uint256 netBalance = address(this).balance - accumulatedFees;
        if (nftReserve > 0) {
            emit PriceUpdated(netBalance / nftReserve, netBalance, nftReserve);
        } else {
            emit PriceUpdated(0, netBalance, nftReserve);
        }
    }
    
    /**
     * @dev 出售 NFT
     * @param tokenId 要出售的 NFT token ID
     * @param minPrice 最小可接受价格（滑点保护）
     */
    function sellNFT(uint256 tokenId, uint256 minPrice) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        _sellNFT(tokenId, minPrice, msg.sender);
    }
    
    
    /**
     * @dev 内部出售 NFT 函数
     * @param tokenId 要出售的 NFT token ID
     * @param minPrice 最小可接受价格（滑点保护）
     * @param seller 实际出售者地址
     */
    function _sellNFT(uint256 tokenId, uint256 minPrice, address seller) internal {
        if (nftContract.ownerOf(tokenId) != seller) {
            revert NotNFTOwner();
        }
        
        if (nftReserve == 0) {
            revert PoolEmpty();
        }
        
        uint256 sellPrice = getSellPrice();
        uint256 fee = (sellPrice * TRADING_FEE) / FEE_DENOMINATOR;
        uint256 netAmount = sellPrice - fee;
        
        if (netAmount < minPrice) {
            revert SlippageExceeded();
        }
        
        if (address(this).balance < sellPrice) {
            revert InsufficientLiquidity();
        }
        
        // 更新储备量
        nftReserve++;
        
        // 累积交易费收益
        accumulatedFees += fee;
        
        // 记录交易
        tradeHistory.push(Trade({
            trader: seller,
            isBuy: false,
            price: sellPrice,
            timestamp: block.timestamp
        }));
        
        // 触发累积交易费事件
        emit FeesAccumulated(fee, accumulatedFees);
        
        // 转移 NFT 到池子
        nftContract.safeTransferFrom(seller, address(this), tokenId);
        
        // 支付 ETH 给卖家（扣除手续费）
        // 手续费部分保留在池子中
        payable(seller).transfer(netAmount);
        
        emit NFTSold(seller, tokenId, sellPrice, fee);
        
        // 优化事件发射 - 减少函数调用，使用净余额
        uint256 netBalance = address(this).balance - accumulatedFees;
        emit PriceUpdated(netBalance / nftReserve, netBalance, nftReserve);
    }
    
    /**
     * @dev 获取当前买入价格
     * @return 当前价格 (ETH per NFT)
     */
    function getCurrentPrice() public view returns (uint256) {
        if (nftReserve == 0) {
            return 0;
        }
        // 使用净储备（余额减去累积费用）来计算价格
        uint256 netBalance = address(this).balance - accumulatedFees;
        return netBalance / nftReserve;
    }
    
    /**
     * @dev 获取当前卖出价格
     * @return 当前卖出价格 (ETH per NFT)
     */
    function getSellPrice() public view returns (uint256) {
        if (nftReserve == 0) {
            return 0;
        }
        // 卖出价格略低于买入价格，因为卖出会增加 NFT 储备
        uint256 currentPrice = getCurrentPrice();
        return (currentPrice * nftReserve) / (nftReserve + 1);
    }
    
    /**
     * @dev 获取池子储备量
     * @return ethReserve ETH 储备量（不包括累积费用）
     * @return nftReserveCount NFT 储备量
     */
    function getPoolReserves() external view returns (uint256 ethReserve, uint256 nftReserveCount) {
        // 返回净储备（余额减去累积费用）
        uint256 netBalance = address(this).balance - accumulatedFees;
        return (netBalance, nftReserve);
    }
    
    /**
     * @dev 获取交易历史
     * @return 交易历史数组
     */
    function getTradeHistory() external view returns (Trade[] memory) {
        return tradeHistory;
    }
    
    /**
     * @dev 获取最近的交易记录
     * @param count 要获取的交易数量
     * @return 最近的交易记录
     */
    function getRecentTrades(uint256 count) external view returns (Trade[] memory) {
        uint256 length = tradeHistory.length;
        if (count > length) {
            count = length;
        }
        
        Trade[] memory recentTrades = new Trade[](count);
        for (uint256 i = 0; i < count; i++) {
            recentTrades[i] = tradeHistory[length - 1 - i];
        }
        
        return recentTrades;
    }
    
    /**
     * @dev 获取累积交易费收益
     * @return 累积的交易费收益 (wei)
     */
    function getAccumulatedFees() external view returns (uint256) {
        return accumulatedFees;
    }
    
    /**
     * @dev 获取买入 NFT 的预估价格（包含手续费）
     * @return totalCost 预估总成本
     * @return fee 预估手续费
     */
    function getBuyQuote() external view returns (uint256 totalCost, uint256 fee) {
        uint256 currentPrice = getCurrentPrice();
        fee = (currentPrice * TRADING_FEE) / FEE_DENOMINATOR;
        totalCost = currentPrice + fee;
    }
    
    /**
     * @dev 获取卖出 NFT 的预估价格（扣除手续费）
     * @return netAmount 预估净收入
     * @return fee 预估手续费
     */
    function getSellQuote() external view returns (uint256 netAmount, uint256 fee) {
        uint256 sellPrice = getSellPrice();
        fee = (sellPrice * TRADING_FEE) / FEE_DENOMINATOR;
        netAmount = sellPrice - fee;
    }
    
    /**
     * @dev 暂停合约
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev 恢复合约
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev 提取合约中的 ETH（仅所有者）
     */
    function withdrawETH() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        
        payable(owner()).transfer(balance);
    }
    
    /**
     * @dev 提取累积的交易费收益（仅所有者）
     */
    function withdrawAccumulatedFees() external onlyOwner nonReentrant {
        uint256 fees = accumulatedFees;
        require(fees > 0, "No accumulated fees to withdraw");
        require(address(this).balance >= fees, "Insufficient contract balance");
        
        // 重置累积交易费
        accumulatedFees = 0;
        
        // 转账给所有者
        payable(owner()).transfer(fees);
        
        emit FeesWithdrawn(owner(), fees);
    }
    
    /**
     * @dev 提取合约中的 NFT（仅所有者）
     * @param tokenId NFT token ID
     */
    function withdrawNFT(uint256 tokenId) external onlyOwner nonReentrant {
        nftContract.safeTransferFrom(address(this), owner(), tokenId);
        nftReserve--;
    }
    
    /**
     * @dev 获取池子中的第一个 NFT token ID
     * @return tokenId NFT token ID
     */
    function _getFirstNFTInPool() internal view returns (uint256) {
        // 这里简化实现，实际应该维护一个 NFT 列表
        // 为了演示，我们假设 tokenId 从 1 开始连续编号
        for (uint256 i = 1; i <= 1000; i++) {
            try nftContract.ownerOf(i) returns (address owner) {
                if (owner == address(this)) {
                    return i;
                }
            } catch {
                continue;
            }
        }
        revert InvalidTokenId();
    }
    
    /**
     * @dev 获取池子中的随机 NFT token IDs
     * @param count 要获取的 NFT 数量
     * @return tokenIds NFT token ID 数组
     */
    function _getRandomNFTs(uint256 count) internal view returns (uint256[] memory tokenIds) {
        tokenIds = new uint256[](count);
        uint256 found = 0;
        
        // 这里简化实现，实际应该维护一个 NFT 列表
        // 为了演示，我们假设 tokenId 从 1 开始连续编号
        for (uint256 i = 1; i <= 1000 && found < count; i++) {
            try nftContract.ownerOf(i) returns (address owner) {
                if (owner == address(this)) {
                    tokenIds[found] = i;
                    found++;
                }
            } catch {
                continue;
            }
        }
        
        require(found == count, "Insufficient NFTs in pool");
        return tokenIds;
    }
    
    /**
     * @dev 实现 IERC721Receiver 接口
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
    
    /**
     * @dev 将地址转换为十六进制字符串
     * @param addr 地址
     * @return 十六进制字符串
     */
    function _toHexString(address addr) internal pure returns (string memory) {
        return Strings.toHexString(uint256(uint160(addr)), 20);
    }
    
    /**
     * @dev 接收 ETH
     */
    receive() external payable {
        // 允许接收 ETH
    }
}
