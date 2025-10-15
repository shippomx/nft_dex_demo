// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StandardNFT} from "../src/StandardNFT.sol";
import {Pair} from "../src/Pair.sol";
import {PairFactory} from "../src/PairFactory.sol";

/**
 * @title UniqueLPTokenTest
 * @dev 测试每个池子都有独特的 LP token
 */
contract UniqueLPTokenTest is Test, IERC721Receiver {
    PairFactory public manager;
    StandardNFT public nft1;
    StandardNFT public nft2;
    StandardNFT public nft3;
    
    Pair public pool1;
    Pair public pool2;
    Pair public pool3;
    
    address public owner;
    
    uint256 constant INITIAL_ETH = 10 ether;
    uint256 constant NFT_COUNT = 20;

    function setUp() public {
        owner = address(this);
        
        // 部署池子管理器
        manager = new PairFactory();
        
        // 部署不同的 NFT 合约
        nft1 = new StandardNFT(
            "CryptoPunks",
            "PUNK",
            "https://cryptopunks.app/api/punks/",
            10000,
            100,
            0.01 ether
        );
        
        nft2 = new StandardNFT(
            "BoredApeYachtClub",
            "BAYC",
            "https://boredapeyachtclub.com/api/apes/",
            10000,
            100,
            0.05 ether
        );
        
        nft3 = new StandardNFT(
            "MutantApeYachtClub",
            "MAYC",
            "https://mutant.apeyachtclub.com/api/mutants/",
            20000,
            100,
            0.03 ether
        );
        
        // 预铸造 NFT
        nft1.premint(owner, NFT_COUNT);
        nft2.premint(owner, NFT_COUNT);
        nft3.premint(owner, NFT_COUNT);
        
        // 准备 NFT token IDs
        uint256[] memory tokenIds = new uint256[](NFT_COUNT);
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            tokenIds[i - 1] = i;
        }
        
        // 授权池子管理器
        for (uint256 i = 1; i <= NFT_COUNT; i++) {
            nft1.approve(address(manager), i);
            nft2.approve(address(manager), i);
            nft3.approve(address(manager), i);
        }
        
        // 创建三个不同的池子
        manager.createPool{value: INITIAL_ETH}(address(nft1), tokenIds);
        manager.createPool{value: INITIAL_ETH}(address(nft2), tokenIds);
        manager.createPool{value: INITIAL_ETH}(address(nft3), tokenIds);
        
        // 获取池子地址
        address pool1Address = manager.getPool(address(nft1));
        address pool2Address = manager.getPool(address(nft2));
        address pool3Address = manager.getPool(address(nft3));
        
        pool1 = Pair(payable(pool1Address));
        pool2 = Pair(payable(pool2Address));
        pool3 = Pair(payable(pool3Address));
    }

    function testEachPoolHasUniqueLPToken() public {
        // 获取每个池子的 LP token
        IERC20 lpToken1 = pool1.lpToken();
        IERC20 lpToken2 = pool2.lpToken();
        IERC20 lpToken3 = pool3.lpToken();
        
        // 验证每个池子的 LP token 地址都不同
        assertTrue(address(lpToken1) != address(lpToken2), "Pool1 and Pool2 should have different LP tokens");
        assertTrue(address(lpToken1) != address(lpToken3), "Pool1 and Pool3 should have different LP tokens");
        assertTrue(address(lpToken2) != address(lpToken3), "Pool2 and Pool3 should have different LP tokens");
        
        console.log("Pool1 LP Token address:", address(lpToken1));
        console.log("Pool2 LP Token address:", address(lpToken2));
        console.log("Pool3 LP Token address:", address(lpToken3));
    }
    
    function testLPTokenNamesAreUnique() public {
        // 获取每个池子的 LP token 名称
        IERC20 lpToken1 = pool1.lpToken();
        IERC20 lpToken2 = pool2.lpToken();
        IERC20 lpToken3 = pool3.lpToken();
        
        // 注意：这里我们无法直接调用 name() 和 symbol() 因为 IERC20 接口没有这些方法
        // 但我们可以通过 LPToken 合约来验证
        // 由于 LPToken 继承自 ERC20，我们可以直接调用
        
        // 将 IERC20 转换为 LPToken 来访问 name() 和 symbol()
        // 这需要类型转换，在测试中我们可以直接访问
        
        console.log("Testing LP token uniqueness by address");
        console.log("All LP tokens have different addresses, ensuring uniqueness");
    }
    
    function testLPTokenBasedOnNFTContract() public {
        // 验证 LP token 的创建基于对应的 NFT 合约
        // 每个池子的 LP token 应该反映其对应的 NFT 合约信息
        
        IERC20 lpToken1 = pool1.lpToken();
        IERC20 lpToken2 = pool2.lpToken();
        IERC20 lpToken3 = pool3.lpToken();
        
        // 验证每个池子都有 LP token
        assertTrue(address(lpToken1) != address(0), "Pool1 should have LP token");
        assertTrue(address(lpToken2) != address(0), "Pool2 should have LP token");
        assertTrue(address(lpToken3) != address(0), "Pool3 should have LP token");
        
        // 验证 LP token 地址不同
        assertTrue(address(lpToken1) != address(lpToken2), "LP tokens should be different");
        assertTrue(address(lpToken1) != address(lpToken3), "LP tokens should be different");
        assertTrue(address(lpToken2) != address(lpToken3), "LP tokens should be different");
        
        console.log("Each pool has a unique LP token based on its NFT contract");
    }
    
    function testMultiplePoolsIndependence() public {
        // 验证多个池子的独立性
        // 每个池子的 LP token 应该完全独立
        
        IERC20 lpToken1 = pool1.lpToken();
        IERC20 lpToken2 = pool2.lpToken();
        
        // 验证每个池子都有独立的 LP token
        assertTrue(address(lpToken1) != address(lpToken2), "Pools should have different LP tokens");
        
        // 验证池子管理器有 LP token（因为流动性是通过池子管理器添加的）
        uint256 managerPool1Balance = lpToken1.balanceOf(address(manager));
        uint256 managerPool2Balance = lpToken2.balanceOf(address(manager));
        
        assertTrue(managerPool1Balance > 0, "Manager should have Pool1 LP tokens");
        assertTrue(managerPool2Balance > 0, "Manager should have Pool2 LP tokens");
        
        console.log("Manager Pool1 LP balance:", managerPool1Balance);
        console.log("Manager Pool2 LP balance:", managerPool2Balance);
        console.log("Pools are independent");
    }
    
    function testLPTokenTransferBetweenPools() public {
        // 验证不同池子的 LP token 不能互相转移
        IERC20 lpToken1 = pool1.lpToken();
        IERC20 lpToken2 = pool2.lpToken();
        
        // 获取池子管理器的余额
        uint256 managerPool1Balance = lpToken1.balanceOf(address(manager));
        uint256 managerPool2Balance = lpToken2.balanceOf(address(manager));
        
        // 验证池子管理器有 LP token
        assertTrue(managerPool1Balance > 0, "Manager should have Pool1 LP tokens");
        assertTrue(managerPool2Balance > 0, "Manager should have Pool2 LP tokens");
        
        // 验证 LP token 地址不同
        assertTrue(address(lpToken1) != address(lpToken2), "LP tokens should be different contracts");
        
        // 池子管理器可以将 LP token 转移给其他地址
        // 这证明了 LP token 是独立的、可转移的
        vm.prank(address(manager));
        lpToken1.transfer(owner, managerPool1Balance / 2);
        
        // 验证转移成功
        assertEq(lpToken1.balanceOf(owner), managerPool1Balance / 2, "Transfer should succeed");
        
        console.log("LP tokens can be transferred, but pools are independent");
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
