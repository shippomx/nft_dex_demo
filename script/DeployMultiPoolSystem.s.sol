// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {StandardNFT} from "../src/StandardNFT.sol";
import {Pair} from "../src/Pair.sol";
import {MultiPoolManager} from "../src/MultiPoolManager.sol";

/**
 * @title DeployMultiPoolSystem
 * @dev 部署多池 NFT 交易系统
 */
contract DeployMultiPoolSystem is Script {
    MultiPoolManager public manager;
    StandardNFT[] public nftContracts;
    Pair[] public pools;
    
    // 部署参数
    uint256 public constant INITIAL_ETH_PER_POOL = 10 ether;
    uint256 public constant PREMINT_COUNT = 20;
    uint256 public constant POOL_COUNT = 3;
    
    // NFT 集合配置
    struct NFTConfig {
        string name;
        string symbol;
        string baseUri;
        uint256 maxSupply;
        uint256 maxMintPerAddress;
        uint256 mintPrice;
    }
    
    NFTConfig[] public nftConfigs;

    function run() public {
        // 获取私钥
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        require(deployerPrivateKey != 0, "PRIVATE_KEY not set");
        
        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);
        
        // 初始化 NFT 配置
        _initializeNFTConfigs();
        
        // 部署池子管理器
        manager = new MultiPoolManager();
        console.log("MultiPoolManager deployed at:", address(manager));
        
        // 部署 NFT 合约
        for (uint256 i = 0; i < POOL_COUNT; i++) {
            NFTConfig memory config = nftConfigs[i];
            StandardNFT nft = new StandardNFT(
                config.name,
                config.symbol,
                config.baseUri,
                config.maxSupply,
                config.maxMintPerAddress,
                config.mintPrice
            );
            nftContracts.push(nft);
            console.log("NFT Contract %d deployed at:", i + 1, address(nft));
        }
        
        // 预铸造 NFT 并创建池子
        for (uint256 i = 0; i < POOL_COUNT; i++) {
            _setupPool(i);
        }
        
        // 停止广播
        vm.stopBroadcast();
        
        // 输出部署信息
        _printDeploymentSummary();
        
        // 验证部署
        _verifyDeployment();
    }
    
    /**
     * @dev 部署到本地测试网络
     */
    function runLocal() public {
        // 获取私钥，优先使用环境变量，否则使用默认值
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast();
        
        // 初始化 NFT 配置
        _initializeNFTConfigs();
        
        // 部署池子管理器
        manager = new MultiPoolManager();
        
        // 部署 NFT 合约
        for (uint256 i = 0; i < POOL_COUNT; i++) {
            NFTConfig memory config = nftConfigs[i];
            StandardNFT nft = new StandardNFT(
                config.name,
                config.symbol,
                config.baseUri,
                config.maxSupply,
                config.maxMintPerAddress,
                config.mintPrice
            );
            nftContracts.push(nft);
        }
        
        vm.stopBroadcast();
        
        // 预铸造 NFT 并创建池子（使用部署者私钥）
        for (uint256 i = 0; i < POOL_COUNT; i++) {
            _setupPoolLocal(i, deployer);
        }
        
        console.log("=== Local Multi-Pool Deployment Summary ===");
        console.log("MultiPoolManager:", address(manager));
        console.log("Pool Count:", POOL_COUNT);
        for (uint256 i = 0; i < POOL_COUNT; i++) {
            console.log("Pool %d - NFT:", i + 1, address(nftContracts[i]));
            console.log("Pool %d - AMM:", i + 1, manager.getPool(address(nftContracts[i])));
        }
    }
    
    /**
     * @dev 初始化 NFT 配置
     */
    function _initializeNFTConfigs() internal {
        nftConfigs.push(NFTConfig({
            name: "Art Collection",
            symbol: "ART",
            baseUri: "https://api.example.com/art/",
            maxSupply: 1000,
            maxMintPerAddress: 50,
            mintPrice: 0.01 ether
        }));
        
        nftConfigs.push(NFTConfig({
            name: "Gaming Collection",
            symbol: "GAME",
            baseUri: "https://api.example.com/gaming/",
            maxSupply: 2000,
            maxMintPerAddress: 100,
            mintPrice: 0.005 ether
        }));
        
        nftConfigs.push(NFTConfig({
            name: "Music Collection",
            symbol: "MUSIC",
            baseUri: "https://api.example.com/music/",
            maxSupply: 500,
            maxMintPerAddress: 25,
            mintPrice: 0.02 ether
        }));
    }
    
    /**
     * @dev 设置单个池子
     */
    function _setupPool(uint256 index) internal {
        StandardNFT nft = nftContracts[index];
        
        // 预铸造 NFT 到部署者地址
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        nft.premint(deployer, PREMINT_COUNT);
        console.log("Preminted %d NFTs for collection %d", PREMINT_COUNT, index + 1);
        
        // 准备 NFT token IDs
        uint256[] memory tokenIds = new uint256[](PREMINT_COUNT);
        for (uint256 i = 1; i <= PREMINT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 授权池子管理器
        for (uint256 i = 1; i <= PREMINT_COUNT; i++) {
            nft.approve(address(manager), i);
        }
        
        // 创建池子
        manager.createPool{value: INITIAL_ETH_PER_POOL}(
            address(nft),
            tokenIds
        );
        
        address poolAddress = manager.getPool(address(nft));
        pools.push(Pair(payable(poolAddress)));
        
        console.log("Pool %d created at:", index + 1, poolAddress);
    }
    
    /**
     * @dev 设置单个池子（本地部署版本）
     */
    function _setupPoolLocal(uint256 index, address deployer) internal {
        StandardNFT nft = nftContracts[index];
        
        // 使用部署者私钥进行预铸造
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        
        // 预铸造 NFT 到部署者地址
        nft.premint(deployer, PREMINT_COUNT);
        console.log("Preminted %d NFTs for collection %d", PREMINT_COUNT, index + 1);
        
        // 准备 NFT token IDs
        uint256[] memory tokenIds = new uint256[](PREMINT_COUNT);
        for (uint256 i = 1; i <= PREMINT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 授权池子管理器
        for (uint256 i = 1; i <= PREMINT_COUNT; i++) {
            nft.approve(address(manager), i);
        }
        
        // 创建池子
        manager.createPool{value: INITIAL_ETH_PER_POOL}(
            address(nft),
            tokenIds
        );
        
        vm.stopBroadcast();
        
        address poolAddress = manager.getPool(address(nft));
        pools.push(Pair(payable(poolAddress)));
        
        console.log("Pool %d created at:", index + 1, poolAddress);
    }
    
    /**
     * @dev 打印部署摘要
     */
    function _printDeploymentSummary() internal view {
        console.log("=== Multi-Pool Deployment Summary ===");
        console.log("MultiPoolManager:", address(manager));
        console.log("Pool Count:", POOL_COUNT);
        console.log("Initial ETH per Pool:", INITIAL_ETH_PER_POOL);
        console.log("NFTs per Pool:", PREMINT_COUNT);
        
        for (uint256 i = 0; i < POOL_COUNT; i++) {
            console.log("--- Pool %d ---", i + 1);
            console.log("NFT Contract:", address(nftContracts[i]));
            console.log("AMM Pool:", address(pools[i]));
            
            (uint256 ethReserve, uint256 nftReserve) = manager.getPoolReserves(address(nftContracts[i]));
            uint256 currentPrice = manager.getCurrentPrice(address(nftContracts[i]));
            
            console.log("ETH Reserve:", ethReserve);
            console.log("NFT Reserve:", nftReserve);
            console.log("Current Price:", currentPrice, "wei per NFT");
        }
    }
    
    /**
     * @dev 验证部署
     */
    function _verifyDeployment() internal view {
        require(address(manager) != address(0), "Manager not deployed");
        require(nftContracts.length == POOL_COUNT, "Incorrect NFT count");
        require(pools.length == POOL_COUNT, "Incorrect pool count");
        require(manager.getPoolCount() == POOL_COUNT, "Incorrect pool count in manager");
        
        for (uint256 i = 0; i < POOL_COUNT; i++) {
            require(address(nftContracts[i]) != address(0), "NFT contract not deployed");
            require(address(pools[i]) != address(0), "Pool not deployed");
            require(manager.hasPool(address(nftContracts[i])), "Pool not registered");
            
            (uint256 ethReserve, uint256 nftReserve) = manager.getPoolReserves(address(nftContracts[i]));
            require(ethReserve == INITIAL_ETH_PER_POOL, "Incorrect ETH reserve");
            require(nftReserve == PREMINT_COUNT, "Incorrect NFT reserve");
        }
        
        console.log("Deployment verification passed");
    }
}
