# Sepolia 测试网部署指南

## 环境准备

### 1. 安装依赖
```bash
# 安装 Foundry
curl -L https://foundry.rustup.rs | sh
foundryup

# 安装项目依赖
forge install
```

### 2. 配置环境变量
创建 `.env` 文件并配置以下变量：

```bash
# 私钥 (不要包含 0x 前缀)
PRIVATE_KEY=your_private_key_here

# RPC 端点 API 密钥 (选择其中一个)
INFURA_API_KEY=your_infura_api_key_here
ALCHEMY_API_KEY=your_alchemy_api_key_here

# Etherscan API 密钥 (用于验证合约)
ETHERSCAN_API_KEY=your_etherscan_api_key_here
```

### 3. 获取测试网 ETH
访问 [Sepolia Faucet](https://sepoliafaucet.com/) 获取测试网 ETH。

## 部署步骤

### 1. 编译合约
```bash
forge build
```

### 2. 部署 AMM 系统
```bash
# 使用 Infura
forge script script/DeployAMMSystem.s.sol:DeployAMMSystem --rpc-url sepolia --broadcast --verify

# 或使用 Alchemy
forge script script/DeployAMMSystem.s.sol:DeployAMMSystem --rpc-url alchemy_sepolia --broadcast --verify
```

### 3. 部署多池系统
```bash
# 使用 Infura
forge script script/DeployMultiPoolSystem.s.sol:DeployMultiPoolSystem --rpc-url sepolia --broadcast --verify

# 或使用 Alchemy
forge script script/DeployMultiPoolSystem.s.sol:DeployMultiPoolSystem --rpc-url alchemy_sepolia --broadcast --verify
```

## 验证部署

部署完成后，您将看到以下信息：
- 合约地址
- 交易哈希
- 部署摘要

## 测试合约功能

部署完成后，您可以使用以下方式测试：

1. 在 Etherscan 上查看合约
2. 使用 Foundry 脚本与合约交互
3. 通过前端界面进行测试

## 注意事项

- 确保有足够的 Sepolia ETH 支付 Gas 费用
- 私钥安全：不要将私钥提交到版本控制
- 测试网限制：某些功能可能在测试网上有限制
