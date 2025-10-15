#!/bin/bash

# Sepolia 测试网部署脚本

echo "=== NFT DEX 部署脚本 ==="

export PRIVATE_KEY=ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# 检查环境变量
if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ 错误: 请设置 PRIVATE_KEY 环境变量"
    echo "   例如: export PRIVATE_KEY=ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    exit 1
fi

# 检查 RPC 端点
# if [ -z "$INFURA_API_KEY" ] && [ -z "$ALCHEMY_API_KEY" ]; then
#     echo "❌ 错误: 请设置 INFURA_API_KEY 或 ALCHEMY_API_KEY 环境变量"
#     exit 1
# fi

# 选择 RPC 端点
if [ -n "$INFURA_API_KEY" ]; then
    RPC_URL="sepolia"
    echo "📡 使用 Infura RPC 端点"
else
    RPC_URL="http://localhost:8545"
    echo "📡 使用 local RPC 端点"
fi

# 编译合约
echo "🔨 编译合约..."
forge build

if [ $? -ne 0 ]; then
    echo "❌ 编译失败"
    exit 1
fi

echo "✅ 编译成功"

# 询问部署类型
echo ""
echo "请选择部署类型："
echo "1) AMM 系统 (单个池子)"
echo "2) 多池系统 (多个池子)"
echo "3) 仅 NFT 合约"
read -p "请输入选择 (1-3): " choice

case $choice in
    1)
        echo "🚀 部署 AMM 系统..."
        forge script script/DeployAMMSystem.s.sol:DeployAMMSystem --rpc-url $RPC_URL --broadcast --verify
        ;;
    2)
        echo "🚀 部署多池系统..."
        forge script script/DeployPairFactory.s.sol:DeployPairFactory --rpc-url $RPC_URL --broadcast --verify
        ;;
    3)
        echo "🚀 部署 NFT 合约..."
        forge script script/DeployStandardNFT.s.sol:DeployStandardNFT --rpc-url $RPC_URL --broadcast --verify
        ;;
    *)
        echo "❌ 无效选择"
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 部署成功！"
    echo "📋 请查看上面的输出获取合约地址"
    echo "🔍 您可以在 Etherscan 上查看部署的合约"
else
    echo "❌ 部署失败"
    exit 1
fi
