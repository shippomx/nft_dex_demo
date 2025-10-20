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

# 检查 .env 文件
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}警告: 未找到 .env 文件${NC}"
    echo "从 env.example 创建 .env 文件..."
    cp env.example .env
    echo -e "${GREEN}.env 文件已创建，请根据需要修改配置${NC}"
fi

# 加载环境变量（如果需要覆盖，可以在这里设置）
# 注意：以下环境变量将从 .env 文件自动加载
# 如果需要临时覆盖，可以取消注释下面的行

# export PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
# export RPC_URL="http://localhost:8545"
# export PORT="3000"
# export HOST="0.0.0.0"
# export NODE_ENV="development"

echo -e "${GREEN}环境配置${NC}"
echo "  配置文件: .env"
echo "  请确保 .env 文件中的配置正确"
echo ""

# 读取端口配置（用于脚本中的检查）
PORT=${PORT:-3000}

# 检查端口是否被占用
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${YELLOW}警告: 端口 $PORT 已被占用${NC}"
    echo "正在尝试停止现有进程..."
    lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
    sleep 2
fi

echo -e "${BLUE}启动服务器...${NC}"
echo "服务器配置从 .env 文件读取"
echo "预期端口: $PORT (如果 .env 中有不同配置，将使用 .env 中的值)"
echo ""
echo -e "${YELLOW}按 Ctrl+C 停止服务器${NC}"
echo ""

# 启动服务器
npm start
