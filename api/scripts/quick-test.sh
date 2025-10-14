#!/bin/bash

# NFT DEX API 快速测试脚本
# 简化版本，用于快速验证 API 功能

# 配置
API_BASE_URL="http://localhost:3000"
API_PREFIX="/api/v1"

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 测试函数
test_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    
    echo -e "${BLUE}Testing: $description${NC}"
    echo "  $method $endpoint"
    
    if [ -n "$data" ]; then
        response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X "$method" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$API_BASE_URL$endpoint")
    else
        response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X "$method" \
            "$API_BASE_URL$endpoint")
    fi
    
    http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    response_body=$(echo "$response" | grep -v "HTTP_CODE:")
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo -e "  ${GREEN}✓ Success ($http_code)${NC}"
    elif [ "$http_code" -ge 400 ] && [ "$http_code" -lt 500 ]; then
        echo -e "  ${YELLOW}⚠ Expected Error ($http_code)${NC}"
    else
        echo -e "  ${RED}✗ Error ($http_code)${NC}"
    fi
    
    echo "  Response: $response_body"
    echo ""
}

# 检查服务器
check_server() {
    echo -e "${BLUE}Checking server status...${NC}"
    if curl -s "$API_BASE_URL/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Server is running${NC}"
        return 0
    else
        echo -e "${RED}✗ Server is not running${NC}"
        echo "Please start the server: cd api && npm start"
        return 1
    fi
}

# 主测试流程
main() {
    echo "=========================================="
    echo "     NFT DEX API 快速测试"
    echo "=========================================="
    
    if ! check_server; then
        exit 1
    fi
    
    echo ""
    echo "Running API tests..."
    echo ""
    
    # 系统接口
    test_api "GET" "/health" "" "健康检查"
    test_api "GET" "/" "" "根路径"
    test_api "GET" "/docs" "" "API 文档"
    
    # 部署接口
    test_api "GET" "$API_PREFIX/deploy/contracts" "" "获取合约地址"
    test_api "PUT" "$API_PREFIX/deploy/contracts" '{
        "nftContract": "0x1234567890123456789012345678901234567890",
        "pairContract": "0x2345678901234567890123456789012345678901"
    }' "更新合约地址"
    
    # 池子管理接口
    test_api "GET" "$API_PREFIX/pool" "" "获取所有池子"
    test_api "GET" "$API_PREFIX/pool/reserves" "" "获取池子储备量"
    
    # 交易接口
    test_api "GET" "$API_PREFIX/trade/price" "" "获取价格信息"
    test_api "GET" "$API_PREFIX/trade/quote" "" "获取买入报价"
    test_api "GET" "$API_PREFIX/trade/history" "" "获取交易历史"
    test_api "GET" "$API_PREFIX/trade/reserves" "" "获取池子储备量"
    
    # 错误测试
    test_api "GET" "/nonexistent" "" "404 错误测试"
    
    echo "=========================================="
    echo -e "${GREEN}测试完成！${NC}"
    echo "=========================================="
}

# 运行主函数
main "$@"
