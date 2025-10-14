# API 测试脚本使用指南

## 📋 脚本概述

我们创建了两个测试脚本来验证 NFT DEX API 的功能：

1. **完整测试脚本** (`test-api.sh`) - 全面的 API 测试
2. **快速测试脚本** (`quick-test.sh`) - 简化的快速测试

## 🚀 使用方法

### 1. 完整测试脚本

```bash
# 运行所有测试
./scripts/test-api.sh

# 交互式测试模式
./scripts/test-api.sh -i

# 指定不同的服务器地址
./scripts/test-api.sh -u http://localhost:8080

# 显示帮助信息
./scripts/test-api.sh -h
```

### 2. 快速测试脚本

```bash
# 快速测试所有主要接口
./scripts/quick-test.sh
```

## 📊 测试覆盖范围

### 系统接口
- ✅ 健康检查 (`/health`)
- ✅ 根路径 (`/`)
- ✅ API 文档 (`/docs`)

### 部署接口
- ✅ 获取已部署合约地址 (`GET /api/v1/deploy/contracts`)
- ✅ 更新合约地址 (`PUT /api/v1/deploy/contracts`)
- ⚠️ 部署 NFT 合约 (`POST /api/v1/deploy/nft`) - 需要字节码
- ⚠️ 部署 Pair 合约 (`POST /api/v1/deploy/pair`) - 需要字节码
- ⚠️ 部署 MultiPoolManager 合约 (`POST /api/v1/deploy/multi-pool-manager`) - 需要字节码

### 池子管理接口
- ⚠️ 获取所有池子 (`GET /api/v1/pool`) - 需要合约地址
- ⚠️ 获取池子储备量 (`GET /api/v1/pool/reserves`) - 需要合约地址
- ⚠️ 创建流动性池 (`POST /api/v1/pool/create`) - 需要合约地址
- ⚠️ 添加流动性 (`POST /api/v1/pool/add-liquidity`) - 需要合约地址
- ⚠️ 删除流动性 (`POST /api/v1/pool/remove-liquidity`) - 需要合约地址
- ⚠️ 获取指定池子信息 (`GET /api/v1/pool/:address`) - 需要合约地址

### 交易接口
- ⚠️ 获取价格信息 (`GET /api/v1/trade/price`) - 需要合约地址
- ⚠️ 获取买入报价 (`GET /api/v1/trade/quote`) - 需要合约地址
- ⚠️ 获取交易历史 (`GET /api/v1/trade/history`) - 需要合约地址
- ⚠️ 获取最近交易 (`GET /api/v1/trade/recent`) - 需要合约地址
- ⚠️ 买入 NFT (`POST /api/v1/trade/buy`) - 需要合约地址
- ⚠️ 卖出 NFT (`POST /api/v1/trade/sell`) - 需要合约地址

### 错误处理测试
- ✅ 404 错误测试 (`GET /nonexistent`)
- ✅ 无效请求数据测试
- ✅ 无效合约地址格式测试

## 🔧 测试状态说明

- ✅ **成功** - 接口正常工作
- ⚠️ **预期失败** - 由于缺少必要配置（如合约地址、字节码）而失败，这是正常的
- ❌ **实际错误** - 需要修复的问题

## 📝 测试示例

### 1. 健康检查测试
```bash
curl -X GET http://localhost:3000/health
```

**预期响应：**
```json
{
  "status": "ok",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "uptime": 123.45,
  "version": "1.0.0"
}
```

### 2. 获取合约地址测试
```bash
curl -X GET http://localhost:3000/api/v1/deploy/contracts
```

**预期响应：**
```json
{
  "success": true,
  "message": "Deployed contract addresses retrieved successfully",
  "data": {
    "nftContract": null,
    "pairContract": null,
    "multiPoolManager": null
  }
}
```

### 3. 更新合约地址测试
```bash
curl -X PUT http://localhost:3000/api/v1/deploy/contracts \
  -H "Content-Type: application/json" \
  -d '{
    "nftContract": "0x1234567890123456789012345678901234567890",
    "pairContract": "0x2345678901234567890123456789012345678901"
  }'
```

**预期响应：**
```json
{
  "success": true,
  "message": "Contract addresses updated successfully",
  "data": {
    "nftContract": "0x1234567890123456789012345678901234567890",
    "pairContract": "0x2345678901234567890123456789012345678901"
  }
}
```

## 🛠️ 故障排除

### 1. 服务器未运行
**错误信息：** `Server is not running at http://localhost:3000`

**解决方案：**
```bash
cd api
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 npm start
```

### 2. 端口被占用
**错误信息：** `Port 3000 is already in use`

**解决方案：**
```bash
# 查找占用端口的进程
lsof -i :3000

# 杀死进程
kill -9 <PID>

# 或使用不同端口
API_BASE_URL=http://localhost:3001 ./scripts/test-api.sh
```

### 3. 合约相关错误
**错误信息：** `Contract address not set` 或 `Contract call failed`

**解决方案：**
1. 先更新合约地址：
```bash
curl -X PUT http://localhost:3000/api/v1/deploy/contracts \
  -H "Content-Type: application/json" \
  -d '{
    "nftContract": "0x...",
    "pairContract": "0x..."
  }'
```

2. 确保合约已部署且地址正确

## 📈 性能测试

### 并发测试
```bash
# 使用 Apache Bench 进行并发测试
ab -n 100 -c 10 http://localhost:3000/health
```

### 压力测试
```bash
# 使用 wrk 进行压力测试
wrk -t12 -c400 -d30s http://localhost:3000/health
```

## 🔍 调试技巧

### 1. 启用详细日志
```bash
# 设置环境变量启用详细输出
VERBOSE=true ./scripts/test-api.sh
```

### 2. 查看服务器日志
```bash
# 查看实时日志
tail -f logs/app.log
```

### 3. 使用 curl 手动测试
```bash
# 测试特定接口
curl -v -X GET http://localhost:3000/api/v1/trade/price

# 查看响应头
curl -I http://localhost:3000/health
```

## 📚 相关文档

- [API 使用指南](../API_GUIDE.md)
- [项目 README](../README.md)
- [Swagger 文档](http://localhost:3000/docs)

## 🤝 贡献

如果您发现测试脚本的问题或有改进建议，请：

1. 提交 Issue
2. 创建 Pull Request
3. 联系开发团队

---

**注意：** 这些测试脚本主要用于验证 API 的基本功能。在生产环境中，建议使用更专业的测试工具如 Postman、Newman 或自动化测试框架。
