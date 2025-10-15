// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StandardNFT} from "../src/StandardNFT.sol";
import {Pair} from "../src/Pair.sol";
import {MultiPoolManager} from "../src/MultiPoolManager.sol";

/**
 * @title MultiPoolExample
 * @dev 多池系统使用示例
 */
contract MultiPoolExample {
    MultiPoolManager public manager;
    StandardNFT public nft1;
    StandardNFT public nft2;
    
    /**
     * @dev 示例：创建多个池子
     */
    function exampleCreatePools() external payable {
        // 1. 部署池子管理器
        manager = new MultiPoolManager();
        
        // 2. 部署两个 NFT 集合
        nft1 = new StandardNFT(
            "Art Collection",
            "ART",
            "https://api.example.com/art/",
            1000,  // maxSupply
            50,    // maxMintPerAddress
            0.01 ether // mintPrice
        );
        
        nft2 = new StandardNFT(
            "Gaming Collection",
            "GAME",
            "https://api.example.com/game/",
            2000,
            100,
            0.005 ether
        );
        
        // 3. 预铸造 NFT
        nft1.premint(address(this), 20);
        nft2.premint(address(this), 20);
        
        // 4. 准备 token IDs
        uint256[] memory tokenIds = new uint256[](20);
        for (uint256 i = 1; i <= 20; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 5. 授权池子管理器
        for (uint256 i = 1; i <= 20; i++) {
            nft1.approve(address(manager), i);
            nft2.approve(address(manager), i);
        }
        
        // 6. 创建两个池子
        manager.createPool{value: 10 ether}(address(nft1), tokenIds);
        manager.createPool{value: 5 ether}(address(nft2), tokenIds);
    }
    
    /**
     * @dev 示例：购买 NFT
     */
    function exampleBuyNFT() external payable {
        // 1. 获取池子地址
        address pool1Address = manager.getPool(address(nft1));
        Pair pool1 = Pair(payable(pool1Address));
        
        // 2. 获取购买报价
        (uint256 totalCost, uint256 fee) = manager.getBuyQuote(address(nft1));
        
        // 3. 购买 NFT
        pool1.buyNFT{value: totalCost}(totalCost);
    }
    
    /**
     * @dev 示例：出售 NFT
     */
    function exampleSellNFT(uint256 tokenId) external {
        // 1. 获取池子地址
        address pool1Address = manager.getPool(address(nft1));
        Pair pool1 = Pair(payable(pool1Address));
        
        // 2. 获取出售报价
        (uint256 netAmount, uint256 fee) = manager.getSellQuote(address(nft1));
        
        // 3. 授权并出售
        nft1.approve(pool1Address, tokenId);
        pool1.sellNFT(tokenId, netAmount);
    }
    
    /**
     * @dev 示例：查询池子信息
     */
    function exampleQueryPoolInfo() external view returns (
        uint256 pool1Price,
        uint256 pool2Price,
        uint256 pool1EthReserve,
        uint256 pool1NftReserve,
        uint256 pool2EthReserve,
        uint256 pool2NftReserve
    ) {
        // 查询单个池子价格
        pool1Price = manager.getCurrentPrice(address(nft1));
        pool2Price = manager.getCurrentPrice(address(nft2));
        
        // 查询池子储备
        (pool1EthReserve, pool1NftReserve) = manager.getPoolReserves(address(nft1));
        (pool2EthReserve, pool2NftReserve) = manager.getPoolReserves(address(nft2));
    }
    
    /**
     * @dev 示例：暂停和恢复池子
     */
    function examplePauseControl() external {
        // 暂停单个池子
        manager.pausePool(address(nft1));
        
        // 恢复池子
        manager.unpausePool(address(nft1));
        
        // 暂停所有池子
        manager.pauseAllPools();
        
        // 恢复所有池子
        manager.unpauseAllPools();
    }
    
    /**
     * @dev 接收 ETH
     */
    receive() external payable {}
}

