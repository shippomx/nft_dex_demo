# PairInfoProvider 合约

## 概述

`PairInfoProvider` 是一个专门用于获取 Pair 合约相关信息的工具合约。它提供了丰富的查询功能，帮助开发者和用户轻松获取池子的状态、价格、流动性等信息。

## 功能特性

### 🔍 核心功能

- **池子存在性检查** - 验证 Pair 合约是否已部署
- **状态查询** - 获取池子的活跃状态、暂停状态和流动性状态
- **详细信息** - 获取池子的完整信息，包括储备量、价格、费用等
- **价格分析** - 获取买入/卖出价格、费用和总成本信息
- **流动性分析** - 查询流动性储备和 LP Token 信息
- **交易历史** - 获取池子的交易历史记录
- **统计信息** - 计算总交易数、交易量和手续费统计
- **批量查询** - 支持批量获取多个池子的信息

### 📊 数据结构

#### PoolInfo 结构体
```solidity
struct PoolInfo {
    address pairAddress;        // Pair 合约地址
    address nftContract;       // NFT 合约地址
    uint256 ethReserve;        // ETH 储备量
    uint256 nftReserve;        // NFT 储备量
    uint256 currentPrice;      // 当前价格
    uint256 sellPrice;         // 卖出价格
    uint256 tradingFee;        // 交易费用
    uint256 accumulatedFees;   // 累计费用
    bool isPaused;            // 是否暂停
    address owner;             // 池子所有者
    address lpToken;           // LP Token 地址
    uint256 lpTotalSupply;     // LP Token 总供应量
}
```

#### PriceInfo 结构体
```solidity
struct PriceInfo {
    uint256 buyPrice;          // 买入价格
    uint256 sellPrice;         // 卖出价格
    uint256 buyTotalCost;      // 买入总成本
    uint256 sellNetAmount;     // 卖出净收入
    uint256 buyFee;            // 买入手续费
    uint256 sellFee;           // 卖出手续费
}
```

#### LiquidityInfo 结构体
```solidity
struct LiquidityInfo {
    uint256 ethReserve;        // ETH 储备量
    uint256 nftReserve;        // NFT 储备量
    uint256 totalLiquidity;    // 总流动性
    uint256 lpTokenSupply;     // LP Token 供应量
    uint256 lpTokenDecimals;   // LP Token 小数位数
}
```

## 使用方法

### 1. 部署合约

```bash
forge script script/DeployPairInfoProvider.s.sol:DeployPairInfoProvider --fork-url "http://localhost:8545" --broadcast --private-key "0x..." --sig "runLocal()"
```

### 2. 基本查询

#### 检查池子是否存在
```solidity
bool exists = pairInfoProvider.poolExists(pairAddress);
```

#### 获取池子状态
```solidity
(bool isActive, bool isPaused, bool hasLiquidity) = pairInfoProvider.getPoolStatus(pairAddress);
```

#### 获取池子完整信息
```solidity
PoolInfo memory info = pairInfoProvider.getPoolInfo(pairAddress);
```

### 3. 价格查询

```solidity
PriceInfo memory priceInfo = pairInfoProvider.getPriceInfo(pairAddress);
```

### 4. 流动性查询

```solidity
LiquidityInfo memory liquidityInfo = pairInfoProvider.getLiquidityInfo(pairAddress);
```

### 5. 交易历史查询

```solidity
Pair.Trade[] memory trades = pairInfoProvider.getTradeHistory(pairAddress);
```

### 6. 统计信息查询

```solidity
(uint256 totalTrades, uint256 totalVolume, uint256 totalFees) = pairInfoProvider.getPoolStats(pairAddress);
```

### 7. 批量查询

```solidity
address[] memory pairAddresses = [pair1, pair2, pair3];
PoolInfo[] memory poolInfos = pairInfoProvider.getBatchPoolInfo(pairAddresses);
```

## 使用示例

### JavaScript/TypeScript 示例

```javascript
// 使用 ethers.js
const pairInfoProvider = new ethers.Contract(providerAddress, abi, provider);

// 检查池子是否存在
const exists = await pairInfoProvider.poolExists(pairAddress);

// 获取池子状态
const [isActive, isPaused, hasLiquidity] = await pairInfoProvider.getPoolStatus(pairAddress);

// 获取池子信息
const poolInfo = await pairInfoProvider.getPoolInfo(pairAddress);
console.log(`ETH 储备: ${ethers.utils.formatEther(poolInfo.ethReserve)} ETH`);
console.log(`NFT 储备: ${poolInfo.nftReserve}`);
console.log(`当前价格: ${ethers.utils.formatEther(poolInfo.currentPrice)} ETH`);

// 获取价格信息
const priceInfo = await pairInfoProvider.getPriceInfo(pairAddress);
console.log(`买入价格: ${ethers.utils.formatEther(priceInfo.buyPrice)} ETH`);
console.log(`卖出价格: ${ethers.utils.formatEther(priceInfo.sellPrice)} ETH`);
```

### Python 示例

```python
from web3 import Web3

# 连接 Web3
w3 = Web3(Web3.HTTPProvider('http://localhost:8545'))

# 调用合约
exists = pair_info_provider.functions.poolExists(pair_address).call()
is_active, is_paused, has_liquidity = pair_info_provider.functions.getPoolStatus(pair_address).call()

# 获取池子信息
pool_info = pair_info_provider.functions.getPoolInfo(pair_address).call()
eth_reserve = Web3.fromWei(pool_info[2], 'ether')  # ethReserve
nft_reserve = pool_info[3]  # nftReserve
current_price = Web3.fromWei(pool_info[4], 'ether')  # currentPrice
```

## 错误处理

合约定义了以下错误类型：

- `InvalidPairAddress()` - 无效的 Pair 合约地址
- `PairNotDeployed()` - Pair 合约未部署

## 事件

合约会触发以下事件：

- `PoolInfoQueried(address indexed pairAddress, address indexed querier)` - 池子信息查询事件
- `PriceInfoQueried(address indexed pairAddress, address indexed querier)` - 价格信息查询事件
- `LiquidityInfoQueried(address indexed pairAddress, address indexed querier)` - 流动性信息查询事件

## 应用场景

### 1. 池子监控面板
- 实时显示池子状态
- 监控价格变化
- 跟踪流动性变化

### 2. 交易策略
- 基于价格信息制定交易策略
- 监控滑点和费用
- 分析交易历史

### 3. 风险管理
- 检查池子健康状态
- 监控流动性水平
- 跟踪费用积累

### 4. 数据分析
- 统计交易数据
- 分析价格趋势
- 计算收益率

## 部署地址

- **PairInfoProvider**: `0x6e0a5725dD4071e46356bD974E13F35DbF9ef367`
- **测试 Pair**: `0x1eB5C49630E08e95Ba7f139BcF4B9BA171C9a8C7`
- **测试 NFT**: `0xd977422c9eE9B646f64A4C4389a6C98ad356d8C4`

## 演示脚本

运行演示脚本来查看 PairInfoProvider 的功能：

```bash
./scripts/pair_info_demo.sh
```

## 注意事项

1. 所有查询函数都是 `view` 函数，不会修改链上状态
2. 批量查询功能适用于需要同时查询多个池子的场景
3. 交易历史查询返回的是 `Pair.Trade[]` 数组
4. LP Token 信息查询包含错误处理，如果查询失败会返回默认值
5. 统计信息计算基于交易历史，可能不是完全准确的实时数据

## 许可证

MIT License
