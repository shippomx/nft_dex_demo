// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PairInfoProvider
 * @dev 提供池子信息查询功能
 * @author NFT DEX Team
 */
contract PairInfoProvider {
    // 池子信息结构
    struct PoolInfo {
        address nftContract;
        uint256 totalLiquidity;
        uint256 totalNFTs;
        uint256 currentPrice;
        bool isActive;
    }
    
    // 池子信息映射
    mapping(address => PoolInfo) public pools;
    
    // 事件
    event PoolInfoUpdated(address indexed pool, address nftContract, uint256 totalLiquidity, uint256 totalNFTs, uint256 currentPrice);
    
    /**
     * @dev 更新池子信息
     * @param pool 池子地址
     * @param nftContract NFT 合约地址
     * @param totalLiquidity 总流动性
     * @param totalNFTs NFT 总数
     * @param currentPrice 当前价格
     */
    function updatePoolInfo(
        address pool,
        address nftContract,
        uint256 totalLiquidity,
        uint256 totalNFTs,
        uint256 currentPrice
    ) external {
        pools[pool] = PoolInfo({
            nftContract: nftContract,
            totalLiquidity: totalLiquidity,
            totalNFTs: totalNFTs,
            currentPrice: currentPrice,
            isActive: true
        });
        
        emit PoolInfoUpdated(pool, nftContract, totalLiquidity, totalNFTs, currentPrice);
    }
    
    /**
     * @dev 获取池子信息
     * @param pool 池子地址
     * @return PoolInfo 池子信息
     */
    function getPoolInfo(address pool) external view returns (PoolInfo memory) {
        return pools[pool];
    }
    
    /**
     * @dev 检查池子是否活跃
     * @param pool 池子地址
     * @return bool 是否活跃
     */
    function isPoolActive(address pool) external view returns (bool) {
        return pools[pool].isActive;
    }
}
