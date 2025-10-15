// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {Pair} from "./Pair.sol";

/**
 * @title MultiPoolManager
 * @dev 管理多个 NFT-ETH 交易池的合约
 * @author NFT DEX Team
 */
contract MultiPoolManager is Ownable, Pausable, ReentrancyGuard, IERC721Receiver {
    // 事件
    event PoolCreated(address indexed poolAddress);
    
    // 错误定义
    error PoolAlreadyExists();
    error PoolNotFound();
    error InvalidNFTContract();
    
    /**
     * @dev 构造函数
     */
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev 为 NFT 合约创建新的交易池
     * @param nftContract NFT 合约地址
     * @return poolAddress 新创建的池子地址
     */
    function createPool(address nftContract) external onlyOwner returns (address poolAddress) {
        if (nftContract == address(0)) {
            revert InvalidNFTContract();
        }
        
        // 计算 Pair 合约的 CREATE2 地址
        poolAddress = getPoolAddress(nftContract);
        
        // 检查池子是否已存在
        if (poolAddress.code.length > 0) {
            revert PoolAlreadyExists();
        }
        
        // 使用 CREATE2 创建新的 AMM 池子
        bytes memory bytecode = abi.encodePacked(type(Pair).creationCode, abi.encode(nftContract));
        address deployedPool = Create2.deploy(0, keccak256(abi.encodePacked(nftContract, address(0))), bytecode);
        
        emit PoolCreated(deployedPool);
    }
    
    /**
     * @dev 计算 Pair 合约的 CREATE2 地址
     * @param nftContract NFT 合约地址
     * @return poolAddress 计算出的池子地址
     */
    function getPoolAddress(address nftContract) public view returns (address poolAddress) {
        bytes memory bytecode = abi.encodePacked(type(Pair).creationCode, abi.encode(nftContract));
        bytes32 salt = keccak256(abi.encodePacked(nftContract, address(0)));
        poolAddress = Create2.computeAddress(salt, keccak256(bytecode));
    }
    
    /**
     * @dev 获取池子信息
     * @param nftContract NFT 合约地址
     * @return poolAddress 池子地址
     * @return ethReserve ETH 储备量
     * @return nftReserve NFT 储备量
     * @return currentPrice 当前价格
     */
    
    
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
        address poolAddress = getPoolAddress(nftContract);
        if (poolAddress.code.length == 0) {
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
        address poolAddress = getPoolAddress(nftContract);
        if (poolAddress.code.length == 0) {
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
        address poolAddress = getPoolAddress(nftContract);
        if (poolAddress.code.length == 0) {
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
        address poolAddress = getPoolAddress(nftContract);
        if (poolAddress.code.length == 0) {
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
        address poolAddress = getPoolAddress(nftContract);
        if (poolAddress.code.length == 0) {
            revert PoolNotFound();
        }
        
        Pair pool = Pair(payable(poolAddress));
        return pool.getPoolReserves();
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
