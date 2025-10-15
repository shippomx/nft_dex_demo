# NFT DEX API

一个基于 Fastify 的 NFT 去中心化交易所 REST API 服务器，提供合约部署、流动性管理、NFT 交易等功能。

## 🚀 功能特性

- **合约部署**: 支持 NFT 合约、Pair 合约、PairFactory 合约的部署
- **流动性管理**: 添加/移除流动性，LP 代币管理
- **NFT 交易**: 买入/卖出 NFT，价格查询
- **池子管理**: 池子信息查询，储备量监控
- **Web3 集成**: 区块链交互，交易管理
- **API 文档**: 完整的 Swagger 文档
- **错误处理**: 统一的错误处理和日志记录

## 📋 目录结构

```
api/
├── src/
│   ├── controllers/          # 控制器层
│   │   ├── deployController.ts    # 合约部署控制器
│   │   ├── poolController.ts      # 池子管理控制器
│   │   └── tradeController.ts     # 交易控制器
│   ├── routes/               # 路由层
│   │   ├── deploy.ts         # 部署相关路由
│   │   ├── pool.ts           # 池子管理路由
│   │   ├── trade.ts          # 交易路由
│   │   └── web3.ts           # Web3 相关路由
│   ├── services/             # 服务层
│   │   ├── contracts/        # 合约服务
│   │   │   ├── contractService.ts  # 合约交互服务
│   │   │   ├── bytecodeLoader.ts   # 字节码加载器
│   │   │   └── abis.ts            # 合约 ABI 定义
│   │   └── web3Service.ts    # Web3 服务
│   ├── utils/                # 工具类
│   │   ├── logger.ts         # 日志工具
│   │   └── errors.ts         # 错误处理
│   ├── config/               # 配置
│   │   └── index.ts          # 配置文件
│   └── index.ts              # 应用入口
├── scripts/                  # 脚本文件
│   ├── deploy-and-create-pool.sh  # 部署和创建池子脚本
│   ├── start-server.sh       # 启动服务器脚本
│   └── start.sh              # 启动脚本
├── tests/                    # 测试文件
├── docs/                     # 文档
├── logs/                     # 日志文件
├── dist/                     # 编译输出
├── package.json              # 项目配置
├── tsconfig.json             # TypeScript 配置
├── jest.config.js            # Jest 配置
└── README.md                 # 项目说明
```

## 🛠️ 技术栈

- **框架**: Fastify 4.x
- **语言**: TypeScript
- **区块链**: Ethers.js 6.x
- **文档**: Swagger/OpenAPI
- **日志**: Winston + Pino
- **测试**: Jest
- **开发**: Nodemon + ts-node

## 📦 安装和运行

### 环境要求

- Node.js >= 18.0.0
- npm >= 8.0.0
- 本地以太坊节点 (Anvil/Foundry)

### 安装依赖

```bash
cd api
npm install
```

### 环境配置

创建 `.env` 文件：

```bash
# 服务器配置
PORT=3000
HOST=0.0.0.0
NODE_ENV=development

# 区块链配置
RPC_URL=http://localhost:8545
CHAIN_ID=31337
PRIVATE_KEY=your_private_key_here

# 合约地址 (可选，可通过 API 设置)
NFT_CONTRACT_ADDRESS=
PAIR_CONTRACT_ADDRESS=
PAIR_FACTORY_ADDRESS=

# 日志配置
LOG_LEVEL=info
LOG_FILE=logs/app.log

# API 配置
API_PREFIX=/api/v1
CORS_ORIGIN=*
```

### 开发模式

```bash
npm run dev
```

### 生产模式

```bash
# 编译
npm run build

# 启动
npm start
```

## 📚 API 文档

### 基础信息

- **Base URL**: `http://localhost:3000`
- **API Prefix**: `/api/v1`
- **文档地址**: `http://localhost:3000/docs`
- **健康检查**: `http://localhost:3000/health`

### 主要端点

#### 1. 合约部署 (`/deploy`)

| 方法 | 端点 | 描述 |
|------|------|------|
| POST | `/deploy/nft` | 部署 NFT 合约 |
| POST | `/deploy/pair` | 部署 Pair 合约 |
| POST | `/deploy/pair-factory` | 部署 PairFactory 合约 |
| GET | `/deploy/contracts` | 获取已部署的合约地址 |
| PUT | `/deploy/contracts` | 更新合约地址 |

