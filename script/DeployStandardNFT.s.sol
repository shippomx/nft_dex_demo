// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {StandardNFT} from "../src/StandardNFT.sol";

/**
 * @title DeployStandardNFT
 * @dev 部署标准 NFT 合约到 Sepolia 测试网
 */
contract DeployStandardNFT is Script {
    StandardNFT public nft;
    
    // 部署参数
    string public constant NFT_NAME = "Test NFT Collection";
    string public constant NFT_SYMBOL = "TESTNFT";
    string public constant BASE_URI = "https://api.example.com/metadata/";
    uint256 public constant MAX_SUPPLY = 1000;
    uint256 public constant MAX_MINT_PER_ADDRESS = 50;
    uint256 public constant MINT_PRICE = 0.01 ether;

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
        
        // 停止广播
        vm.stopBroadcast();
        
        // 输出部署信息
        console.log("=== NFT Deployment Summary ===");
        console.log("NFT Contract:", address(nft));
        console.log("Name:", NFT_NAME);
        console.log("Symbol:", NFT_SYMBOL);
        console.log("Max Supply:", MAX_SUPPLY);
        console.log("Max Mint Per Address:", MAX_MINT_PER_ADDRESS);
        console.log("Mint Price:", MINT_PRICE, "wei");
        console.log("Base URI:", BASE_URI);
        
        // 验证部署
        _verifyDeployment();
    }
    
    /**
     * @dev 部署到本地测试网络
     */
    function runLocal() public {
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
        
        vm.stopBroadcast();
        
        console.log("=== Local NFT Deployment Summary ===");
        console.log("NFT Contract:", address(nft));
        console.log("Name:", NFT_NAME);
        console.log("Symbol:", NFT_SYMBOL);
    }
    
    /**
     * @dev 验证部署
     */
    function _verifyDeployment() internal view {
        require(address(nft) != address(0), "NFT contract not deployed");
        require(keccak256(bytes(nft.name())) == keccak256(bytes(NFT_NAME)), "Incorrect name");
        require(keccak256(bytes(nft.symbol())) == keccak256(bytes(NFT_SYMBOL)), "Incorrect symbol");
        require(nft.maxSupply() == MAX_SUPPLY, "Incorrect max supply");
        require(nft.maxMintPerAddress() == MAX_MINT_PER_ADDRESS, "Incorrect max mint per address");
        require(nft.mintPrice() == MINT_PRICE, "Incorrect mint price");
        
        console.log("Deployment verification passed");
    }
}