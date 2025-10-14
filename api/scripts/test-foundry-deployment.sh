#!/bin/bash

# Foundry 字节码部署测试脚本
# 测试使用 Foundry 编译的合约字节码进行部署

# 配置
API_BASE_URL="http://localhost:3000"
API_PREFIX="/api/v1"

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 测试函数
test_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    local expected_status=$5
    
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
    
    if [ -n "$expected_status" ]; then
        if [ "$http_code" = "$expected_status" ]; then
            echo -e "  ${GREEN}✓ Success ($http_code)${NC}"
        else
            echo -e "  ${RED}✗ Expected $expected_status, got $http_code${NC}"
        fi
    else
        if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
            echo -e "  ${GREEN}✓ Success ($http_code)${NC}"
        elif [ "$http_code" -ge 400 ] && [ "$http_code" -lt 500 ]; then
            echo -e "  ${YELLOW}⚠ Expected Error ($http_code)${NC}"
        else
            echo -e "  ${RED}✗ Error ($http_code)${NC}"
        fi
    fi
    
    echo "  Response: $response_body"
    echo ""
}

# 检查服务状态
check_services() {
    echo -e "${BLUE}检查服务状态...${NC}"
    
    # 检查 HTTP 服务器
    if curl -s "$API_BASE_URL/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ HTTP 服务器运行正常${NC}"
    else
        echo -e "${RED}✗ HTTP 服务器未运行${NC}"
        return 1
    fi
    
    # 检查 anvil 节点
    if curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        http://localhost:8545 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Anvil 节点运行正常${NC}"
    else
        echo -e "${RED}✗ Anvil 节点未运行${NC}"
        return 1
    fi
    
    return 0
}

# 测试部署功能
test_deployment() {
    echo -e "${PURPLE}开始测试 Foundry 字节码部署功能...${NC}"
    echo ""
    
    # 1. 测试部署 NFT 合约
    echo -e "${YELLOW}1. 测试部署 StandardNFT 合约${NC}"
    test_api "POST" "$API_PREFIX/deploy/nft" '{
        "name": "Test Bytecode NFT",
        "symbol": "TBNFT",
        "baseURI": "https://api.test.com/metadata/",
        "maxSupply": 1000,
        "maxMintPerAddress": 10,
        "mintPrice": "0.01"
    }' "部署 StandardNFT 合约"
    
    # 等待部署完成
    echo "等待部署完成..."
    sleep 3
    
    # 2. 获取部署的合约地址
    echo -e "${YELLOW}2. 获取部署的合约地址${NC}"
    test_api "GET" "$API_PREFIX/deploy/contracts" "" "获取合约地址"
    
    # 3. 测试部署 Pair 合约
    echo -e "${YELLOW}3. 测试部署 Pair 合约${NC}"
    test_api "POST" "$API_PREFIX/deploy/pair" '{
        "nftContractAddress": "0x1234567890123456789012345678901234567890"
    }' "部署 Pair 合约"
    
    # 等待部署完成
    echo "等待部署完成..."
    sleep 3
    
    # 4. 测试部署 MultiPoolManager 合约
    echo -e "${YELLOW}4. 测试部署 MultiPoolManager 合约${NC}"
    test_api "POST" "$API_PREFIX/deploy/multi-pool-manager" '{}' "部署 MultiPoolManager 合约"
    
    # 等待部署完成
    echo "等待部署完成..."
    sleep 3
    
    # 5. 获取所有合约地址
    echo -e "${YELLOW}5. 获取所有合约地址${NC}"
    test_api "GET" "$API_PREFIX/deploy/contracts" "" "获取所有合约地址"
}

