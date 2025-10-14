#!/bin/bash

# NFT DEX API 服务器启动脚本

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== NFT DEX API 服务器启动脚本 ===${NC}"
echo ""

# 检查是否在正确的目录
if [ ! -f "package.json" ]; then
    echo -e "${RED}错误: 请在 api 目录中运行此脚本${NC}"
    echo "使用方法: cd api && ./scripts/start-server.sh"
    exit 1
fi

# 检查 Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}错误: 未找到 Node.js${NC}"
    echo "请先安装 Node.js 18+"
    exit 1
fi

# 检查依赖
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}安装依赖...${NC}"
    npm install
fi

# 检查构建文件
if [ ! -d "dist" ]; then
    echo -e "${YELLOW}构建项目...${NC}"
    npm run build
fi

# 设置环境变量
export PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
export RPC_URL="http://localhost:8545"
export PORT="3000"
export HOST="0.0.0.0"
export NODE_ENV="development"

echo -e "${GREEN}环境变量已设置${NC}"
echo "  PRIVATE_KEY: ${PRIVATE_KEY:0:10}..."
echo "  RPC_URL: $RPC_URL"
echo "  PORT: $PORT"
echo "  HOST: $HOST"
echo ""

# 检查端口是否被占用
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${YELLOW}警告: 端口 $PORT 已被占用${NC}"
    echo "正在尝试停止现有进程..."
    lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
    sleep 2
fi

echo -e "${BLUE}启动服务器...${NC}"
echo "服务器将在 http://localhost:$PORT 启动"
echo "API 文档: http://localhost:$PORT/docs"
echo "健康检查: http://localhost:$PORT/health"
echo ""
echo -e "${YELLOW}按 Ctrl+C 停止服务器${NC}"
echo ""

# 启动服务器
npm start
