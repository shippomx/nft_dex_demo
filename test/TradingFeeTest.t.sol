// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {StandardNFT} from "../src/StandardNFT.sol";
import {Pair} from "../src/Pair.sol";

/**
 * @title TradingFeeTest
 * @dev 测试交易手续费收取功能
 */
contract TradingFeeTest is Test, IERC721Receiver {
    Pair public amm;
    StandardNFT public nft;
    
    address public owner;
    address public buyer;
    address public seller;
    
    uint256 constant INITIAL_ETH = 10 ether;
    uint256 constant NFT_COUNT = 20;
    uint256 constant TRADING_FEE = 200; // 2%
    uint256 constant FEE_DENOMINATOR = 10000;

    function setUp() public {
        owner = address(this);
        buyer = makeAddr("buyer");
        seller = makeAddr("seller");
        
        // 部署 NFT 合约
        nft = new StandardNFT(
            "Test NFT",
            "TNFT",
            "https://api.example.com/",
            1000,
            50,
            0.01 ether
        );
        
        // 部署 AMM 合约
        amm = new Pair(address(nft));
        
        // 预铸造 NFT
        nft.premint(owner, NFT_COUNT);
        
        // 准备 NFT token IDs
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 授权 AMM 合约
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            nft.approve(address(amm), i);
        }
        
        // 添加初始流动性
        amm.addInitialLiquidity{value: INITIAL_ETH}(tokenIds);
    }

    function testTradingFeeOnBuy() public {
        // 记录购买前的池子余额
        uint256 poolBalanceBefore = address(amm).balance;
        
        // 获取购买报价
        (uint256 totalCost, uint256 expectedFee) = amm.getBuyQuote();
        uint256 currentPrice = totalCost - expectedFee;
        
        console.log("Current price:", currentPrice);
        console.log("Expected fee:", expectedFee);
        console.log("Total cost:", totalCost);
        
        // 验证手续费计算正确
        uint256 calculatedFee = (currentPrice * TRADING_FEE) / FEE_DENOMINATOR;
        assertEq(expectedFee, calculatedFee, "Fee calculation should be correct");
        
        // 用户购买 NFT
        vm.deal(buyer, totalCost);
        vm.prank(buyer);
        amm.buyNFT{value: totalCost}(totalCost);
        
        // 记录购买后的池子余额
        uint256 poolBalanceAfter = address(amm).balance;
        
        // 验证池子收到了包含手续费的金额
        uint256 poolReceived = poolBalanceAfter - poolBalanceBefore;
        assertEq(poolReceived, totalCost, "Pool should receive total cost including fee");
        
        // 验证手续费被保留在池子中
        assertTrue(poolReceived > currentPrice, "Pool should receive more than just the price");
        
        console.log("Pool received:", poolReceived);
        console.log("Fee retained:", poolReceived - currentPrice);
    }
    
    function testTradingFeeOnSell() public {
        // 先购买一个 NFT
        (uint256 totalCost,) = amm.getBuyQuote();
        vm.deal(buyer, totalCost);
        vm.prank(buyer);
        amm.buyNFT{value: totalCost}(totalCost);
        
        // 记录出售前的池子余额
        uint256 poolBalanceBefore = address(amm).balance;
        
        // 获取出售报价
        (uint256 netAmount, uint256 expectedFee) = amm.getSellQuote();
        uint256 sellPrice = netAmount + expectedFee;
        
        console.log("Sell price:", sellPrice);
        console.log("Expected fee:", expectedFee);
        console.log("Net amount:", netAmount);
        
        // 验证手续费计算正确
        uint256 calculatedFee = (sellPrice * TRADING_FEE) / FEE_DENOMINATOR;
        assertEq(expectedFee, calculatedFee, "Fee calculation should be correct");
        
        // 用户出售 NFT
        uint256 tokenId = 1; // 假设是第一个 NFT
        vm.startPrank(buyer);
        nft.approve(address(amm), tokenId);
        amm.sellNFT(tokenId, netAmount);
        vm.stopPrank();
        
        // 记录出售后的池子余额
        uint256 poolBalanceAfter = address(amm).balance;
        
        // 验证池子支付了扣除手续费的金额
        uint256 poolPaid = poolBalanceBefore - poolBalanceAfter;
        assertEq(poolPaid, netAmount, "Pool should pay net amount (after fee)");
        
        // 验证手续费被保留在池子中
        assertTrue(sellPrice > netAmount, "Sell price should be more than net amount");
        
        console.log("Pool paid:", poolPaid);
        console.log("Fee retained:", sellPrice - netAmount);
    }
    
    function testFeeAccumulation() public {
        // 记录初始池子余额
        uint256 initialPoolBalance = address(amm).balance;
        
        // 进行多次交易来累积手续费
        uint256 totalFeesCollected = 0;
        
        for (uint256 i = 0; i < 3; i++) {
            // 购买 NFT
            (uint256 totalCost, uint256 fee) = amm.getBuyQuote();
            vm.deal(buyer, totalCost);
            vm.prank(buyer);
            amm.buyNFT{value: totalCost}(totalCost);
            
            totalFeesCollected += fee;
            console.log("Transaction %d fee:", i + 1, fee);
        }
        
        // 记录最终池子余额
        uint256 finalPoolBalance = address(amm).balance;
        
        // 验证手续费被累积
        uint256 poolIncrease = finalPoolBalance - initialPoolBalance;
        assertTrue(poolIncrease > 0, "Pool balance should increase due to fees");
        
        console.log("Total fees collected:", totalFeesCollected);
        console.log("Pool balance increase:", poolIncrease);
        console.log("Fees retained in pool:", poolIncrease);
    }
    
    function testFeePercentage() public {
        // 测试不同价格下的手续费百分比
        uint256[4] memory testPrices = [uint256(1 ether), uint256(2 ether), uint256(5 ether), uint256(10 ether)];
        
        for (uint256 i = 0; i < 4; i++) {
            uint256 price = testPrices[i];
            uint256 expectedFee = (price * TRADING_FEE) / FEE_DENOMINATOR;
            uint256 expectedPercentage = (expectedFee * 10000) / price;
            
            assertEq(expectedPercentage, TRADING_FEE, "Fee percentage should be 2%");
            assertEq(expectedFee, price * 2 / 100, "Fee should be 2% of price");
            
            console.log("Price: %d ETH, Fee: %d ETH, Percentage: %d%%", 
                price / 1e18, expectedFee / 1e18, expectedPercentage / 100);
        }
    }
    
    function testFeeWithDifferentPoolSizes() public {
        // 测试不同池子大小下的手续费
        uint256[4] memory poolSizes = [uint256(5), uint256(10), uint256(20), uint256(50)];
        
        for (uint256 i = 0; i < 4; i++) {
            // 创建新的池子进行测试
            StandardNFT testNft = new StandardNFT(
                string(abi.encodePacked("Test NFT ", i)),
                string(abi.encodePacked("TNFT", i)),
                "https://api.example.com/",
                1000,
                50,
                0.01 ether
            );
            
            Pair testAmm = new Pair(address(testNft));
            
            // 预铸造 NFT
            testNft.premint(owner, poolSizes[i]);
            
            // 准备 token IDs
            uint256[] memory tokenIds = new uint256[](poolSizes[i]);
            for (uint256 j = 1; j <= poolSizes[i]; j++) {
                tokenIds[j - 1] = j;
            }
            
            // 授权
            for (uint256 j = 1; j <= poolSizes[i]; j++) {
                testNft.approve(address(testAmm), j);
            }
            
            // 添加流动性
            testAmm.addInitialLiquidity{value: 10 ether}(tokenIds);
            
            // 获取购买报价
            (uint256 totalCost, uint256 fee) = testAmm.getBuyQuote();
            uint256 price = totalCost - fee;
            uint256 feePercentage = (fee * 10000) / price;
            
            assertEq(feePercentage, TRADING_FEE, "Fee percentage should be 2% regardless of pool size");
            
            console.log("Pool size: %d, Price: %d ETH, Fee: %d ETH", 
                poolSizes[i], price / 1e18, fee / 1e18);
        }
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