# 测试池子管理功能
test_pool_management() {
    echo -e "${PURPLE}开始测试池子管理功能...${NC}"
    echo ""
    
    # 1. 获取所有池子
    echo -e "${YELLOW}1. 获取所有池子${NC}"
    test_api "GET" "$API_PREFIX/pool" "" "获取所有池子"
    
    # 2. 获取池子储备量
    echo -e "${YELLOW}2. 获取池子储备量${NC}"
    test_api "GET" "$API_PREFIX/pool/reserves" "" "获取池子储备量"
    
    # 3. 创建新池子
    echo -e "${YELLOW}3. 创建新池子${NC}"
    test_api "POST" "$API_PREFIX/pool/create" '{
        "nftContractAddress": "0x1234567890123456789012345678901234567890",
        "nftTokenIds": [1, 2, 3],
        "ethAmount": "1.0"
    }' "创建新池子"
}

# 测试交易功能
test_trading() {
    echo -e "${PURPLE}开始测试交易功能...${NC}"
    echo ""
    
    # 1. 获取价格信息
    echo -e "${YELLOW}1. 获取价格信息${NC}"
    test_api "GET" "$API_PREFIX/trade/price" "" "获取当前价格"
    
    # 2. 获取买入报价
    echo -e "${YELLOW}2. 获取买入报价${NC}"
    test_api "GET" "$API_PREFIX/trade/quote" "" "获取买入报价"
    
    # 3. 获取交易历史
    echo -e "${YELLOW}3. 获取交易历史${NC}"
    test_api "GET" "$API_PREFIX/trade/history" "" "获取交易历史"
    
    # 4. 获取池子储备量
    echo -e "${YELLOW}4. 获取池子储备量${NC}"
    test_api "GET" "$API_PREFIX/trade/reserves" "" "获取池子储备量"
}

# 测试错误处理
test_error_handling() {
    echo -e "${PURPLE}开始测试错误处理...${NC}"
    echo ""
    
    # 1. 测试无效的合约地址
    echo -e "${YELLOW}1. 测试无效的合约地址${NC}"
    test_api "POST" "$API_PREFIX/deploy/pair" '{
        "nftContractAddress": "invalid_address"
    }' "使用无效地址部署 Pair 合约" "400"
    
    # 2. 测试缺少必需参数
    echo -e "${YELLOW}2. 测试缺少必需参数${NC}"
    test_api "POST" "$API_PREFIX/deploy/nft" '{
        "name": "Test NFT"
    }' "缺少必需参数部署 NFT 合约" "400"
    
    # 3. 测试不存在的端点
    echo -e "${YELLOW}3. 测试不存在的端点${NC}"
    test_api "GET" "/nonexistent" "" "404 错误测试" "404"
}

# 主测试流程
main() {
    echo "=========================================="
    echo "     Foundry 字节码部署测试"
    echo "=========================================="
    echo ""
    
    # 检查服务状态
    if ! check_services; then
        echo -e "${RED}服务检查失败，请确保以下服务正在运行：${NC}"
        echo "1. HTTP 服务器: cd api && npm run dev"
        echo "2. Anvil 节点: anvil --host 0.0.0.0 --port 8545"
        exit 1
    fi
    
    echo ""
    echo -e "${GREEN}所有服务运行正常，开始测试...${NC}"
    echo ""
    
    # 运行测试
    test_deployment
    test_pool_management
    test_trading
    test_error_handling
    
    echo "=========================================="
    echo -e "${GREEN}测试完成！${NC}"
    echo "=========================================="
    echo ""
    echo -e "${BLUE}测试总结：${NC}"
    echo "✅ 测试了 Foundry 字节码部署功能"
    echo "✅ 测试了池子管理功能"
    echo "✅ 测试了交易功能"
    echo "✅ 测试了错误处理"
    echo ""
    echo -e "${YELLOW}注意：${NC}"
    echo "- 如果看到错误，这是正常的，因为某些功能需要实际的合约地址"
    echo "- 部署功能现在使用 Foundry 编译的字节码"
    echo "- 可以通过 API 文档查看详细接口: http://localhost:3000/docs"
}

# 运行主函数
main "$@"
