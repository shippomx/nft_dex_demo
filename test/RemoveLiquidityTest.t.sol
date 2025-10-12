// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StandardNFT} from "../src/StandardNFT.sol";
import {Pair} from "../src/Pair.sol";

/**
 * @title RemoveLiquidityTest
 * @dev 测试移除流动性和 LP token 销毁功能
 */
contract RemoveLiquidityTest is Test, IERC721Receiver {
    Pair public amm;
    StandardNFT public nft;
    IERC20 public lpToken;
    
    address public owner;
    address public liquidityProvider;
    
    uint256 constant INITIAL_ETH = 10 ether;
    uint256 constant NFT_COUNT = 20;

    function setUp() public {
        owner = address(this);
        liquidityProvider = makeAddr("liquidityProvider");
        
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
        lpToken = amm.lpToken();
        
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

    function testRemoveLiquidityBurnsLPTokens() public {
        // 记录移除流动性前的状态
        uint256 lpBalanceBefore = lpToken.balanceOf(owner);
        uint256 totalSupplyBefore = lpToken.totalSupply();
        uint256 ethBalanceBefore = owner.balance;
        uint256 nftBalanceBefore = nft.balanceOf(owner);
        
        console.log("LP balance before:", lpBalanceBefore);
        console.log("Total supply before:", totalSupplyBefore);
        
        // 移除一半的流动性
        uint256 lpToRemove = lpBalanceBefore / 2;
        
        // 计算期望的 ETH 和 NFT 数量
        uint256 expectedETH = (INITIAL_ETH * lpToRemove) / totalSupplyBefore;
        uint256 expectedNFTs = (NFT_COUNT * lpToRemove) / totalSupplyBefore;
        
        console.log("Removing LP tokens:", lpToRemove);
        console.log("Expected ETH:", expectedETH);
        console.log("Expected NFTs:", expectedNFTs);
        
        // 监听 LPTokensBurned 事件
        vm.expectEmit(false, false, false, true);
        emit Pair.LPTokensBurned(owner, lpToRemove);
        
        // 移除流动性
        amm.removeLiquidity(lpToRemove, expectedETH * 95 / 100, expectedNFTs * 95 / 100);
        
        // 验证 LP token 被销毁
        uint256 lpBalanceAfter = lpToken.balanceOf(owner);
        uint256 totalSupplyAfter = lpToken.totalSupply();
        
        assertEq(lpBalanceAfter, lpBalanceBefore - lpToRemove, "LP balance should decrease");
        assertEq(totalSupplyAfter, totalSupplyBefore - lpToRemove, "Total supply should decrease");
        
        // 验证收到 ETH 和 NFT
        assertTrue(owner.balance > ethBalanceBefore, "Should receive ETH");
        assertTrue(nft.balanceOf(owner) > nftBalanceBefore, "Should receive NFTs");
        
        console.log("LP balance after:", lpBalanceAfter);
        console.log("Total supply after:", totalSupplyAfter);
        console.log("ETH received:", owner.balance - ethBalanceBefore);
        console.log("NFTs received:", nft.balanceOf(owner) - nftBalanceBefore);
    }
    
    function testRemoveAllLiquidity() public {
        uint256 lpBalance = lpToken.balanceOf(owner);
        uint256 totalSupply = lpToken.totalSupply();
        
        console.log("Removing all liquidity");
        console.log("LP balance:", lpBalance);
        console.log("Total supply:", totalSupply);
        
        // 计算期望的 ETH 和 NFT 数量
        uint256 expectedETH = (INITIAL_ETH * lpBalance) / totalSupply;
        uint256 expectedNFTs = (NFT_COUNT * lpBalance) / totalSupply;
        
        // 监听 LPTokensBurned 事件
        vm.expectEmit(false, false, false, true);
        emit Pair.LPTokensBurned(owner, lpBalance);
        
        // 移除所有流动性
        amm.removeLiquidity(lpBalance, expectedETH * 95 / 100, expectedNFTs * 95 / 100);
        
        // 验证所有 LP token 被销毁
        assertEq(lpToken.balanceOf(owner), 0, "All LP tokens should be burned");
        assertEq(lpToken.totalSupply(), 0, "Total supply should be zero");
        
        console.log("All LP tokens burned successfully");
    }
    
    function testRemoveLiquidityInsufficientTokens() public {
        uint256 lpBalance = lpToken.balanceOf(owner);
        
        // 尝试移除超过持有的 LP token 数量
        vm.expectRevert("Insufficient LP tokens");
        amm.removeLiquidity(lpBalance + 1, 0, 0);
    }
    
    function testRemoveLiquiditySlippageProtection() public {
        uint256 lpBalance = lpToken.balanceOf(owner);
        uint256 totalSupply = lpToken.totalSupply();
        
        // 计算期望的 ETH 和 NFT 数量
        uint256 expectedETH = (INITIAL_ETH * lpBalance) / totalSupply;
        uint256 expectedNFTs = (NFT_COUNT * lpBalance) / totalSupply;
        
        // 设置过高的最小输出要求，应该失败
        vm.expectRevert("Insufficient ETH output");
        amm.removeLiquidity(lpBalance, expectedETH + 1, 0);
        
        vm.expectRevert("Insufficient NFT output");
        amm.removeLiquidity(lpBalance, 0, expectedNFTs + 1);
    }
    
    function testRemoveLiquidityZeroAmount() public {
        // 尝试移除 0 个 LP token
        vm.expectRevert("Amount must be greater than 0");
        amm.removeLiquidity(0, 0, 0);
    }
    
    function testRemoveLiquidityEvents() public {
        uint256 lpBalance = lpToken.balanceOf(owner);
        uint256 totalSupply = lpToken.totalSupply();
        
        uint256 expectedETH = (INITIAL_ETH * lpBalance) / totalSupply;
        uint256 expectedNFTs = (NFT_COUNT * lpBalance) / totalSupply;
        
        // 监听所有相关事件
        vm.expectEmit(false, false, false, true);
        emit Pair.LPTokensBurned(owner, lpBalance);
        
        // 移除流动性
        amm.removeLiquidity(lpBalance, expectedETH * 95 / 100, expectedNFTs * 95 / 100);
        
        console.log("LPTokensBurned event triggered successfully");
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
