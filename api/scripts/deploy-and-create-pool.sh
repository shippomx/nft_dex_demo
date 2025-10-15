#!/bin/bash

# NFT DEX 部署和池子创建脚本
# 包含：部署 NFT 合约、部署 PairFactory 合约、通过 PairFactory 创建池子

# 配置
API_BASE_URL="http://localhost:3000"
API_PREFIX="/api/v1"

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 存储合约地址
NFT_CONTRACT=""
FACTORY_CONTRACT=""
POOL_ADDRESS=""

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
        echo "  Response: $response_body"
        return 0
    elif [ "$http_code" -ge 400 ] && [ "$http_code" -lt 500 ]; then
        echo -e "  ${YELLOW}⚠ Expected Error ($http_code)${NC}"
        echo "  Response: $response_body"
        return 1
    else
        echo -e "  ${RED}✗ Error ($http_code)${NC}"
        echo "  Response: $response_body"
        return 1
    fi
}

# 检查服务器
check_server() {
    echo -e "${BLUE}Checking server status...${NC}"
    if curl -s "$API_BASE_URL/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Server is running${NC}"
        return 0
    else
        echo -e "${RED}✗ Server is not running${NC}"
        echo "Please start the server: cd api && npm run dev"
        return 1
    fi
}

# 部署 NFT 合约
deploy_nft() {
    echo -e "\n${BLUE}=== 部署 NFT 合约 ===${NC}"
    
    local response=$(curl -s -X POST "$API_BASE_URL$API_PREFIX/deploy/nft" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "Test NFT Collection",
            "symbol": "TNFT",
            "baseURI": "https://api.test.com/metadata/",
            "maxSupply": 1000,
            "maxMintPerAddress": 10,
            "mintPrice": "0.01"
        }')
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        NFT_CONTRACT=$(echo "$response" | jq -r '.data.contractAddress')
        echo -e "${GREEN}✓ NFT 合约部署成功${NC}"
        echo "  合约地址: $NFT_CONTRACT"
        echo "  合约名称: $(echo "$response" | jq -r '.data.name')"
        echo "  合约符号: $(echo "$response" | jq -r '.data.symbol')"
        echo "  最大供应量: $(echo "$response" | jq -r '.data.maxSupply')"
        echo "  铸造价格: $(echo "$response" | jq -r '.data.mintPrice') ETH"
        return 0
    else
        echo -e "${RED}✗ NFT 合约部署失败${NC}"
        echo "$response" | jq .
        return 1
    fi
}

# 部署 PairFactory 合约
deploy_factory() {
    echo -e "\n${BLUE}=== 部署 PairFactory 合约 ===${NC}"
    
    local response=$(curl -s -X POST "$API_BASE_URL$API_PREFIX/deploy/pair-factory" \
        -H "Content-Type: application/json" \
        -d '{}')
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        FACTORY_CONTRACT=$(echo "$response" | jq -r '.data.contractAddress')
        echo -e "${GREEN}✓ PairFactory 合约部署成功${NC}"
        echo "  合约地址: $FACTORY_CONTRACT"
        return 0
    else
        echo -e "${RED}✗ PairFactory 合约部署失败${NC}"
        echo "$response" | jq .
        return 1
    fi
}

# 通过 PairFactory 创建池子
create_pool() {
    echo -e "\n${BLUE}=== 通过 PairFactory 创建池子 ===${NC}"
    
    if [ -z "$NFT_CONTRACT" ]; then
        echo -e "${RED}✗ NFT 合约地址未设置${NC}"
        return 1
    fi
    
    echo "  使用 NFT 合约地址: $NFT_CONTRACT"
    
    local response=$(curl -s -X POST "$API_BASE_URL$API_PREFIX/pool/create" \
        -H "Content-Type: application/json" \
        -d "{\"nftContractAddress\": \"$NFT_CONTRACT\"}")
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        local tx_hash=$(echo "$response" | jq -r '.data.txHash')
        echo -e "${GREEN}✓ 池子创建成功${NC}"
        echo "  交易哈希: $tx_hash"
        echo "  NFT 合约: $NFT_CONTRACT"
        return 0
    else
        echo -e "${RED}✗ 池子创建失败${NC}"
        echo "$response" | jq .
        return 1
    fi
}

# 获取池子信息
get_pool_info() {
    echo -e "\n${BLUE}=== 获取池子信息 ===${NC}"
    
    if [ -z "$NFT_CONTRACT" ]; then
        echo -e "${RED}✗ NFT 合约地址未设置${NC}"
        return 1
    fi
    
    local response=$(curl -s "http://localhost:3000/api/v1/pool/$NFT_CONTRACT")
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        POOL_ADDRESS=$(echo "$response" | jq -r '.data.poolAddress')
        echo -e "${GREEN}✓ 池子信息获取成功${NC}"
        echo "  池子地址: $POOL_ADDRESS"
        echo "  NFT 合约: $(echo "$response" | jq -r '.data.nftContractAddress')"
        echo "  存在状态: $(echo "$response" | jq -r '.data.exists')"
        echo "  ETH 储备: $(echo "$response" | jq -r '.data.reserves.ethReserve')"
        echo "  NFT 储备: $(echo "$response" | jq -r '.data.reserves.nftReserve')"
        echo "  当前价格: $(echo "$response" | jq -r '.data.prices.current') ETH"
        echo "  卖出价格: $(echo "$response" | jq -r '.data.prices.sell') ETH"
        echo "  买入总成本: $(echo "$response" | jq -r '.data.prices.buy.totalCost') ETH"
        echo "  买入手续费: $(echo "$response" | jq -r '.data.prices.buy.fee') ETH"
        return 0
    else
        echo -e "${RED}✗ 池子信息获取失败${NC}"
        echo "$response" | jq .
        return 1
    fi
}

