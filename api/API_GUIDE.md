# NFT DEX API 使用指南

## 🚀 快速开始

### 1. 启动服务器

```bash
# 开发模式
npm run dev

# 或使用启动脚本
./scripts/start.sh
```

### 2. 访问 API 文档

打开浏览器访问：http://localhost:3000/docs

### 3. 运行演示脚本

```bash
node examples/api-demo.js
```

## 📋 API 接口总览

### 部署接口

| 方法 | 路径 | 描述 |
|------|------|------|
| POST | `/api/v1/deploy/nft` | 部署 NFT 合约 |
| POST | `/api/v1/deploy/pair` | 部署 Pair 合约 |
| POST | `/api/v1/deploy/multi-pool-manager` | 部署多池管理器 |
| GET | `/api/v1/deploy/contracts` | 获取已部署合约地址 |
| PUT | `/api/v1/deploy/contracts` | 更新合约地址 |

### 池子管理接口

| 方法 | 路径 | 描述 |
|------|------|------|
| POST | `/api/v1/pool/create` | 创建流动性池 |
| POST | `/api/v1/pool/add-liquidity` | 添加流动性 |
| POST | `/api/v1/pool/remove-liquidity` | 删除流动性 |
| GET | `/api/v1/pool/:nftContractAddress` | 获取指定池子信息 |
| GET | `/api/v1/pool` | 获取所有池子 |
| GET | `/api/v1/pool/reserves` | 获取池子储备量 |

### 交易接口

| 方法 | 路径 | 描述 |
|------|------|------|
| POST | `/api/v1/trade/buy` | 买入 NFT |
| POST | `/api/v1/trade/sell` | 卖出 NFT |
| GET | `/api/v1/trade/price` | 获取价格信息 |
| GET | `/api/v1/trade/history` | 获取交易历史 |
| GET | `/api/v1/trade/recent` | 获取最近交易 |
| GET | `/api/v1/trade/quote` | 获取买入报价 |
| GET | `/api/v1/trade/reserves` | 获取池子储备量 |

## 🔧 详细使用示例

### 1. 部署 NFT 合约

```bash
curl -X POST http://localhost:3000/api/v1/deploy/nft \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My NFT Collection",
    "symbol": "MNC",
    "baseURI": "https://api.example.com/metadata/",
    "maxSupply": 1000,
    "maxMintPerAddress": 50,
    "mintPrice": "0.01"
  }'
```

**响应示例：**
```json
{
  "success": true,
  "message": "NFT contract deployed successfully",
  "data": {
    "contractAddress": "0x1234567890123456789012345678901234567890",
    "name": "My NFT Collection",
    "symbol": "MNC",
    "baseURI": "https://api.example.com/metadata/",
    "maxSupply": 1000,
    "maxMintPerAddress": 50,
    "mintPrice": "0.01"
  }
}
```

### 2. 部署 Pair 合约

```bash
curl -X POST http://localhost:3000/api/v1/deploy/pair \
  -H "Content-Type: application/json" \
  -d '{
    "nftContractAddress": "0x1234567890123456789012345678901234567890"
  }'
```

### 3. 创建流动性池

```bash
curl -X POST http://localhost:3000/api/v1/pool/create \
  -H "Content-Type: application/json" \
  -d '{
    "nftContractAddress": "0x1234567890123456789012345678901234567890",
    "nftTokenIds": [1, 2, 3, 4, 5],
    "ethAmount": "1.0"
  }'
```

### 4. 添加流动性

```bash
curl -X POST http://localhost:3000/api/v1/pool/add-liquidity \
  -H "Content-Type: application/json" \
  -d '{
    "nftTokenIds": [6, 7, 8],
    "ethAmount": "0.5"
  }'
```

### 5. 买入 NFT

```bash
curl -X POST http://localhost:3000/api/v1/trade/buy \
  -H "Content-Type: application/json" \
  -d '{
    "maxPrice": "0.1"
  }'
```

### 6. 卖出 NFT

```bash
curl -X POST http://localhost:3000/api/v1/trade/sell \
  -H "Content-Type: application/json" \
  -d '{
    "tokenId": 1,
    "minPrice": "0.05"
  }'
```

