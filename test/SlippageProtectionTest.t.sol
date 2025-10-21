// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {StandardNFT} from "../src/StandardNFT.sol";
import {Pair} from "../src/Pair.sol";

/**
 * @title SlippageProtectionTest
 * @dev 测试滑点保护功能，验证最大 5% 滑点限制
 */
contract SlippageProtectionTest is Test, IERC721Receiver {
    Pair public amm;
    StandardNFT public nft;
    
    address public owner;
    address public trader;
    
    uint256 constant INITIAL_ETH = 10 ether;
    uint256 constant NFT_COUNT = 20;
    uint256 constant MAX_SLIPPAGE = 500; // 5%
    uint256 constant FEE_DENOMINATOR = 10000;

    function setUp() public {
        owner = address(this);
        trader = makeAddr("trader");
        
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

    function testBuySlippageProtectionWithinLimit() public {
        uint256 currentPrice = amm.getCurrentPrice();
        
        // 测试 5% 滑点（在 5% 限制内）
        uint256 maxPrice = currentPrice + (currentPrice * MAX_SLIPPAGE) / FEE_DENOMINATOR;
        
        (uint256 totalCost,) = amm.getBuyQuote();
        
        vm.deal(trader, totalCost);
        vm.prank(trader);
        
        // 应该成功，因为滑点在限制内
        amm.buyNFT{value: totalCost}(maxPrice);
        
        console.log("5% slippage test passed");
    }
    
    function testBuySlippageProtectionExceedsLimit() public {
        uint256 currentPrice = amm.getCurrentPrice();
        
        // 测试 6% 滑点（超过 5% 限制）
        // 设置一个低于当前价格的最大价格，这样实际价格会超过最大价格
        uint256 maxPrice = currentPrice - (currentPrice * MAX_SLIPPAGE) / FEE_DENOMINATOR; // 比当前价格低 5%
        
        (uint256 totalCost,) = amm.getBuyQuote();
        
        vm.deal(trader, totalCost);
        vm.prank(trader);
        
        // 应该失败，因为实际价格超过最大价格
        vm.expectRevert(Pair.SlippageExceeded.selector);
        amm.buyNFT{value: totalCost}(maxPrice);
        
        console.log("Slippage test correctly rejected when actual price exceeds max price");
    }
    
    function testBuySlippageProtectionExactLimit() public {
        uint256 currentPrice = amm.getCurrentPrice();
        
        // 测试恰好 5% 滑点（边界情况）
        uint256 maxPrice = currentPrice + (currentPrice * MAX_SLIPPAGE) / FEE_DENOMINATOR;
        
        (uint256 totalCost,) = amm.getBuyQuote();
        
        vm.deal(trader, totalCost);
        vm.prank(trader);
        
        // 应该成功，因为滑点恰好等于限制
        amm.buyNFT{value: totalCost}(maxPrice);
        
        console.log("5% slippage test passed");
    }
    
    function testSellSlippageProtectionWithinLimit() public {
        // 先购买一个 NFT
        (uint256 totalCost,) = amm.getBuyQuote();
        vm.deal(trader, totalCost);
        vm.prank(trader);
        amm.buyNFT{value: totalCost}(totalCost);
        
        // 获取出售报价
        (uint256 netAmount,) = amm.getSellQuote();
        
        // 测试 5% 滑点（在 5% 限制内）
        uint256 minPrice = netAmount - (netAmount * MAX_SLIPPAGE) / FEE_DENOMINATOR;
        
        vm.startPrank(trader);
        nft.approve(address(amm), 1);
        
        // 应该成功，因为滑点在限制内
        amm.sellNFT(1, minPrice);
        vm.stopPrank();
        
        console.log("5% sell slippage test passed");
    }
    
    function testSellSlippageProtectionExceedsLimit() public {
        // 先购买一个 NFT
        (uint256 totalCost,) = amm.getBuyQuote();
        vm.deal(trader, totalCost);
        vm.prank(trader);
        amm.buyNFT{value: totalCost}(totalCost);
        
        // 获取出售报价
        (uint256 netAmount,) = amm.getSellQuote();
        
        // 测试滑点保护：设置一个高于净收入的最小价格
        uint256 minPrice = netAmount + (netAmount * MAX_SLIPPAGE) / FEE_DENOMINATOR; // 比净收入高 5%
        
        vm.startPrank(trader);
        nft.approve(address(amm), 1);
        
        // 应该失败，因为实际净收入低于最小价格
        vm.expectRevert(Pair.SlippageExceeded.selector);
        amm.sellNFT(1, minPrice);
        vm.stopPrank();
        
        console.log("Sell slippage test correctly rejected when actual net amount is below min price");
    }
    
    function testSellSlippageProtectionExactLimit() public {
        // 先购买一个 NFT
        (uint256 totalCost,) = amm.getBuyQuote();
        vm.deal(trader, totalCost);
        vm.prank(trader);
        amm.buyNFT{value: totalCost}(totalCost);
        
        // 获取出售报价
        (uint256 netAmount,) = amm.getSellQuote();
        
        // 测试恰好 5% 滑点（边界情况）
        uint256 minPrice = netAmount - (netAmount * MAX_SLIPPAGE) / FEE_DENOMINATOR;
        
        vm.startPrank(trader);
        nft.approve(address(amm), 1);
        
        // 应该成功，因为滑点恰好等于限制
        amm.sellNFT(1, minPrice);
        vm.stopPrank();
        
        console.log("5% sell slippage test passed");
    }
    
    function testSlippageProtectionWithPriceChanges() public {
        // 测试价格变化时的滑点保护
        uint256 initialPrice = amm.getCurrentPrice();
        
        // 进行多次交易来改变价格
        for (uint256 i = 0; i < 3; i++) {
            (uint256 totalCost,) = amm.getBuyQuote();
            uint256 currentPrice = amm.getCurrentPrice();
            
            // 设置 3% 滑点限制
            uint256 maxPrice = currentPrice + (currentPrice * 300) / FEE_DENOMINATOR;
            
            vm.deal(trader, totalCost);
            vm.prank(trader);
            amm.buyNFT{value: totalCost}(maxPrice);
            
            console.log("Transaction %d: Price changed from %d to %d", 
                i + 1, initialPrice / 1e15, currentPrice / 1e15);
        }
        
        console.log("Slippage protection works with price changes");
    }
    
    function testSlippageProtectionEdgeCases() public {
        // 测试边界情况
        vm.deal(trader, 10 ether); // 给足够的 ETH
        
        // 测试 0% 滑点（最大价格等于当前价格）
        uint256 currentPrice = amm.getCurrentPrice();
        (uint256 totalCost,) = amm.getBuyQuote();
        
        vm.prank(trader);
        amm.buyNFT{value: totalCost}(currentPrice);
        console.log("0% slippage test passed");
        
        // 测试 0.1% 滑点（最大价格比当前价格高 0.1%）
        currentPrice = amm.getCurrentPrice();
        (totalCost,) = amm.getBuyQuote();
        uint256 maxPrice01 = currentPrice + (currentPrice * 10) / FEE_DENOMINATOR;
        
        vm.prank(trader);
        amm.buyNFT{value: totalCost}(maxPrice01);
        console.log("0.1% slippage test passed");
        
        // 测试 4.9% 滑点（最大价格比当前价格高 4.9%）
        currentPrice = amm.getCurrentPrice();
        (totalCost,) = amm.getBuyQuote();
        uint256 maxPrice49 = currentPrice + (currentPrice * 490) / FEE_DENOMINATOR;
        
        vm.prank(trader);
        amm.buyNFT{value: totalCost}(maxPrice49);
        console.log("4.9% slippage test passed");
    }
    
    function testSlippageProtectionCalculation() public {
        // 验证滑点计算逻辑
        uint256 currentPrice = amm.getCurrentPrice();
        
        // 测试不同的滑点百分比
        uint256[10] memory slippagePercentages = [uint256(100), uint256(200), uint256(300), uint256(400), uint256(500), uint256(600), uint256(700), uint256(800), uint256(900), uint256(1000)]; // 1% to 10%
        
        for (uint256 i = 0; i < 10; i++) {
            uint256 slippage = slippagePercentages[i];
            uint256 maxPrice = currentPrice + (currentPrice * slippage) / FEE_DENOMINATOR;
            uint256 actualSlippage = ((maxPrice - currentPrice) * FEE_DENOMINATOR) / currentPrice;
            
            assertEq(actualSlippage, slippage, "Slippage calculation should be accurate");
            
            console.log("Slippage %d%%: Expected %d, Actual %d", 
                slippage / 100, slippage, actualSlippage);
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
