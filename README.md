# NFT DEX Sepolia 部署报告

## 🎉 部署成功！

**部署时间**: $(date)  
**网络**: Sepolia 测试网  
**RPC 端点**: https://sepolia.infura.io/v3/ff6896ca6835453f965911119da38dff

## 📋 合约地址

| 合约类型 | 地址 | Etherscan 链接 |
|---------|------|----------------|
| **NFT 合约** | `0x15D79A5f7883D6802F6763DBC3e0414B0A61CAA1` | [查看](https://sepolia.etherscan.io/address/0x15D79A5f7883D6802F6763DBC3e0414B0A61CAA1) |
| **AMM 合约** | `0x66116ca01984953188289A87F3Af79b154612D87` | [查看](https://sepolia.etherscan.io/address/0x66116ca01984953188289A87F3Af79b154612D87) |

## 🔧 合约配置

### NFT 合约参数
- **名称**: AMM NFT Collection
- **符号**: AMMNFT
- **基础 URI**: https://api.example.com/metadata/
- **最大供应量**: 1,000
- **单地址最大铸造**: 50
- **铸造价格**: 0.0001 ETH
- **当前总供应量**: 20

### AMM 合约参数
- **初始 ETH 储备**: 0.000001 ETH (1,000,000,000 wei)
- **初始 NFT 储备**: 20
- **初始价格**: 0.00000005 ETH per NFT
- **交易手续费**: 200 basis points (2%)
- **最大滑点**: 500 basis points (5%)

## 💰 部署者信息

- **部署者地址**: `0x10E2F55d428ee8214452E5F9B177DE541F9b987F`
- **部署后余额**: 约 0.149 ETH
- **Gas 消耗**: 16,675,316 gas
- **Gas 费用**: 约 0.0000167 ETH

## 🚀 功能验证

✅ **NFT 合约部署成功**  
✅ **AMM 合约部署成功**  
✅ **初始流动性添加成功**  
✅ **NFT 预铸造成功**  
✅ **合约所有权转移成功**  
✅ **价格计算正确**  

## 📊 交易记录

所有交易记录已保存到:
- `broadcast/DeployAMMSystem.s.sol/11155111/run-latest.json`
- `cache/DeployAMMSystem.s.sol/11155111/run-latest.json`

## 🔍 下一步操作

1. **验证合约**: 在 Etherscan 上验证合约源码
2. **测试功能**: 使用测试脚本验证交易功能
3. **监控价格**: 使用价格监控脚本跟踪价格变化
4. **添加流动性**: 根据需要添加更多流动性

## 🛠️ 常用命令

```bash
# 检查合约状态
cast call 0x15D79A5f7883D6802F6763DBC3e0414B0A61CAA1 "totalSupply()" --rpc-url sepolia
cast call 0x66116ca01984953188289A87F3Af79b154612D87 "getCurrentPrice()" --rpc-url sepolia

# 运行测试
forge test --match-contract PairTest --rpc-url sepolia

# 价格监控
./scripts/price_monitor.sh
```

---

# 本地运行测试

**just run ./scripts/demo.sh with a local anvil account private key.**

demo.log shows the details.
