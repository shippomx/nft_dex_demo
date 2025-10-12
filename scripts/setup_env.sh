#!/bin/bash

# 环境变量设置脚本
echo "=== 设置环境变量 ==="

# 设置私钥
export PRIVATE_KEY="2d641b722192c0003244f5467ef1b81b843a91693a8b657e08e34f5d879deba0"

# 设置 Infura API Key (如果需要)
export INFURA_API_KEY="ff6896ca6835453f965911119da38dff"

# 设置 Etherscan API Key (用于验证合约)
export ETHERSCAN_API_KEY=""

echo "✅ 环境变量已设置:"
echo "   PRIVATE_KEY: ${PRIVATE_KEY:0:10}..."
echo "   INFURA_API_KEY: ${INFURA_API_KEY:0:10}..."
echo "   ETHERSCAN_API_KEY: ${ETHERSCAN_API_KEY:-未设置}"

echo ""
echo "现在可以运行部署脚本:"
echo "   source scripts/setup_env.sh && forge script script/DeployAMMSystem.s.sol:DeployAMMSystem --rpc-url sepolia --broadcast --verify"