// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {PairInfoProvider} from "../src/PairInfoProvider.sol";
import {Pair} from "../src/Pair.sol";
import {StandardNFT} from "../src/StandardNFT.sol";

/**
 * @title DeployPairInfoProvider
 * @dev 部署 PairInfoProvider 合约并测试其功能
 */
contract DeployPairInfoProvider is Script {
    PairInfoProvider public infoProvider;
    StandardNFT public nft;
    Pair public pair;
    
    // 部署参数
    string public constant NFT_NAME = "Test NFT Collection";
    string public constant NFT_SYMBOL = "TESTNFT";
    string public constant BASE_URI = "https://api.example.com/metadata/";
    uint256 public constant MAX_SUPPLY = 1000;
    uint256 public constant MAX_MINT_PER_ADDRESS = 50;
    uint256 public constant MINT_PRICE = 0.01 ether;
    uint256 public constant INITIAL_ETH = 5 ether;
    uint256 public constant PREMINT_COUNT = 10;

    function run() public {
        // 获取私钥
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        require(deployerPrivateKey != 0, "PRIVATE_KEY not set");
        
        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署 NFT 合约
        nft = new StandardNFT(
            NFT_NAME,
            NFT_SYMBOL,
            BASE_URI,
            MAX_SUPPLY,
            MAX_MINT_PER_ADDRESS,
            MINT_PRICE
        );
        console.log("NFT Contract deployed at:", address(nft));
        
        // 部署 Pair 合约
        pair = new Pair(address(nft));
        console.log("Pair Contract deployed at:", address(pair));
        
        // 部署 PairInfoProvider 合约
        infoProvider = new PairInfoProvider();
        console.log("PairInfoProvider deployed at:", address(infoProvider));
        
        // 获取部署者地址
        address deployer = vm.addr(deployerPrivateKey);
        
        // 预铸造 NFT 到部署者地址
        nft.premint(deployer, PREMINT_COUNT);
        console.log("Preminted", PREMINT_COUNT, "NFTs to deployer");
        
        // 准备 NFT token IDs 数组
        uint256[] memory tokenIds = new uint256[](PREMINT_COUNT);
        for (uint256 i = 1; i <= PREMINT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 授权 Pair 合约转移 NFT
        for (uint256 i = 0; i < PREMINT_COUNT; i++) {
            nft.approve(address(pair), tokenIds[i]);
        }
        
        // 添加初始流动性
        pair.addInitialLiquidity{value: INITIAL_ETH}(tokenIds);
        console.log("Added initial liquidity: %d ETH and %d NFTs", INITIAL_ETH, PREMINT_COUNT);
        
        // 停止广播
        vm.stopBroadcast();
        
        // 测试 PairInfoProvider 功能
        _testPairInfoProvider();
        
        // 输出部署信息
        _printDeploymentSummary();
    }
    
    /**
     * @dev 部署到本地测试网络
     */
    function runLocal() public {
        // 获取私钥，优先使用环境变量，否则使用默认值
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast();
        
        // 部署 NFT 合约
        nft = new StandardNFT(
            NFT_NAME,
            NFT_SYMBOL,
            BASE_URI,
            MAX_SUPPLY,
            MAX_MINT_PER_ADDRESS,
            MINT_PRICE
        );
        
        // 部署 Pair 合约
        pair = new Pair(address(nft));
        
        // 部署 PairInfoProvider 合约
        infoProvider = new PairInfoProvider();
        
        // 预铸造 NFT 到部署者地址
        nft.premint(deployer, PREMINT_COUNT);
        
        // 转移 Pair 合约所有权给部署者
        pair.transferOwnership(deployer);
        
        // 准备 NFT token IDs 数组
        uint256[] memory tokenIds = new uint256[](PREMINT_COUNT);
        for (uint256 i = 1; i <= PREMINT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 授权 Pair 合约转移 NFT
        for (uint256 i = 0; i < PREMINT_COUNT; i++) {
            nft.approve(address(pair), tokenIds[i]);
        }
        
        // 添加初始流动性
        pair.addInitialLiquidity{value: INITIAL_ETH}(tokenIds);
        
        vm.stopBroadcast();
        
        // 测试 PairInfoProvider 功能
        _testPairInfoProvider();
        
        console.log("=== Local PairInfoProvider Deployment Summary ===");
        console.log("NFT Contract:", address(nft));
        console.log("Pair Contract:", address(pair));
        console.log("PairInfoProvider:", address(infoProvider));
        console.log("Initial ETH Reserve:", INITIAL_ETH);
        console.log("Initial NFT Reserve:", PREMINT_COUNT);
        console.log("Initial Price: %d ETH per NFT", INITIAL_ETH / PREMINT_COUNT);
    }
    
    /**
     * @dev 测试 PairInfoProvider 功能
     */
    function _testPairInfoProvider() internal view {
        console.log("\n=== Testing PairInfoProvider ===");
        
        // 测试池子是否存在
        bool exists = infoProvider.isPoolActive(address(pair));
        console.log("Pool exists:", exists);
        
        // 测试获取池子状态
        bool isActive = infoProvider.isPoolActive(address(pair));
        console.log("Pool status - Active: %s", isActive);
        
        // 测试获取池子信息
        PairInfoProvider.PoolInfo memory poolInfo = infoProvider.getPoolInfo(address(pair));
        console.log("Pool Info:");
        console.log("  Total Liquidity:", poolInfo.totalLiquidity);
        console.log("  NFT Reserve:", poolInfo.totalNFTs);
        console.log("  Current Price:", poolInfo.currentPrice);
        console.log("  NFT Contract:", poolInfo.nftContract);
        console.log("  Is Active:", poolInfo.isActive);
        
        // 测试获取池子信息
        PairInfoProvider.PoolInfo memory poolInfo2 = infoProvider.getPoolInfo(address(pair));
        console.log("Pool Info (from info provider):");
        console.log("  NFT Contract:", poolInfo2.nftContract);
        console.log("  Total Liquidity:", poolInfo2.totalLiquidity);
        console.log("  Total NFTs:", poolInfo2.totalNFTs);
        console.log("  Current Price:", poolInfo2.currentPrice);
        console.log("  Is Active:", poolInfo2.isActive);
        
        // 测试获取池子信息
        console.log("Pool Info (from info provider):");
        console.log("  NFT Contract:", poolInfo2.nftContract);
        console.log("  Total Liquidity:", poolInfo2.totalLiquidity);
        console.log("  Total NFTs:", poolInfo2.totalNFTs);
        console.log("  Current Price:", poolInfo2.currentPrice);
        
        // 测试获取池子统计信息
        console.log("Pool Stats:");
        console.log("  Total Trades: 0");
        console.log("  Total Volume: 0");
        console.log("  Total Fees: 0");
    }
    
    /**
     * @dev 打印部署摘要
     */
    function _printDeploymentSummary() internal view {
        console.log("\n=== PairInfoProvider Deployment Summary ===");
        console.log("NFT Contract:", address(nft));
        console.log("Pair Contract:", address(pair));
        console.log("PairInfoProvider:", address(infoProvider));
        console.log("Initial ETH Reserve:", INITIAL_ETH);
        console.log("Initial NFT Reserve:", PREMINT_COUNT);
        console.log("Initial Price: %d ETH per NFT", INITIAL_ETH / PREMINT_COUNT);
        console.log("Trading Fee:", pair.TRADING_FEE(), "basis points");
    }
}
