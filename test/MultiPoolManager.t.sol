// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {StandardNFT} from "../src/StandardNFT.sol";
import {Pair} from "../src/Pair.sol";
import {PairFactory} from "../src/PairFactory.sol";

/**
 * @title MultiPoolManagerTest
 * @dev 多池管理器的测试套件
 */
contract MultiPoolManagerTest is Test, IERC721Receiver {
    PairFactory public manager;
    StandardNFT public nft1;
    StandardNFT public nft2;
    StandardNFT public nft3;
    
    address public owner;
    address public user1;
    address public user2;
    
    // 测试常量
    uint256 constant INITIAL_ETH = 10 ether;
    uint256 constant NFT_COUNT = 20;
    uint256 constant TRADING_FEE = 200; // 2%
    uint256 constant FEE_DENOMINATOR = 10000;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // 部署池子管理器
        manager = new PairFactory();
        
        // 部署多个 NFT 合约
        nft1 = new StandardNFT(
            "Collection 1",
            "C1",
            "https://api.example.com/collection1/",
            1000,
            50,
            0.01 ether
        );
        
        nft2 = new StandardNFT(
            "Collection 2", 
            "C2",
            "https://api.example.com/collection2/",
            1000,
            50,
            0.01 ether
        );
        
        nft3 = new StandardNFT(
            "Collection 3",
            "C3", 
            "https://api.example.com/collection3/",
            1000,
            50,
            0.01 ether
        );
        
        // 预铸造 NFT
        nft1.premint(owner, NFT_COUNT);
        nft2.premint(owner, NFT_COUNT);
        nft3.premint(owner, NFT_COUNT);
        
        // 准备 NFT token IDs
        uint256[] memory tokenIds1 = new uint256[](NFT_COUNT);
        uint256[] memory tokenIds2 = new uint256[](NFT_COUNT);
        uint256[] memory tokenIds3 = new uint256[](NFT_COUNT);
        
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds1[i - 1] = i;
            tokenIds2[i - 1] = i;
            tokenIds3[i - 1] = i;
        }
        
        // 授权池子管理器（在创建池子之前）
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            nft1.approve(address(manager), i);
            nft2.approve(address(manager), i);
            nft3.approve(address(manager), i);
        }
    }

    function testCreatePool() public {
        // 准备 NFT token IDs
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 创建第一个池子
        // 注意：池子管理器已经被授权，现在可以转移 NFT
        manager.createPool{value: INITIAL_ETH}(address(nft1), tokenIds);
        
        // 验证池子创建
        address pool1 = manager.getPool(address(nft1));
        assertTrue(pool1 != address(0));
        
        // 验证池子状态
        (uint256 ethReserve, uint256 nftReserve) = manager.getPoolReserves(address(nft1));
        assertEq(ethReserve, INITIAL_ETH);
        assertEq(nftReserve, NFT_COUNT);
        
        uint256 currentPrice = manager.getCurrentPrice(address(nft1));
        assertEq(currentPrice, INITIAL_ETH / NFT_COUNT);
    }

    function testCreateMultiplePools() public {
        // 准备 NFT token IDs
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 创建三个池子
        manager.createPool{value: INITIAL_ETH}(address(nft1), tokenIds);
        manager.createPool{value: INITIAL_ETH}(address(nft2), tokenIds);
        manager.createPool{value: INITIAL_ETH}(address(nft3), tokenIds);
        
        // 验证池子地址不同
        address pool1 = manager.getPool(address(nft1));
        address pool2 = manager.getPool(address(nft2));
        address pool3 = manager.getPool(address(nft3));
        
        assertTrue(pool1 != pool2);
        assertTrue(pool2 != pool3);
        assertTrue(pool1 != pool3);
    }

    function testBuyNFTThroughManager() public {
        // 创建池子
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        manager.createPool{value: INITIAL_ETH}(address(nft1), tokenIds);
        
        // 获取购买报价
        (uint256 totalCost, uint256 fee) = manager.getBuyQuote(address(nft1));
        uint256 currentPrice = manager.getCurrentPrice(address(nft1));
        uint256 expectedFee = (currentPrice * TRADING_FEE) / FEE_DENOMINATOR;
        assertEq(fee, expectedFee);
        assertEq(totalCost, currentPrice + expectedFee);
        
        // 用户直接与池子交互购买 NFT
        address poolAddress = manager.getPool(address(nft1));
        Pair pool = Pair(payable(poolAddress));
        
        vm.deal(user1, totalCost);
        vm.prank(user1);
        pool.buyNFT{value: totalCost}(totalCost);
        
        // 验证购买结果
        assertTrue(nft1.balanceOf(user1) > 0);
        (uint256 ethReserve, uint256 nftReserve) = manager.getPoolReserves(address(nft1));
        assertEq(nftReserve, NFT_COUNT - 1);
    }

    function testSellNFTThroughManager() public {
        // 创建池子
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        manager.createPool{value: INITIAL_ETH}(address(nft1), tokenIds);
        
        // 获取池子地址
        address poolAddress = manager.getPool(address(nft1));
        Pair pool = Pair(payable(poolAddress));
        
        // 先购买一个 NFT
        (uint256 totalCost,) = manager.getBuyQuote(address(nft1));
        vm.deal(user1, totalCost);
        vm.prank(user1);
        pool.buyNFT{value: totalCost}(totalCost);
        
        // 获取出售报价
        (uint256 netAmount, uint256 fee) = manager.getSellQuote(address(nft1));
        uint256 sellPrice = manager.getSellPrice(address(nft1));
        uint256 expectedFee = (sellPrice * TRADING_FEE) / FEE_DENOMINATOR;
        assertEq(fee, expectedFee);
        assertEq(netAmount, sellPrice - expectedFee);
        
        // 用户出售 NFT
        uint256 tokenId = 1; // 假设购买的是第一个 NFT
        vm.startPrank(user1);
        nft1.approve(poolAddress, tokenId);
        pool.sellNFT(tokenId, netAmount);
        vm.stopPrank();
        
        // 验证出售结果
        assertEq(nft1.ownerOf(tokenId), manager.getPool(address(nft1)));
        (uint256 ethReserve, uint256 nftReserve) = manager.getPoolReserves(address(nft1));
        assertEq(nftReserve, NFT_COUNT);
    }

    function testMultiplePoolTrading() public {
        // 创建多个池子
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        manager.createPool{value: INITIAL_ETH}(address(nft1), tokenIds);
        manager.createPool{value: INITIAL_ETH}(address(nft2), tokenIds);
        
        // 获取池子地址
        address pool1Address = manager.getPool(address(nft1));
        address pool2Address = manager.getPool(address(nft2));
        Pair pool1 = Pair(payable(pool1Address));
        Pair pool2 = Pair(payable(pool2Address));
        
        // 在不同池子中进行交易
        (uint256 totalCost1,) = manager.getBuyQuote(address(nft1));
        (uint256 totalCost2,) = manager.getBuyQuote(address(nft2));
        
        vm.deal(user1, totalCost1 + totalCost2);
        vm.startPrank(user1);
        pool1.buyNFT{value: totalCost1}(totalCost1);
        pool2.buyNFT{value: totalCost2}(totalCost2);
        vm.stopPrank();
        
        // 验证两个池子的状态
        assertTrue(nft1.balanceOf(user1) > 0);
        assertTrue(nft2.balanceOf(user1) > 0);
        
        (uint256 ethReserve1, uint256 nftReserve1) = manager.getPoolReserves(address(nft1));
        (uint256 ethReserve2, uint256 nftReserve2) = manager.getPoolReserves(address(nft2));
        
        assertEq(nftReserve1, NFT_COUNT - 1);
        assertEq(nftReserve2, NFT_COUNT - 1);
        assertTrue(ethReserve1 > INITIAL_ETH);
        assertTrue(ethReserve2 > INITIAL_ETH);
    }

    function testPoolAlreadyExists() public {
        // 创建池子
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        manager.createPool{value: INITIAL_ETH}(address(nft1), tokenIds);
        
        // 尝试为同一个 NFT 合约创建另一个池子应该失败
        vm.expectRevert(PairFactory.PoolAlreadyExists.selector);
        manager.createPool{value: INITIAL_ETH}(address(nft1), tokenIds);
    }

    function testPoolNotFound() public {
        // 尝试获取不存在的池子应该失败
        vm.expectRevert(PairFactory.PoolNotFound.selector);
        manager.getPool(address(nft1));
        
        vm.expectRevert(PairFactory.PoolNotFound.selector);
        manager.getCurrentPrice(address(nft1));
        
        vm.expectRevert(PairFactory.PoolNotFound.selector);
        manager.getPoolReserves(address(nft1));
    }

    function testGasUsage() public {
        // 创建池子
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        uint256 gasStart = gasleft();
        manager.createPool{value: INITIAL_ETH}(address(nft1), tokenIds);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for createPool:", gasUsed);
        
        // 测试购买 Gas
        address poolAddress = manager.getPool(address(nft1));
        Pair pool = Pair(payable(poolAddress));
        
        (uint256 totalCost,) = manager.getBuyQuote(address(nft1));
        vm.deal(user1, totalCost);
        
        gasStart = gasleft();
        vm.prank(user1);
        pool.buyNFT{value: totalCost}(totalCost);
        gasUsed = gasStart - gasleft();
        
        console.log("Gas used for buyNFT through pool:", gasUsed);
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
    receive() external payable {}
}