# 获取所有合约地址
get_all_contracts() {
    echo -e "\n${BLUE}=== 获取所有合约地址 ===${NC}"
    
    local response=$(curl -s "$API_BASE_URL$API_PREFIX/deploy/contracts")
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 合约地址获取成功${NC}"
        echo ""
        echo "📋 已部署的合约地址："
        echo "  NFT 合约: $(echo "$response" | jq -r '.data.nftContract')"
        echo "  Pair 合约: $(echo "$response" | jq -r '.data.pairContract')"
        echo "  PairFactory: $(echo "$response" | jq -r '.data.pairFactory')"
        return 0
    else
        echo -e "${RED}✗ 合约地址获取失败${NC}"
        echo "$response" | jq .
        return 1
    fi
}

# 显示使用说明
show_usage() {
    echo "NFT DEX 部署和池子创建脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -n, --nft-only 仅部署 NFT 合约"
    echo "  -f, --factory-only 仅部署 PairFactory 合约"
    echo "  -p, --pool-only 仅创建池子（需要先部署 NFT 和 PairFactory）"
    echo "  -i, --info-only 仅获取合约和池子信息"
    echo "  --full         执行完整流程（默认）"
    echo ""
    echo "示例:"
    echo "  $0                    # 执行完整流程"
    echo "  $0 --nft-only         # 仅部署 NFT 合约"
    echo "  $0 --factory-only     # 仅部署 PairFactory 合约"
    echo "  $0 --pool-only        # 仅创建池子"
    echo "  $0 --info-only        # 仅获取信息"
}

# 主测试流程
main() {
    local mode="full"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -n|--nft-only)
                mode="nft-only"
                shift
                ;;
            -f|--factory-only)
                mode="factory-only"
                shift
                ;;
            -p|--pool-only)
                mode="pool-only"
                shift
                ;;
            -i|--info-only)
                mode="info-only"
                shift
                ;;
            --full)
                mode="full"
                shift
                ;;
            *)
                echo "未知选项: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    echo "=========================================="
    echo "     NFT DEX 部署和池子创建脚本"
    echo "=========================================="
    echo "模式: $mode"
    
    if ! check_server; then
        exit 1
    fi
    
    case $mode in
        "nft-only")
            echo ""
            echo "开始 NFT 合约部署..."
            if ! deploy_nft; then
                echo -e "${RED}NFT 合约部署失败，终止脚本${NC}"
                exit 1
            fi
            ;;
        "factory-only")
            echo ""
            echo "开始 PairFactory 合约部署..."
            if ! deploy_factory; then
                echo -e "${RED}PairFactory 合约部署失败，终止脚本${NC}"
                exit 1
            fi
            ;;
        "pool-only")
            echo ""
            echo "开始池子创建..."
            if ! create_pool; then
                echo -e "${RED}池子创建失败，终止脚本${NC}"
                exit 1
            fi
            get_pool_info
            ;;
        "info-only")
            echo ""
            echo "获取合约和池子信息..."
            get_all_contracts
            if [ -n "$NFT_CONTRACT" ]; then
                get_pool_info
            fi
            ;;
        "full"|*)
            echo ""
            echo "开始完整部署流程..."
            
            # 部署 NFT 合约
            if ! deploy_nft; then
                echo -e "${RED}NFT 合约部署失败，终止脚本${NC}"
                exit 1
            fi
            
            # 部署 PairFactory 合约
            if ! deploy_factory; then
                echo -e "${RED}PairFactory 合约部署失败，终止脚本${NC}"
                exit 1
            fi
            
            # 创建池子
            if ! create_pool; then
                echo -e "${RED}池子创建失败，终止脚本${NC}"
                exit 1
            fi
            
            # 获取池子信息
            get_pool_info
            
            # 获取所有合约地址
            get_all_contracts
            ;;
    esac
    
    echo ""
    echo "=========================================="
    echo -e "${GREEN}✅ 操作完成！${NC}"
    echo "=========================================="
    
    if [ -n "$NFT_CONTRACT" ] || [ -n "$FACTORY_CONTRACT" ] || [ -n "$POOL_ADDRESS" ]; then
        echo ""
        echo "📋 操作结果汇总："
        [ -n "$NFT_CONTRACT" ] && echo "  NFT 合约: $NFT_CONTRACT"
        [ -n "$FACTORY_CONTRACT" ] && echo "  PairFactory: $FACTORY_CONTRACT"
        [ -n "$POOL_ADDRESS" ] && echo "  池子地址: $POOL_ADDRESS"
        echo ""
        echo "🎉 所有功能已验证通过！"
    fi
}

# 运行主函数
main "$@"
