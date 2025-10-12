// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {StandardNFT} from "../src/StandardNFT.sol";
import {MultiPoolManager} from "../src/MultiPoolManager.sol";

/**
 * @title CreatePoolValueTest
 * @dev 测试 createPool 函数从 msg.value 获取 ETH
 */
contract CreatePoolValueTest is Test, IERC721Receiver {
    MultiPoolManager public manager;
    StandardNFT public nft;
    
    address public owner;
    
    uint256 constant INITIAL_ETH = 10 ether;
    uint256 constant NFT_COUNT = 20;

    function setUp() public {
        owner = address(this);
        
        // 部署 NFT 合约
        nft = new StandardNFT(
            "Test NFT",
            "TNFT",
            "https://api.example.com/",
            1000,
            50,
            0.01 ether
        );
        
        // 部署池子管理器
        manager = new MultiPoolManager();
        
        // 预铸造 NFT
        nft.premint(owner, NFT_COUNT);
        
        // 准备 NFT token IDs
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 授权池子管理器
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            nft.approve(address(manager), i);
        }
    }

    function testCreatePoolUsesMsgValue() public {
        // 准备 NFT token IDs
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 记录创建池子前的状态
        uint256 ownerBalanceBefore = owner.balance;
        
        // 创建池子，发送 10 ETH
        manager.createPool{value: INITIAL_ETH}(address(nft), tokenIds);
        
        // 验证 ETH 被正确转移（从所有者到池子）
        assertEq(owner.balance, ownerBalanceBefore - INITIAL_ETH, "Owner should lose ETH");
        
        // 验证池子创建成功
        address poolAddress = manager.getPool(address(nft));
        assertTrue(poolAddress != address(0), "Pool should be created");
        assertTrue(manager.hasPool(address(nft)), "Pool should exist");
        
        console.log("Pool created at:", poolAddress);
        console.log("ETH sent:", INITIAL_ETH);
        console.log("Pool balance:", poolAddress.balance);
    }
    
    function testCreatePoolWithDifferentAmounts() public {
        uint256[5] memory testAmounts = [uint256(1 ether), uint256(5 ether), uint256(10 ether), uint256(20 ether), uint256(50 ether)];
        
        for (uint256 i = 0; i < 5; i++) {
            uint256 ethAmount = testAmounts[i];
            
            // 创建新的 NFT 合约用于每个测试
            StandardNFT testNft = new StandardNFT(
                string(abi.encodePacked("Test NFT ", i)),
                string(abi.encodePacked("TNFT", i)),
                "https://api.example.com/",
                1000,
                50,
                0.01 ether
            );
            
            // 预铸造 NFT
            testNft.premint(owner, NFT_COUNT);
            
            // 准备 token IDs
            uint256[] memory tokenIds = new uint256[](NFT_COUNT);
            for (uint256 j = 1; j <= NFT_COUNT; j++) {
                tokenIds[j - 1] = j;
            }
            
            // 授权
            for (uint256 j = 1; j <= NFT_COUNT; j++) {
                testNft.approve(address(manager), j);
            }
            
            // 记录余额
            uint256 ownerBalanceBefore = owner.balance;
            
            // 创建池子
            manager.createPool{value: ethAmount}(address(testNft), tokenIds);
            
            // 验证 ETH 被正确转移（从所有者到池子）
            assertEq(owner.balance, ownerBalanceBefore - ethAmount, 
                string(abi.encodePacked("Owner should lose ", ethAmount, " ETH")));
            
            // 验证池子存在
            assertTrue(manager.hasPool(address(testNft)), "Pool should exist");
            
            console.log("Created pool with %d ETH", ethAmount / 1e18);
        }
    }
    
    function testCreatePoolWithZeroValue() public {
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 尝试用 0 ETH 创建池子应该失败
        vm.expectRevert(MultiPoolManager.InvalidAmount.selector);
        manager.createPool{value: 0}(address(nft), tokenIds);
    }
    
    function testCreatePoolValueConsistency() public {
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 创建池子
        manager.createPool{value: INITIAL_ETH}(address(nft), tokenIds);
        
        // 获取池子地址
        address poolAddress = manager.getPool(address(nft));
        
        // 验证池子中的 ETH 数量与发送的数量一致
        uint256 poolBalance = poolAddress.balance;
        assertEq(poolBalance, INITIAL_ETH, "Pool should contain the exact ETH amount sent");
        
        console.log("Pool balance:", poolBalance);
        console.log("Expected balance:", INITIAL_ETH);
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
