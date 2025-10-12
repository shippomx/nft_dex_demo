#!/bin/bash

# Sepolia 测试网部署脚本

echo "=== NFT DEX Sepolia 部署脚本 ==="

# 设置环境变量
export PRIVATE_KEY="2d641b722192c0003244f5467ef1b81b843a91693a8b657e08e34f5d879deba0"
export INFURA_API_KEY="ff6896ca6835453f965911119da38dff"

echo "📡 使用 Sepolia 测试网"
echo "🔑 私钥: ${PRIVATE_KEY:0:10}..."

# 检查账户余额
echo "💰 检查账户余额..."
ACCOUNT_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY)
echo "账户地址: $ACCOUNT_ADDRESS"

# 获取余额
BALANCE=$(cast balance $ACCOUNT_ADDRESS --rpc-url sepolia)
BALANCE_ETH=$(cast to-unit $BALANCE ether)
echo "账户余额: $BALANCE_ETH ETH"

if (( $(echo "$BALANCE_ETH < 0.01" | bc -l) )); then
    echo "⚠️  警告: 账户余额较低，可能无法完成部署"
    echo "   请确保账户有足够的 ETH 用于 gas 费用"
    echo "   建议至少 0.01 ETH"
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
        echo "🚀 部署 AMM 系统到 Sepolia..."
        forge script script/DeployAMMSystem.s.sol:DeployAMMSystem --rpc-url sepolia --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
        ;;
    2)
        echo "🚀 部署多池系统到 Sepolia..."
        forge script script/DeployMultiPoolSystem.s.sol:DeployMultiPoolSystem --rpc-url sepolia --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
        ;;
    3)
        echo "🚀 部署 NFT 合约到 Sepolia..."
        forge script script/DeployStandardNFT.s.sol:DeployStandardNFT --rpc-url sepolia --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
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
    echo "🔍 您可以在 Etherscan 上查看部署的合约: https://sepolia.etherscan.io/"
    echo "💰 账户余额: $(cast balance $ACCOUNT_ADDRESS --rpc-url sepolia | cast to-unit ether) ETH"
else
    echo "❌ 部署失败"
    echo "💡 常见问题排查:"
    echo "   1. 检查账户是否有足够的 ETH"
    echo "   2. 检查网络连接"
    echo "   3. 检查私钥是否正确"
    exit 1
fi