#### 2. 池子管理 (`/pool`)

| 方法 | 端点 | 描述 |
|------|------|------|
| POST | `/pool/create` | 创建流动性池 |
| POST | `/pool/add-liquidity` | 添加流动性 |
| POST | `/pool/remove-liquidity` | 移除流动性 |
| POST | `/pool/approve-nft` | 授权单个 NFT |
| POST | `/pool/batch-approve-nft` | 批量授权 NFT |
| GET | `/pool/:nftContractAddress` | 获取池子信息 |
| GET | `/pool/reserves` | 获取池子储备量 |

#### 3. 交易功能 (`/trade`)

| 方法 | 端点 | 描述 |
|------|------|------|
| POST | `/trade/mint` | 铸造 NFT |
| POST | `/trade/buy` | 买入 NFT |
| POST | `/trade/sell` | 卖出 NFT |
| GET | `/trade/price` | 获取价格信息 |
| GET | `/trade/history` | 获取交易历史 |
| GET | `/trade/recent` | 获取最近交易 |
| GET | `/trade/quote` | 获取买入报价 |

#### 4. Web3 功能 (`/web3`)

| 方法 | 端点 | 描述 |
|------|------|------|
| GET | `/web3/health` | Web3 服务健康检查 |
| POST | `/web3/reset-nonce` | 重置 nonce |

### 请求示例

#### 部署 NFT 合约

```bash
curl -X POST http://localhost:3000/api/v1/deploy/nft \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test NFT Collection",
    "symbol": "TNFT",
    "baseURI": "https://api.test.com/metadata/",
    "maxSupply": 1000,
    "maxMintPerAddress": 10,
    "mintPrice": "0.01"
  }'
```

#### 创建流动性池

```bash
curl -X POST http://localhost:3000/api/v1/pool/create \
  -H "Content-Type: application/json" \
  -d '{
    "nftContractAddress": "0x..."
  }'
```

#### 添加流动性

```bash
curl -X POST http://localhost:3000/api/v1/pool/add-liquidity \
  -H "Content-Type: application/json" \
  -d '{
    "nftContractAddress": "0x...",
    "nftTokenIds": [1, 2, 3],
    "ethAmount": "0.1"
  }'
```

#### 买入 NFT

```bash
curl -X POST http://localhost:3000/api/v1/trade/buy \
  -H "Content-Type: application/json" \
  -d '{
    "maxPrice": "0.1"
  }'
```

#### 卖出 NFT

```bash
curl -X POST http://localhost:3000/api/v1/trade/sell \
  -H "Content-Type: application/json" \
  -d '{
    "tokenId": 1,
    "minPrice": "0.05"
  }'
```

### 快速测试

```bash
# API 快速测试
npm run test:api

# 字节码部署测试
npm run test:bytecode
```

## 🧪 测试

### 运行测试

```bash
# 运行所有测试
npm test

# 运行 API 测试
npm run test:api

# 运行快速测试
npm run test:quick
```

### 测试覆盖

- 单元测试: 控制器和服务层
- 集成测试: API 端点
- 端到端测试: 完整业务流程

## 📊 监控和日志

### 日志配置

- **开发环境**: 控制台输出 + 文件日志
- **生产环境**: 结构化 JSON 日志
- **日志级别**: error, warn, info, debug

### 健康检查

```bash
# 应用健康检查
curl http://localhost:3000/health

# Web3 服务健康检查
curl http://localhost:3000/api/v1/web3/health
```

### 监控指标

- 请求响应时间
- 错误率
- 区块链连接状态
- 合约调用成功率

## 🔒 安全特性

- **CORS 支持**: 可配置的跨域资源共享
- **安全头**: Helmet.js 安全头设置
- **输入验证**: JSON Schema 验证
- **错误处理**: 统一的错误响应格式
- **日志记录**: 详细的操作日志

## 🚀 部署

### Docker 部署

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY dist/ ./dist/
EXPOSE 3000
CMD ["npm", "start"]
```

### 环境变量

生产环境需要设置以下环境变量：

```bash
NODE_ENV=production
RPC_URL=https://your-ethereum-node.com
PRIVATE_KEY=your_production_private_key
LOG_LEVEL=info
```