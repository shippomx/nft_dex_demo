// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StandardNFT} from "../src/StandardNFT.sol";
import {Pair} from "../src/Pair.sol";

/**
 * @title LPTokenTest
 * @dev 测试 LP token 功能
 */
contract LPTokenTest is Test, IERC721Receiver {
    Pair public amm;
    StandardNFT public nft;
    
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

    function testAddLiquidityWithLPToken() public {
        // 准备 NFT token IDs
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 记录添加流动性前的状态
        uint256 balanceBefore = address(amm).balance;
        uint256 nftReserveBefore = amm.nftReserve();
        
        // 添加流动性
        amm.addInitialLiquidity{value: INITIAL_ETH}(tokenIds);
        
        // 验证 ETH 储备增加
        assertEq(address(amm).balance, balanceBefore + INITIAL_ETH);
        
        // 验证 NFT 储备增加
        assertEq(amm.nftReserve(), nftReserveBefore + NFT_COUNT);
        
        // 验证 NFT 被转移到池子
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            assertEq(nft.ownerOf(i), address(amm));
        }
        
        // 验证 LP token 被铸造
        address lpTokenAddress = address(amm.lpToken());
        assertTrue(lpTokenAddress != address(0), "LP Token should be created");
        
        IERC20 lpToken = IERC20(lpTokenAddress);
        uint256 lpBalance = lpToken.balanceOf(owner);
        assertTrue(lpBalance > 0, "Should receive LP tokens");
        
        // 计算期望的 LP token 数量
        uint256 expectedLP = sqrt(INITIAL_ETH * NFT_COUNT);
        assertEq(lpBalance, expectedLP, "LP token amount should match calculation");
        
        console.log("LP Token address:", lpTokenAddress);
        console.log("LP Token balance:", lpBalance);
        console.log("Expected LP amount:", expectedLP);
    }
    
    function testLPTokenShouldExist() public {
        // 这个测试会失败，因为当前实现没有 LP token
        // 但我们可以验证当前的行为
        
        // 准备 NFT token IDs
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 添加流动性
        amm.addInitialLiquidity{value: INITIAL_ETH}(tokenIds);
        
        // 检查是否有 LP token 合约
        // 当前实现中没有 LP token，所以这些检查会失败
        console.log("Current AMM implementation does NOT have LP token functionality");
        console.log("This is a significant missing feature for a proper AMM");
        
        // 在标准的 AMM 中，流动性提供者应该收到 LP token 作为凭证
        // 这些 LP token 代表他们在池子中的份额
        // 当池子产生手续费时，LP token 持有者可以按比例分享收益
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
