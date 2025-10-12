// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {StandardNFT} from "../src/StandardNFT.sol";
import {Pair} from "../src/Pair.sol";

/**
 * @title PairTest
 * @dev Pair 合约的测试套件
 */
contract PairTest is Test, IERC721Receiver {
    StandardNFT public nft;
    Pair public amm;
    
    address public owner;
    address public user1;
    address public user2;
    
    // 测试常量
    uint256 constant INITIAL_ETH = 10 ether;
    uint256 constant NFT_COUNT = 20;
    uint256 constant TRADING_FEE = 200; // 2%
    uint256 constant FEE_DENOMINATOR = 10000;
    
    event NFTBought(address indexed buyer, uint256 tokenId, uint256 price, uint256 fee);
    event NFTSold(address indexed seller, uint256 tokenId, uint256 price, uint256 fee);
    event PriceUpdated(uint256 newPrice, uint256 ethReserve, uint256 nftReserve);
    event LiquidityAdded(uint256 ethAmount, uint256 nftCount);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // 部署 NFT 合约
        nft = new StandardNFT(
            "Test NFT",
            "TNFT",
            "https://api.example.com/metadata/",
            1000, // maxSupply
            50,   // maxMintPerAddress
            0.01 ether // mintPrice
        );
        
        // 部署 AMM 合约
        amm = new Pair(address(nft));
        
        // 预铸造 20 个 NFT 给 owner
        nft.premint(owner, NFT_COUNT);
        
        // 准备 NFT token IDs 数组
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 授权 AMM 合约转移 NFT
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            nft.approve(address(amm), i);
        }
        
        // 添加初始流动性
        vm.deal(address(this), INITIAL_ETH);
        amm.addInitialLiquidity{value: INITIAL_ETH}(tokenIds);
    }

    function testInitialState() public view {
        assertEq(amm.nftReserve(), NFT_COUNT);
        assertEq(address(amm).balance, INITIAL_ETH);
        assertEq(amm.getCurrentPrice(), INITIAL_ETH / NFT_COUNT);
    }

    function testBuyNFT() public {
        uint256 initialPrice = amm.getCurrentPrice();
        uint256 expectedPrice = INITIAL_ETH / NFT_COUNT;
        assertEq(initialPrice, expectedPrice);
        
        // 计算购买成本
        (uint256 totalCost, uint256 fee) = amm.getBuyQuote();
        uint256 currentPrice = amm.getCurrentPrice();
        uint256 expectedFee = (currentPrice * TRADING_FEE) / FEE_DENOMINATOR;
        assertEq(fee, expectedFee);
        assertEq(totalCost, currentPrice + expectedFee);
        
        console.log("Expected price:", expectedPrice);
        console.log("Current price:", currentPrice);
        console.log("Total cost:", totalCost);
        console.log("Fee:", fee);
        
        // 用户购买 NFT
        vm.deal(user1, totalCost);
        console.log("User1 balance before:", user1.balance);
        console.log("User1 balance after deal:", user1.balance);
        
        vm.prank(user1);
        amm.buyNFT{value: totalCost}(currentPrice);
        
        // 检查状态更新
        assertEq(amm.nftReserve(), NFT_COUNT - 1);
        // 检查 user1 拥有至少一个 NFT
        assertTrue(nft.balanceOf(user1) > 0);
        // 池子余额应该是初始 ETH + 用户支付的价格（包含手续费）
        assertEq(address(amm).balance, INITIAL_ETH + totalCost);
        
        // 检查价格更新
        uint256 newPrice = amm.getCurrentPrice();
        assertTrue(newPrice > initialPrice);
    }

    function testSellNFT() public {
        // 先购买一个 NFT
        (uint256 totalCost,) = amm.getBuyQuote();
        vm.deal(user1, totalCost);
        vm.prank(user1);
        amm.buyNFT{value: totalCost}(totalCost);
        
        uint256 tokenId = 1;
        assertEq(nft.ownerOf(tokenId), user1);
        
        // 获取卖出报价
        (uint256 netAmount, uint256 fee) = amm.getSellQuote();
        uint256 sellPrice = amm.getSellPrice();
        uint256 expectedFee = (sellPrice * TRADING_FEE) / FEE_DENOMINATOR;
        assertEq(fee, expectedFee);
        assertEq(netAmount, sellPrice - expectedFee);
        
        uint256 userBalanceBefore = user1.balance;
        
        // 用户授权 AMM 合约转移 NFT
        vm.prank(user1);
        nft.approve(address(amm), tokenId);
        
        // 用户出售 NFT
        vm.prank(user1);
        amm.sellNFT(tokenId, netAmount);
        
        // 检查状态更新
        assertEq(amm.nftReserve(), NFT_COUNT);
        assertEq(nft.ownerOf(tokenId), address(amm));
        assertEq(user1.balance, userBalanceBefore + netAmount);
    }

    function testMultipleTrades() public {
        uint256 initialPrice = amm.getCurrentPrice();
        
        // 第一次购买
        (uint256 totalCost1,) = amm.getBuyQuote();
        vm.deal(user1, totalCost1);
        vm.prank(user1);
        amm.buyNFT{value: totalCost1}(totalCost1);
        
        uint256 priceAfterBuy1 = amm.getCurrentPrice();
        assertTrue(priceAfterBuy1 > initialPrice);
        
        // 第二次购买
        (uint256 totalCost2,) = amm.getBuyQuote();
        vm.deal(user2, totalCost2);
        vm.prank(user2);
        amm.buyNFT{value: totalCost2}(totalCost2);
        
        uint256 priceAfterBuy2 = amm.getCurrentPrice();
        assertTrue(priceAfterBuy2 > priceAfterBuy1);
        
        // 出售一个 NFT
        vm.startPrank(user1);
        (uint256 netAmount,) = amm.getSellQuote();
        nft.approve(address(amm), 1);
        amm.sellNFT(1, netAmount);
        vm.stopPrank();
        
        uint256 priceAfterSell = amm.getCurrentPrice();
        assertTrue(priceAfterSell < priceAfterBuy2);
    }

    function testBuyWhenPoolEmpty() public {
        // 购买所有 NFT
        for (uint256 i = 0; i < NFT_COUNT; i++) {
            (uint256 totalCost,) = amm.getBuyQuote();
            address user = makeAddr(string(abi.encodePacked("user", Strings.toString(i))));
            vm.deal(user, totalCost);
            vm.prank(user);
            amm.buyNFT{value: totalCost}(totalCost);
        }
        
        // 尝试购买更多 NFT
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert(Pair.PoolEmpty.selector);
        amm.buyNFT{value: 1 ether}(1 ether);
    }

    function testFeeCalculation() public {
        uint256 initialPrice = amm.getCurrentPrice();
        
        // 购买 NFT
        (uint256 totalCost, uint256 fee) = amm.getBuyQuote();
        uint256 expectedFee = (initialPrice * TRADING_FEE) / FEE_DENOMINATOR;
        assertEq(fee, expectedFee);
        
        vm.deal(user1, totalCost);
        vm.prank(user1);
        amm.buyNFT{value: totalCost}(totalCost);
        
        // 检查手续费是否正确保留在池子中（包含手续费）
        uint256 expectedPoolBalance = INITIAL_ETH + totalCost;
        assertEq(address(amm).balance, expectedPoolBalance);
    }

    function testSlippageProtection() public {
        uint256 currentPrice = amm.getCurrentPrice();
        uint256 maxPrice = currentPrice - 1; // 设置一个低于当前价格的最大价格
        
        (uint256 totalCost,) = amm.getBuyQuote();
        vm.deal(user1, totalCost);
        vm.prank(user1);
        
        vm.expectRevert(Pair.SlippageExceeded.selector);
        amm.buyNFT{value: totalCost}(maxPrice);
    }

    function testSellSlippageProtection() public {
        // 先购买一个 NFT
        (uint256 totalCost,) = amm.getBuyQuote();
        vm.deal(user1, totalCost);
        vm.prank(user1);
        amm.buyNFT{value: totalCost}(totalCost);
        
        // 尝试以过高的最小价格出售
        (uint256 netAmount,) = amm.getSellQuote();
        uint256 minPrice = netAmount + 1; // 设置一个高于净收入的最小价格
        
        vm.startPrank(user1);
        nft.approve(address(amm), 1);
        vm.expectRevert(Pair.SlippageExceeded.selector);
        amm.sellNFT(1, minPrice);
        vm.stopPrank();
    }

    function testInsufficientPayment() public {
        uint256 currentPrice = amm.getCurrentPrice();
        uint256 insufficientAmount = currentPrice / 2; // 支付不足
        
        vm.deal(user1, insufficientAmount);
        vm.prank(user1);
        
        vm.expectRevert(Pair.InsufficientPayment.selector);
        amm.buyNFT{value: insufficientAmount}(currentPrice);
    }

    function testNotNFTOwner() public {
        // 尝试出售不属于自己的 NFT
        vm.prank(user1);
        vm.expectRevert(Pair.NotNFTOwner.selector);
        amm.sellNFT(1, 0);
    }

    function testPauseAndUnpause() public {
        // 暂停合约
        amm.pause();
        assertTrue(amm.paused());
        
        // 尝试在暂停状态下购买
        (uint256 totalCost,) = amm.getBuyQuote();
        vm.deal(user1, totalCost);
        vm.prank(user1);
        
        vm.expectRevert();
        amm.buyNFT{value: totalCost}(totalCost);
        
        // 恢复合约
        amm.unpause();
        assertFalse(amm.paused());
        
        // 现在应该可以正常购买
        vm.prank(user1);
        amm.buyNFT{value: totalCost}(totalCost);
    }

    function testTradeHistory() public {
        // 进行几笔交易
        (uint256 totalCost1,) = amm.getBuyQuote();
        vm.deal(user1, totalCost1);
        vm.prank(user1);
        amm.buyNFT{value: totalCost1}(totalCost1);
        
        vm.startPrank(user1);
        (uint256 netAmount,) = amm.getSellQuote();
        nft.approve(address(amm), 1);
        amm.sellNFT(1, netAmount);
        vm.stopPrank();
        
        // 检查交易历史
        Pair.Trade[] memory history = amm.getTradeHistory();
        assertEq(history.length, 2);
        assertEq(history[0].trader, user1);
        assertTrue(history[0].isBuy);
        assertEq(history[1].trader, user1);
        assertFalse(history[1].isBuy);
    }

    function testGetRecentTrades() public {
        // 进行多笔交易
        for (uint256 i = 0; i < 5; i++) {
            (uint256 totalCost,) = amm.getBuyQuote();
            address user = makeAddr(string(abi.encodePacked("user", Strings.toString(i))));
            vm.deal(user, totalCost);
            vm.prank(user);
            amm.buyNFT{value: totalCost}(totalCost);
        }
        
        // 获取最近 3 笔交易
        Pair.Trade[] memory recentTrades = amm.getRecentTrades(3);
        assertEq(recentTrades.length, 3);
        
        // 检查交易顺序（最新的在前）
        for (uint256 i = 0; i < recentTrades.length - 1; i++) {
            assertTrue(recentTrades[i].timestamp >= recentTrades[i + 1].timestamp);
        }
    }

    function testOwnerFunctions() public {
        // 测试提取 NFT
        uint256 initialNFTCount = amm.nftReserve();
        amm.withdrawNFT(2);
        assertEq(amm.nftReserve(), initialNFTCount - 1);
        assertEq(nft.ownerOf(2), address(this));
        
        // 测试提取 ETH
        uint256 initialBalance = address(this).balance;
        uint256 ammBalance = address(amm).balance;
        amm.withdrawETH();
        assertEq(address(this).balance, initialBalance + ammBalance);
        assertEq(address(amm).balance, 0);
    }

    function testPriceCalculation() public {
        // 测试价格计算逻辑
        uint256 ethReserve = address(amm).balance;
        uint256 nftReserve = amm.nftReserve();
        uint256 expectedPrice = ethReserve / nftReserve;
        
        assertEq(amm.getCurrentPrice(), expectedPrice);
        
        // 测试卖出价格
        uint256 sellPrice = amm.getSellPrice();
        uint256 expectedSellPrice = (expectedPrice * nftReserve) / (nftReserve + 1);
        assertEq(sellPrice, expectedSellPrice);
    }

    function testGasUsage() public {
        // 测试 Gas 使用情况
        (uint256 totalCost,) = amm.getBuyQuote();
        vm.deal(user1, totalCost);
        
        uint256 gasStart = gasleft();
        vm.prank(user1);
        amm.buyNFT{value: totalCost}(totalCost);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for buyNFT:", gasUsed);
        
        // 测试卖出 Gas
        gasStart = gasleft();
        vm.startPrank(user1);
        (uint256 netAmount,) = amm.getSellQuote();
        nft.approve(address(amm), 1);
        amm.sellNFT(1, netAmount);
        vm.stopPrank();
        gasUsed = gasStart - gasleft();
        
        console.log("Gas used for sellNFT:", gasUsed);
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