### 7. 查询价格信息

```bash
# 获取当前价格
curl http://localhost:3000/api/v1/trade/price?type=current

# 获取卖出价格
curl http://localhost:3000/api/v1/trade/price?type=sell

# 获取买入报价
curl http://localhost:3000/api/v1/trade/price?type=buy

# 获取所有价格信息
curl http://localhost:3000/api/v1/trade/price
```

### 8. 查询交易历史

```bash
# 获取最近 10 条交易
curl http://localhost:3000/api/v1/trade/history?limit=10&offset=0

# 获取最近交易
curl http://localhost:3000/api/v1/trade/recent?count=5
```

### 9. 查询池子信息

```bash
# 获取指定池子信息
curl http://localhost:3000/api/v1/pool/0x1234567890123456789012345678901234567890

# 获取所有池子
curl http://localhost:3000/api/v1/pool

# 获取池子储备量
curl http://localhost:3000/api/v1/pool/reserves
```

## 🔍 错误处理

### 常见错误类型

1. **ValidationError**: 请求参数验证失败
2. **ContractError**: 合约调用失败
3. **BlockchainError**: 区块链网络错误
4. **InternalError**: 服务器内部错误

### 错误响应格式

```json
{
  "success": false,
  "error": {
    "message": "Error description",
    "code": 400,
    "type": "ValidationError",
    "details": {
      "field": "error details"
    }
  }
}
```

### 常见错误码

- `400`: 请求参数错误
- `404`: 资源未找到
- `500`: 服务器内部错误
- `503`: 服务不可用

## 🛠️ 开发指南

### 项目结构

```
api/
├── src/
│   ├── config/           # 配置文件
│   ├── controllers/      # 控制器
│   ├── routes/          # 路由定义
│   ├── services/        # 服务层
│   │   └── contracts/   # 合约相关服务
│   ├── utils/           # 工具函数
│   └── index.ts         # 主入口文件
├── tests/               # 测试文件
├── examples/            # 示例脚本
├── scripts/             # 工具脚本
└── docs/                # 文档
```

### 添加新接口

1. 在 `src/controllers/` 中创建控制器
2. 在 `src/routes/` 中定义路由
3. 在 `src/index.ts` 中注册路由
4. 添加相应的测试用例

### 环境变量配置

| 变量名 | 描述 | 默认值 |
|--------|------|--------|
| `PORT` | 服务器端口 | 3000 |
| `HOST` | 服务器主机 | 0.0.0.0 |
| `RPC_URL` | 区块链 RPC 端点 | http://localhost:8545 |
| `PRIVATE_KEY` | 私钥 | - |
| `LOG_LEVEL` | 日志级别 | info |

## 🧪 测试

### 运行测试

```bash
# 运行所有测试
npm test

# 运行特定测试
npm test -- --testNamePattern="API Tests"

# 生成覆盖率报告
npm run test -- --coverage
```

### 测试覆盖

- 单元测试：控制器、服务层
- 集成测试：API 端点
- 端到端测试：完整流程

## 📊 监控和日志

### 日志级别

- `error`: 错误信息
- `warn`: 警告信息
- `info`: 一般信息
- `debug`: 调试信息

### 日志格式

```json
{
  "timestamp": "2024-01-01T00:00:00.000Z",
  "level": "info",
  "message": "Server started",
  "port": 3000,
  "host": "0.0.0.0"
}
```

### 健康检查

```bash
curl http://localhost:3000/health
```

## 🔒 安全注意事项

1. **私钥安全**: 确保私钥安全存储
2. **网络安全**: 生产环境使用 HTTPS
3. **访问控制**: 实现适当的 API 访问控制
4. **输入验证**: 所有输入都经过严格验证
5. **错误处理**: 避免泄露敏感信息

## 📞 支持和反馈

如有问题或建议，请：

1. 查看 [API 文档](http://localhost:3000/docs)
2. 检查 [常见问题](#常见问题)
3. 提交 [GitHub Issue]
4. 联系开发团队

## 📄 许可证

MIT License
