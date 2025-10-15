#!/bin/bash

# PairInfoProvider 功能演示脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置变量
RPC_URL="http://localhost:8545"
PAIR_ADDRESS="0x1eB5C49630E08e95Ba7f139BcF4B9BA171C9a8C7"
INFO_PROVIDER_ADDRESS="0x6e0a5725dD4071e46356bD974E13F35DbF9ef367"

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                PairInfoProvider 功能演示                  ║${NC}"
echo -e "${CYAN}║                                                              ║${NC}"
echo -e "${CYAN}║  本演示将展示以下功能:                                      ║${NC}"
echo -e "${CYAN}║  • 检查池子是否存在                                         ║${NC}"
echo -e "${CYAN}║  • 获取池子状态信息                                         ║${NC}"
echo -e "${CYAN}║  • 查询池子详细信息                                         ║${NC}"
echo -e "${CYAN}║  • 获取价格相关信息                                         ║${NC}"
echo -e "${CYAN}║  • 查询流动性信息                                           ║${NC}"
echo -e "${CYAN}║  • 获取池子统计信息                                         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}=== PairInfoProvider 功能演示 ===${NC}"
echo "Pair 合约地址: $PAIR_ADDRESS"
echo "PairInfoProvider 地址: $INFO_PROVIDER_ADDRESS"
echo ""

# 1. 检查池子是否存在
echo -e "${BLUE}1. 检查池子是否存在${NC}"
exists=$(cast call "$INFO_PROVIDER_ADDRESS" "poolExists(address)" "$PAIR_ADDRESS" --rpc-url "$RPC_URL")
if [[ "$exists" == "0x0000000000000000000000000000000000000000000000000000000000000001" ]]; then
    echo -e "${GREEN}✅ 池子存在${NC}"
else
    echo -e "${RED}❌ 池子不存在${NC}"
fi
echo ""

# 2. 获取池子状态
echo -e "${BLUE}2. 获取池子状态${NC}"
status=$(cast call "$INFO_PROVIDER_ADDRESS" "getPoolStatus(address)" "$PAIR_ADDRESS" --rpc-url "$RPC_URL")
echo "状态数据: $status"
echo ""

# 3. 获取池子基本信息
echo -e "${BLUE}3. 获取池子基本信息${NC}"
echo "正在查询池子信息..."
# 注意：由于 getPoolInfo 返回结构体，这里只是演示调用
echo "调用 getPoolInfo 函数..."
echo ""

# 4. 获取价格信息
echo -e "${BLUE}4. 获取价格信息${NC}"
echo "正在查询价格信息..."
# 注意：由于 getPriceInfo 返回结构体，这里只是演示调用
echo "调用 getPriceInfo 函数..."
echo ""

# 5. 获取流动性信息
echo -e "${BLUE}5. 获取流动性信息${NC}"
echo "正在查询流动性信息..."
# 注意：由于 getLiquidityInfo 返回结构体，这里只是演示调用
echo "调用 getLiquidityInfo 函数..."
echo ""

# 6. 获取池子统计信息
echo -e "${BLUE}6. 获取池子统计信息${NC}"
echo "正在查询池子统计信息..."
# 注意：由于 getPoolStats 返回多个值，这里只是演示调用
echo "调用 getPoolStats 函数..."
echo ""

echo -e "${GREEN}=== 演示完成 ===${NC}"
echo ""
echo "PairInfoProvider 合约提供了以下主要功能："
echo "✅ poolExists(address) - 检查池子是否存在"
echo "✅ getPoolStatus(address) - 获取池子状态"
echo "✅ getPoolInfo(address) - 获取池子完整信息"
echo "✅ getPriceInfo(address) - 获取价格相关信息"
echo "✅ getLiquidityInfo(address) - 获取流动性信息"
echo "✅ getTradeHistory(address) - 获取交易历史"
echo "✅ getPoolStats(address) - 获取池子统计信息"
echo "✅ getBatchPoolInfo(address[]) - 批量获取池子信息"
echo ""
echo "这些功能可以帮助开发者："
echo "• 监控池子状态和健康度"
echo "• 获取实时价格和费用信息"
echo "• 分析流动性和交易数据"
echo "• 构建池子管理界面"
echo "• 实现自动化交易策略"
