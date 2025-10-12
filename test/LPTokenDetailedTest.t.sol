// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {StandardNFT} from "../src/StandardNFT.sol";
import {Pair} from "../src/Pair.sol";
import {LPToken} from "../src/LPToken.sol";

/**
 * @title LPTokenDetailedTest
 * @dev 详细测试 LP token 功能
 */
contract LPTokenDetailedTest is Test, IERC721Receiver {
    Pair public amm;
    StandardNFT public nft;
    LPToken public lpToken;
    
    address public owner;
    address public liquidityProvider1;
    address public liquidityProvider2;
    
    uint256 constant INITIAL_ETH = 10 ether;
    uint256 constant NFT_COUNT = 20;

    function setUp() public {
        owner = address(this);
        liquidityProvider1 = makeAddr("liquidityProvider1");
        liquidityProvider2 = makeAddr("liquidityProvider2");
        
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
    }

    function testLPTokenBasicInfo() public {
        // 测试 LP token 基本信息
        // 现在 LP token 名称基于 NFT 合约地址
        string memory expectedName = string(abi.encodePacked("LP-NFT-", _toHexString(address(nft))));
        string memory expectedSymbol = string(abi.encodePacked("LP-", _toHexString(address(nft))));
        
        assertEq(lpToken.name(), expectedName);
        assertEq(lpToken.symbol(), expectedSymbol);
        assertEq(lpToken.decimals(), 18);
        assertEq(lpToken.totalSupply(), 0);
        
        console.log("LP Token Name:", lpToken.name());
        console.log("LP Token Symbol:", lpToken.symbol());
        console.log("LP Token Decimals:", lpToken.decimals());
    }
    
    function testAddLiquidityMintsLPTokens() public {
        // 准备 NFT token IDs
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 记录添加流动性前的状态
        uint256 lpBalanceBefore = lpToken.balanceOf(owner);
        uint256 totalSupplyBefore = lpToken.totalSupply();
        
        // 添加流动性
        amm.addInitialLiquidity{value: INITIAL_ETH}(tokenIds);
        
        // 验证 LP token 被铸造
        uint256 lpBalanceAfter = lpToken.balanceOf(owner);
        uint256 totalSupplyAfter = lpToken.totalSupply();
        
        assertTrue(lpBalanceAfter > lpBalanceBefore, "LP token balance should increase");
        assertTrue(totalSupplyAfter > totalSupplyBefore, "Total supply should increase");
        
        // 计算期望的 LP token 数量
        uint256 expectedLP = sqrt(INITIAL_ETH * NFT_COUNT);
        assertEq(lpBalanceAfter, expectedLP, "LP token amount should match calculation");
        assertEq(totalSupplyAfter, expectedLP, "Total supply should equal minted amount");
        
        console.log("LP Token balance after adding liquidity:", lpBalanceAfter);
        console.log("Expected LP amount:", expectedLP);
        console.log("Total supply:", totalSupplyAfter);
    }
    
    function testLPTokenCalculation() public {
        // 测试不同数量的 LP token 计算
        uint256[5] memory testCases = [
            uint256(1 ether), 
            uint256(5 ether), 
            uint256(10 ether), 
            uint256(20 ether), 
            uint256(50 ether)
        ];
        
        for (uint256 i = 0; i < 5; i++) {
            uint256 ethAmount = testCases[i];
            uint256 nftAmount = 10; // 固定 NFT 数量
            
            uint256 expectedLP = sqrt(ethAmount * nftAmount);
            
            console.log("ETH: %d, NFT: %d, Expected LP: %d", ethAmount / 1e18, nftAmount, expectedLP);
            
            // 验证计算正确性
            assertTrue(expectedLP > 0, "LP amount should be positive");
            assertTrue(expectedLP <= ethAmount, "LP amount should not exceed ETH amount");
            assertTrue(expectedLP <= nftAmount * 1e18, "LP amount should not exceed NFT amount");
        }
    }
    
    function testLPTokenTransfer() public {
        // 先添加流动性获得 LP token
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        amm.addInitialLiquidity{value: INITIAL_ETH}(tokenIds);
        
        uint256 lpBalance = lpToken.balanceOf(owner);
        assertTrue(lpBalance > 0, "Should have LP tokens");
        
        // 转移 LP token
        uint256 transferAmount = lpBalance / 2;
        lpToken.transfer(liquidityProvider1, transferAmount);
        
        assertEq(lpToken.balanceOf(owner), lpBalance - transferAmount);
        assertEq(lpToken.balanceOf(liquidityProvider1), transferAmount);
        
        console.log("Transferred LP tokens:", transferAmount);
        console.log("Remaining LP tokens:", lpToken.balanceOf(owner));
    }
    
    function testLPTokenApproval() public {
        // 先添加流动性获得 LP token
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        amm.addInitialLiquidity{value: INITIAL_ETH}(tokenIds);
        
        uint256 lpBalance = lpToken.balanceOf(owner);
        uint256 transferAmount = lpBalance / 2;
        
        // 授权转移
        lpToken.approve(liquidityProvider1, transferAmount);
        assertEq(lpToken.allowance(owner, liquidityProvider1), transferAmount);
        
        // 通过授权转移
        vm.prank(liquidityProvider1);
        lpToken.transferFrom(owner, liquidityProvider2, transferAmount);
        
        assertEq(lpToken.balanceOf(owner), lpBalance - transferAmount);
        assertEq(lpToken.balanceOf(liquidityProvider2), transferAmount);
        assertEq(lpToken.allowance(owner, liquidityProvider1), 0);
        
        console.log("Approval and transferFrom successful");
    }
    
    function testMultipleLiquidityProviders() public {
        // 第一个流动性提供者
        uint256[] memory tokenIds1 = new uint256[](10);
        for (uint256 i = 1; i <= 10; i++) {
            tokenIds1[i - 1] = i;
        }
        
        // 授权并添加流动性
        for (uint256 i = 1; i <= 10; i++) {
            nft.approve(address(amm), i);
        }
        
        amm.addInitialLiquidity{value: 5 ether}(tokenIds1);
        
        uint256 lpBalance1 = lpToken.balanceOf(owner);
        console.log("First LP provider balance:", lpBalance1);
        
        // 注意：在实际的 AMM 中，后续的流动性提供者需要按比例添加
        // 这里只是演示 LP token 的分配
        assertTrue(lpBalance1 > 0, "First provider should receive LP tokens");
    }
    
    function testLPTokenEvents() public {
        // 准备 NFT token IDs
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 监听事件
        vm.expectEmit(false, false, false, true);
        emit Pair.LPTokensMinted(owner, sqrt(INITIAL_ETH * NFT_COUNT));
        
        // 添加流动性
        amm.addInitialLiquidity{value: INITIAL_ETH}(tokenIds);
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
     * @dev 计算平方根（用于测试）
     * @param x 输入值
     * @return 平方根
     */
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
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
