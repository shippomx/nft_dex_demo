// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {StandardNFT} from "../src/StandardNFT.sol";
import {Pair} from "../src/Pair.sol";

/**
 * @title DeployAMMSystem
 * @dev 部署完整的 AMM NFT 交易系统
 */
contract DeployAMMSystem is Script {
    StandardNFT public nft;
    Pair public amm;
    
    // 部署参数
    string public constant NFT_NAME = "AMM NFT Collection";
    string public constant NFT_SYMBOL = "AMMNFT";
    string public constant BASE_URI = "https://api.example.com/metadata/";
    uint256 public constant MAX_SUPPLY = 1000;
    uint256 public constant MAX_MINT_PER_ADDRESS = 50;
    uint256 public constant MINT_PRICE = 0.01 ether;
    uint256 public constant INITIAL_ETH = 10 ether;
    uint256 public constant PREMINT_COUNT = 20;

    function run() public {
        // 使用提供的私钥
        uint256 deployerPrivateKey = 0x2d641b722192c0003244f5467ef1b81b843a91693a8b657e08e34f5d879deba0;
        
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
        
        // 部署 AMM 合约
        amm = new Pair(address(nft));
        
        console.log("AMM Marketplace deployed at:", address(amm));
        
        // 获取部署者地址
        address deployer = vm.addr(deployerPrivateKey);
        
        // 转移 NFT 合约所有权给部署者
        nft.transferOwnership(deployer);
        
        // 预铸造 NFT 到部署者地址
        nft.premint(deployer, PREMINT_COUNT);
        console.log("Preminted", PREMINT_COUNT, "NFTs to deployer");
        
        // 准备 NFT token IDs 数组
        uint256[] memory tokenIds = new uint256[](PREMINT_COUNT);
        for (uint256 i = 1; i <= PREMINT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 授权 AMM 合约转移 NFT
        for (uint256 i = 0; i < PREMINT_COUNT; i++) {
            nft.approve(address(amm), tokenIds[i]);
        }
        
        // 添加初始流动性
        amm.addInitialLiquidity{value: INITIAL_ETH}(tokenIds);
        console.log("Added initial liquidity: %d ETH and %d NFTs", INITIAL_ETH, PREMINT_COUNT);
        
        // 停止广播
        vm.stopBroadcast();
        
        // 输出部署信息
        console.log("=== Deployment Summary ===");
        console.log("NFT Contract:", address(nft));
        console.log("AMM Marketplace:", address(amm));
        console.log("Initial ETH Reserve:", INITIAL_ETH);
        console.log("Initial NFT Reserve:", PREMINT_COUNT);
        console.log("Initial Price: %d ETH per NFT", INITIAL_ETH / PREMINT_COUNT);
        console.log("Trading Fee:", amm.TRADING_FEE(), "basis points");
        console.log("Max Slippage: 500 basis points");
        
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
        
        // 部署 NFT 合约
        nft = new StandardNFT(
            NFT_NAME,
            NFT_SYMBOL,
            BASE_URI,
            MAX_SUPPLY,
            MAX_MINT_PER_ADDRESS,
            MINT_PRICE
        );
        
        // 部署 AMM 合约
        amm = new Pair(address(nft));
        
        // 预铸造 NFT 到部署者地址
        nft.premint(deployer, PREMINT_COUNT);
        
        // 转移 AMM 合约所有权给部署者
        amm.transferOwnership(deployer);
        
        // 准备 NFT token IDs 数组
        uint256[] memory tokenIds = new uint256[](PREMINT_COUNT);
        for (uint256 i = 1; i <= PREMINT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 先授权 AMM 合约转移 NFT
        for (uint256 i = 0; i < PREMINT_COUNT; i++) {
            nft.approve(address(amm), tokenIds[i]);
        }
        
        // 添加初始流动性
        amm.addInitialLiquidity{value: INITIAL_ETH}(tokenIds);
        
        vm.stopBroadcast();
        
        console.log("=== Local Deployment Summary ===");
        console.log("NFT Contract:", address(nft));
        console.log("AMM Marketplace:", address(amm));
        console.log("Initial Price: %d ETH per NFT", INITIAL_ETH / PREMINT_COUNT);
    }
    
    /**
     * @dev 验证部署
     */
    function _verifyDeployment() internal view {
        require(address(nft) != address(0), "NFT contract not deployed");
        require(address(amm) != address(0), "AMM contract not deployed");
        require(amm.nftReserve() == PREMINT_COUNT, "Incorrect NFT reserve");
        require(address(amm).balance == INITIAL_ETH, "Incorrect ETH reserve");
        require(amm.getCurrentPrice() == INITIAL_ETH / PREMINT_COUNT, "Incorrect initial price");
        
        console.log("Deployment verification passed");
    }
}
