// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pair} from "./Pair.sol";

/**
 * @title MultiPoolManager
 * @dev 管理多个 NFT-ETH 交易池的合约
 * @author NFT DEX Team
 */
contract MultiPoolManager is Ownable, Pausable, ReentrancyGuard, IERC721Receiver {
    // 状态变量
    mapping(address => address) public nftToPool; // NFT 合约地址 => AMM 池子地址
    mapping(address => bool) public isPool; // 验证是否为有效的池子
    address[] public pools; // 所有池子的地址列表
    
    // 事件
    event PoolCreated(address indexed nftContract, address indexed poolAddress, uint256 poolIndex);
    event PoolRemoved(address indexed nftContract, address indexed poolAddress);
    event PoolUpdated(address indexed nftContract, address indexed oldPool, address indexed newPool);
    
    // 错误定义
    error PoolAlreadyExists();
    error PoolNotFound();
    error InvalidPool();
    error PoolNotActive();
    error InvalidNFTContract();
    
    /**
     * @dev 构造函数
     */
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev 为 NFT 合约创建新的交易池
     * @param nftContract NFT 合约地址
     * @param nftTokenIds 要添加到池子的 NFT token IDs
     * @return poolAddress 新创建的池子地址
     */
    function createPool(
        address nftContract,
        uint256[] calldata nftTokenIds
    ) external payable onlyOwner nonReentrant returns (address poolAddress) {
        if (nftContract == address(0)) {
            revert InvalidNFTContract();
        }
        
        if (nftToPool[nftContract] != address(0)) {
            revert PoolAlreadyExists();
        }
        
        if (msg.value == 0) {
            revert InvalidAmount();
        }
        
        // 创建新的 AMM 池子
        Pair newPool = new Pair(nftContract);
        poolAddress = address(newPool);
        
        // 设置池子管理器
        // 池子管理器功能已移除，直接使用所有者权限
        
        // 记录池子信息
        nftToPool[nftContract] = poolAddress;
        isPool[poolAddress] = true;
        pools.push(poolAddress);
        
        // 将 NFT 从调用者转移到池子管理器
        IERC721 nft = IERC721(nftContract);
        for (uint256 i = 0; i < nftTokenIds.length; i++) {
            nft.safeTransferFrom(msg.sender, address(this), nftTokenIds[i]);
        }
        
        // 授权池子转移 NFT
        for (uint256 i = 0; i < nftTokenIds.length; i++) {
            nft.approve(poolAddress, nftTokenIds[i]);
        }
        
        // 添加初始流动性（从池子管理器）
        newPool.addInitialLiquidity{value: msg.value}(nftTokenIds);
        
        emit PoolCreated(nftContract, poolAddress, pools.length - 1);
    }
    
    /**
     * @dev 获取 NFT 合约对应的池子地址
     * @param nftContract NFT 合约地址
     * @return poolAddress 池子地址
     */
    function getPool(address nftContract) external view returns (address poolAddress) {
        poolAddress = nftToPool[nftContract];
        if (poolAddress == address(0)) {
            revert PoolNotFound();
        }
    }
    
    /**
     * @dev 检查 NFT 合约是否有对应的池子
     * @param nftContract NFT 合约地址
     * @return exists 是否存在池子
     */
    function hasPool(address nftContract) external view returns (bool exists) {
        return nftToPool[nftContract] != address(0);
    }
    
    /**
     * @dev 获取所有池子地址
     * @return allPools 所有池子地址数组
     */
    function getAllPools() external view returns (address[] memory allPools) {
        return pools;
    }
    
    /**
     * @dev 获取池子数量
     * @return count 池子数量
     */
    function getPoolCount() external view returns (uint256 count) {
        return pools.length;
    }
    
    /**
     * @dev 获取池子信息
     * @param nftContract NFT 合约地址
     * @return poolAddress 池子地址
     * @return ethReserve ETH 储备量
     * @return nftReserve NFT 储备量
     * @return currentPrice 当前价格
     */
    function getPoolInfo(address nftContract) 
        external 
        view 
        returns (
            address poolAddress,
            uint256 ethReserve,
            uint256 nftReserve,
            uint256 currentPrice
        ) 
    {
        poolAddress = nftToPool[nftContract];
        if (poolAddress == address(0)) {
            revert PoolNotFound();
        }
        
        Pair pool = Pair(payable(poolAddress));
        (ethReserve, nftReserve) = pool.getPoolReserves();
        currentPrice = pool.getCurrentPrice();
    }
    
    /**
     * @dev 获取多个池子的信息
     * @param nftContracts NFT 合约地址数组
     * @return poolAddresses 池子地址数组
     * @return ethReserves ETH 储备量数组
     * @return nftReserves NFT 储备量数组
     * @return currentPrices 当前价格数组
     */
    function getMultiplePoolInfo(address[] calldata nftContracts)
        external
        view
        returns (
            address[] memory poolAddresses,
            uint256[] memory ethReserves,
            uint256[] memory nftReserves,
            uint256[] memory currentPrices
        )
    {
        uint256 length = nftContracts.length;
        poolAddresses = new address[](length);
        ethReserves = new uint256[](length);
        nftReserves = new uint256[](length);
        currentPrices = new uint256[](length);
        
        for (uint256 i = 0; i < length; i++) {
            address poolAddress = nftToPool[nftContracts[i]];
            if (poolAddress != address(0)) {
                Pair pool = Pair(payable(poolAddress));
                poolAddresses[i] = poolAddress;
                (ethReserves[i], nftReserves[i]) = pool.getPoolReserves();
                currentPrices[i] = pool.getCurrentPrice();
            }
        }
    }
    
    
    /**
     * @dev 获取购买报价
     * @param nftContract NFT 合约地址
     * @return totalCost 预估总成本
     * @return fee 预估手续费
     */
    function getBuyQuote(address nftContract) 
        external 
        view 
        returns (uint256 totalCost, uint256 fee) 
    {
        address poolAddress = nftToPool[nftContract];
        if (poolAddress == address(0)) {
            revert PoolNotFound();
        }
        
        Pair pool = Pair(payable(poolAddress));
        return pool.getBuyQuote();
    }
    
    /**
     * @dev 获取出售报价
     * @param nftContract NFT 合约地址
     * @return netAmount 预估净收入
     * @return fee 预估手续费
     */
    function getSellQuote(address nftContract) 
        external 
        view 
        returns (uint256 netAmount, uint256 fee) 
    {
        address poolAddress = nftToPool[nftContract];
        if (poolAddress == address(0)) {
            revert PoolNotFound();
        }
        
        Pair pool = Pair(payable(poolAddress));
        return pool.getSellQuote();
    }
    
    /**
     * @dev 获取当前价格
     * @param nftContract NFT 合约地址
     * @return currentPrice 当前价格
     */
    function getCurrentPrice(address nftContract) 
        external 
        view 
        returns (uint256 currentPrice) 
    {
        address poolAddress = nftToPool[nftContract];
        if (poolAddress == address(0)) {
            revert PoolNotFound();
        }
        
        Pair pool = Pair(payable(poolAddress));
        return pool.getCurrentPrice();
    }
    
    /**
     * @dev 获取卖出价格
     * @param nftContract NFT 合约地址
     * @return sellPrice 卖出价格
     */
    function getSellPrice(address nftContract) 
        external 
        view 
        returns (uint256 sellPrice) 
    {
        address poolAddress = nftToPool[nftContract];
        if (poolAddress == address(0)) {
            revert PoolNotFound();
        }
        
        Pair pool = Pair(payable(poolAddress));
        return pool.getSellPrice();
    }
    
    /**
     * @dev 获取池子储备量
     * @param nftContract NFT 合约地址
     * @return ethReserve ETH 储备量
     * @return nftReserve NFT 储备量
     */
    function getPoolReserves(address nftContract) 
        external 
        view 
        returns (uint256 ethReserve, uint256 nftReserve) 
    {
        address poolAddress = nftToPool[nftContract];
        if (poolAddress == address(0)) {
            revert PoolNotFound();
        }
        
        Pair pool = Pair(payable(poolAddress));
        return pool.getPoolReserves();
    }
    
    /**
     * @dev 暂停所有池子
     */
    function pauseAllPools() external onlyOwner {
        _pause();
        
        // 暂停所有池子
        for (uint256 i = 0; i < pools.length; i++) {
            Pair pool = Pair(payable(pools[i]));
            pool.pause();
        }
    }
    
    /**
     * @dev 恢复所有池子
     */
    function unpauseAllPools() external onlyOwner {
        _unpause();
        
        // 恢复所有池子
        for (uint256 i = 0; i < pools.length; i++) {
            Pair pool = Pair(payable(pools[i]));
            pool.unpause();
        }
    }
    
    /**
     * @dev 暂停特定池子
     * @param nftContract NFT 合约地址
     */
    function pausePool(address nftContract) external onlyOwner {
        address poolAddress = nftToPool[nftContract];
        if (poolAddress == address(0)) {
            revert PoolNotFound();
        }
        
        Pair pool = Pair(payable(poolAddress));
        pool.pause();
    }
    
    /**
     * @dev 恢复特定池子
     * @param nftContract NFT 合约地址
     */
    function unpausePool(address nftContract) external onlyOwner {
        address poolAddress = nftToPool[nftContract];
        if (poolAddress == address(0)) {
            revert PoolNotFound();
        }
        
        Pair pool = Pair(payable(poolAddress));
        pool.unpause();
    }
    
    /**
     * @dev 移除池子（仅所有者）
     * @param nftContract NFT 合约地址
     */
    function removePool(address nftContract) external onlyOwner {
        address poolAddress = nftToPool[nftContract];
        if (poolAddress == address(0)) {
            revert PoolNotFound();
        }
        
        // 从映射中移除
        delete nftToPool[nftContract];
        delete isPool[poolAddress];
        
        // 从数组中移除（简化实现，保持顺序）
        for (uint256 i = 0; i < pools.length; i++) {
            if (pools[i] == poolAddress) {
                pools[i] = pools[pools.length - 1];
                pools.pop();
                break;
            }
        }
        
        emit PoolRemoved(nftContract, poolAddress);
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
     * @dev 接收 ETH
     */
    receive() external payable {
        // 允许接收 ETH
    }
    
    // 错误定义
    error InvalidAmount();
}
