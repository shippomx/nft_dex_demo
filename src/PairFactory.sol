// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {Pair} from "./Pair.sol";

/**
 * @title PairFactory
 * @dev Pair 合约工厂，用于创建和管理 NFT-ETH 交易池
 * @author NFT DEX Team
 */
contract PairFactory is Ownable {
    // 事件
    event PoolCreated(address indexed poolAddress, address indexed nftContract);
    
    // 错误定义
    error PoolAlreadyExists();
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
        
        // 使用 CREATE2 创建新的 AMM 池子
        bytes32 salt = keccak256(abi.encodePacked(nftContract, address(0)));
        
        // 使用 new 操作符配合 salt 进行 CREATE2 部署
        Pair pool = new Pair{salt: salt}(nftContract);
        poolAddress = address(pool);
        
        emit PoolCreated(poolAddress, nftContract);
    }
    
    /**
     * @dev 计算 Pair 合约的 CREATE2 地址
     * @param nftContract NFT 合约地址
     * @return poolAddress 计算出的池子地址
     */
    function getPool(address nftContract) public view returns (address poolAddress) {
        bytes32 salt = keccak256(abi.encodePacked(nftContract, address(0)));
        bytes memory bytecode = abi.encodePacked(type(Pair).creationCode, abi.encode(nftContract));
        poolAddress = Create2.computeAddress(salt, keccak256(bytecode));
    }
}
