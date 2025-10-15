# NFT DEX API Server

基于 Fastify 框架构建的 NFT DEX REST API 服务器，提供合约部署、流动性管理、交易等功能。

## 🚀 功能特性

- **合约部署**: 部署 NFT 合约、Pair 合约、PairFactory 合约
- **流动性管理**: 创建池子、添加/删除流动性
- **交易功能**: 买入/卖出 NFT、价格查询
- **池子管理**: 多池系统管理、池子信息查询
- **实时监控**: 价格监控、交易历史查询
- **API 文档**: 完整的 Swagger 文档
- **错误处理**: 统一的错误处理和日志记录

## 📋 系统要求

- Node.js >= 18.0.0
- npm >= 8.0.0
- 以太坊网络连接（本地或测试网）

## 🛠️ 安装和运行

### 1. 安装依赖

```bash
cd api
npm install
```

### 2. 配置环境变量

复制环境变量模板文件：

```bash
cp env.example .env
```

编辑 `.env` 文件，配置以下变量：

```bash
# 服务器配置
PORT=3000
HOST=0.0.0.0
NODE_ENV=development

# 区块链网络配置
RPC_URL=http://localhost:8545
CHAIN_ID=31337
PRIVATE_KEY=your_private_key_here

# 合约地址（部署后更新）
NFT_CONTRACT_ADDRESS=
PAIR_CONTRACT_ADDRESS=
MULTI_POOL_MANAGER_ADDRESS=

# 日志配置
LOG_LEVEL=info
LOG_FILE=logs/app.log

# API 配置
API_PREFIX=/api/v1
CORS_ORIGIN=*

# 安全配置
JWT_SECRET=your_jwt_secret_here
RATE_LIMIT_MAX=100
RATE_LIMIT_TIME_WINDOW=60000
```

### 3. 运行服务器

#### 开发模式

```bash
npm run dev
```

#### 生产模式

```bash
# 构建项目
npm run build

# 运行服务器
npm start
```

## 📚 API 文档

启动服务器后，访问以下地址查看 API 文档：

- **Swagger UI**: http://localhost:3000/docs
- **健康检查**: http://localhost:3000/health
- **API 根路径**: http://localhost:3000/

## 🔧 API 接口

### 部署接口

#### 部署 NFT 合约
```http
POST /api/v1/deploy/nft
Content-Type: application/json

{
  "name": "Test NFT Collection",
  "symbol": "TESTNFT",
  "baseURI": "https://api.example.com/metadata/",
  "maxSupply": 1000,
  "maxMintPerAddress": 50,
  "mintPrice": "0.01"
}
```

#### 部署 Pair 合约
```http
POST /api/v1/deploy/pair
Content-Type: application/json

{
  "nftContractAddress": "0x..."
}
```

#### 部署 PairFactory 合约
```http
POST /api/v1/deploy/multi-pool-manager
Content-Type: application/json

{}
```

### 池子管理接口

#### 创建流动性池
```http
POST /api/v1/pool/create
Content-Type: application/json

{
  "nftContractAddress": "0x...",
  "nftTokenIds": [1, 2, 3],
  "ethAmount": "1.0"
}
```

#### 添加流动性
```http
POST /api/v1/pool/add-liquidity
Content-Type: application/json

{
  "nftTokenIds": [4, 5, 6],
  "ethAmount": "0.5"
}
```

#### 获取池子信息
```http
GET /api/v1/pool/0x...
```

### 交易接口

#### 买入 NFT
```http
POST /api/v1/trade/buy
Content-Type: application/json

{
  "maxPrice": "0.1"
}
```

#### 卖出 NFT
```http
POST /api/v1/trade/sell
Content-Type: application/json

{
  "tokenId": 1,
  "minPrice": "0.05"
}
```

#### 获取价格信息
```http
GET /api/v1/trade/price?type=current
```

#### 获取交易历史
```http
GET /api/v1/trade/history?limit=50&offset=0
```

## 🏗️ 项目结构

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
├── docs/                # 文档
├── package.json
├── tsconfig.json
└── README.md
```

## 🔒 安全注意事项

1. **私钥安全**: 确保私钥安全存储，不要提交到版本控制
2. **网络安全**: 在生产环境中使用 HTTPS
3. **访问控制**: 实现适当的 API 访问控制
4. **输入验证**: 所有输入都经过严格验证

## 🐛 故障排除

### 常见问题

1. **连接区块链失败**
   - 检查 RPC_URL 是否正确
   - 确保网络连接正常
   - 验证私钥格式

2. **合约部署失败**
   - 检查账户余额是否足够
   - 验证合约地址格式
   - 查看日志获取详细错误信息

3. **交易失败**
   - 检查 Gas 费用设置
   - 验证交易参数
   - 确保有足够的 ETH 余额

### 日志查看

```bash
# 查看应用日志
tail -f logs/app.log

# 查看实时日志
npm run dev
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

## 📞 支持

如有问题，请联系：
- Email: team@nftdex.com
- GitHub Issues: [项目 Issues 页面]
