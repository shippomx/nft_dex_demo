#!/bin/bash

# NFT DEX API Server 启动脚本

echo "=== NFT DEX API Server 启动脚本 ==="

# 检查 Node.js 版本
echo "🔍 检查 Node.js 版本..."
if ! command -v node &> /dev/null; then
    echo "❌ 错误: 未找到 Node.js，请先安装 Node.js 18+"
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ 错误: Node.js 版本过低，需要 18+，当前版本: $(node -v)"
    exit 1
fi

echo "✅ Node.js 版本: $(node -v)"

# 检查 npm 版本
echo "🔍 检查 npm 版本..."
if ! command -v npm &> /dev/null; then
    echo "❌ 错误: 未找到 npm"
    exit 1
fi

echo "✅ npm 版本: $(npm -v)"

# 检查环境变量文件
echo "🔍 检查环境变量配置..."
if [ ! -f ".env" ]; then
    if [ -f "env.example" ]; then
        echo "📋 创建环境变量文件..."
        cp env.example .env
        echo "✅ 已创建 .env 文件，请编辑配置后重新运行"
        echo "   主要配置项："
        echo "   - RPC_URL: 区块链 RPC 端点"
        echo "   - PRIVATE_KEY: 私钥"
        echo "   - PORT: 服务器端口"
        exit 1
    else
        echo "❌ 错误: 未找到环境变量文件"
        exit 1
    fi
fi

echo "✅ 环境变量文件存在"

# 检查依赖是否安装
echo "🔍 检查依赖..."
if [ ! -d "node_modules" ]; then
    echo "📦 安装依赖..."
    npm install
    if [ $? -ne 0 ]; then
        echo "❌ 依赖安装失败"
        exit 1
    fi
fi

echo "✅ 依赖已安装"

# 创建日志目录
echo "📁 创建日志目录..."
mkdir -p logs
echo "✅ 日志目录已创建"

# 检查端口是否被占用
echo "🔍 检查端口占用..."
PORT=$(grep "^PORT=" .env | cut -d'=' -f2 | tr -d '"')
if [ -z "$PORT" ]; then
    PORT=3000
fi

if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  警告: 端口 $PORT 已被占用"
    echo "   请修改 .env 文件中的 PORT 配置或停止占用端口的进程"
    exit 1
fi

echo "✅ 端口 $PORT 可用"

# 选择运行模式
echo ""
echo "请选择运行模式："
echo "1) 开发模式 (npm run dev)"
echo "2) 生产模式 (npm run build && npm start)"
read -p "请输入选择 (1-2): " choice

case $choice in
    1)
        echo "🚀 启动开发模式..."
        npm run dev
        ;;
    2)
        echo "🔨 构建项目..."
        npm run build
        if [ $? -ne 0 ]; then
            echo "❌ 构建失败"
            exit 1
        fi
        echo "🚀 启动生产模式..."
        npm start
        ;;
    *)
        echo "❌ 无效选择"
        exit 1
        ;;
esac
