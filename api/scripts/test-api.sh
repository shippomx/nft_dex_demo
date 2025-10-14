#!/bin/bash

# NFT DEX API 测试脚本
# 用于测试所有已知的 API 路由

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# API 基础配置
API_BASE_URL="http://localhost:3000"
API_PREFIX="/api/v1"

# 测试计数器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_test() {
    echo -e "${CYAN}[TEST]${NC} $1"
}

# 测试函数
test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local expected_status=$4
    local description=$5
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    log_test "Testing: $description"
    echo "  Method: $method"
    echo "  Endpoint: $endpoint"
    
    if [ -n "$data" ]; then
        echo "  Data: $data"
    fi
    
    # 执行请求
    if [ -n "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$API_BASE_URL$endpoint")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            "$API_BASE_URL$endpoint")
    fi
    
    # 分离响应体和状态码
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n -1)
    
    echo "  Status Code: $http_code"
    echo "  Response: $response_body"
    
    # 检查状态码
    if [ "$http_code" = "$expected_status" ]; then
        log_success "✓ Test passed"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_error "✗ Test failed - Expected: $expected_status, Got: $http_code"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    echo ""
}

# 检查服务器状态
check_server() {
    log_info "Checking server status..."
    
    if curl -s "$API_BASE_URL/health" > /dev/null 2>&1; then
        log_success "Server is running at $API_BASE_URL"
        return 0
    else
        log_error "Server is not running at $API_BASE_URL"
        log_warning "Please start the server first:"
        echo "  cd api && npm start"
        return 1
    fi
}

# 显示测试结果
show_results() {
    echo ""
    echo "=========================================="
    echo "          测试结果汇总"
    echo "=========================================="
    echo "总测试数: $TOTAL_TESTS"
    echo -e "通过: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "失败: ${RED}$FAILED_TESTS${NC}"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "\n${GREEN}🎉 所有测试都通过了！${NC}"
    else
        echo -e "\n${RED}❌ 有 $FAILED_TESTS 个测试失败${NC}"
    fi
    echo "=========================================="
}

# 主测试函数
run_tests() {
    log_info "开始测试 NFT DEX API..."
    echo ""
    
    # 1. 系统接口测试
    log_info "=== 系统接口测试 ==="
    test_endpoint "GET" "/health" "" "200" "健康检查"
    test_endpoint "GET" "/" "" "200" "根路径"
    test_endpoint "GET" "/docs" "" "200" "API 文档"
    
    # 2. 部署接口测试
    log_info "=== 部署接口测试 ==="
    test_endpoint "GET" "$API_PREFIX/deploy/contracts" "" "200" "获取已部署合约地址"
    
    # 部署 NFT 合约测试
    test_endpoint "POST" "$API_PREFIX/deploy/nft" '{
        "name": "Test NFT Collection",
        "symbol": "TESTNFT",
        "baseURI": "https://api.example.com/metadata/",
        "maxSupply": 1000,
        "maxMintPerAddress": 50,
        "mintPrice": "0.01"
    }' "500" "部署 NFT 合约 (预期失败 - 需要字节码)"
    
    # 部署 Pair 合约测试
    test_endpoint "POST" "$API_PREFIX/deploy/pair" '{
        "nftContractAddress": "0x1234567890123456789012345678901234567890"
    }' "500" "部署 Pair 合约 (预期失败 - 需要字节码)"
    
    # 部署 MultiPoolManager 合约测试
    test_endpoint "POST" "$API_PREFIX/deploy/multi-pool-manager" '{}' "500" "部署 MultiPoolManager 合约 (预期失败 - 需要字节码)"
    
    # 更新合约地址测试
    test_endpoint "PUT" "$API_PREFIX/deploy/contracts" '{
        "nftContract": "0x1234567890123456789012345678901234567890",
        "pairContract": "0x2345678901234567890123456789012345678901",
        "multiPoolManager": "0x3456789012345678901234567890123456789012"
    }' "200" "更新合约地址"
    
    # 3. 池子管理接口测试
    log_info "=== 池子管理接口测试 ==="
    test_endpoint "GET" "$API_PREFIX/pool" "" "500" "获取所有池子 (预期失败 - 需要合约地址)"
    test_endpoint "GET" "$API_PREFIX/pool/reserves" "" "500" "获取池子储备量 (预期失败 - 需要合约地址)"
    
    # 创建池子测试
    test_endpoint "POST" "$API_PREFIX/pool/create" '{
        "nftContractAddress": "0x1234567890123456789012345678901234567890",
        "nftTokenIds": [1, 2, 3],
        "ethAmount": "1.0"
    }' "500" "创建流动性池 (预期失败 - 需要合约地址)"
    
    # 添加流动性测试
    test_endpoint "POST" "$API_PREFIX/pool/add-liquidity" '{
        "nftTokenIds": [1, 2, 3],
        "ethAmount": "0.5"
    }' "500" "添加流动性 (预期失败 - 需要合约地址)"
    
    # 删除流动性测试
    test_endpoint "POST" "$API_PREFIX/pool/remove-liquidity" '{
        "lpTokenAmount": "100",
        "nftTokenIds": [1, 2]
    }' "500" "删除流动性 (预期失败 - 需要合约地址)"
    
    # 获取指定池子信息测试
    test_endpoint "GET" "$API_PREFIX/pool/0x1234567890123456789012345678901234567890" "" "500" "获取指定池子信息 (预期失败 - 需要合约地址)"
    
    # 4. 交易接口测试
    log_info "=== 交易接口测试 ==="
    
    # 价格查询测试
    test_endpoint "GET" "$API_PREFIX/trade/price" "" "500" "获取价格信息 (预期失败 - 需要合约地址)"
    test_endpoint "GET" "$API_PREFIX/trade/price?type=current" "" "500" "获取当前价格 (预期失败 - 需要合约地址)"
    test_endpoint "GET" "$API_PREFIX/trade/price?type=sell" "" "500" "获取卖出价格 (预期失败 - 需要合约地址)"
    test_endpoint "GET" "$API_PREFIX/trade/price?type=buy" "" "500" "获取买入价格 (预期失败 - 需要合约地址)"
    
    # 买入报价测试
    test_endpoint "GET" "$API_PREFIX/trade/quote" "" "500" "获取买入报价 (预期失败 - 需要合约地址)"
    
    # 交易历史测试
    test_endpoint "GET" "$API_PREFIX/trade/history" "" "500" "获取交易历史 (预期失败 - 需要合约地址)"
    test_endpoint "GET" "$API_PREFIX/trade/history?limit=10&offset=0" "" "500" "获取分页交易历史 (预期失败 - 需要合约地址)"
    test_endpoint "GET" "$API_PREFIX/trade/recent?count=5" "" "500" "获取最近交易 (预期失败 - 需要合约地址)"
    
    # 池子储备量测试
    test_endpoint "GET" "$API_PREFIX/trade/reserves" "" "500" "获取池子储备量 (预期失败 - 需要合约地址)"
    
    # 买入 NFT 测试
    test_endpoint "POST" "$API_PREFIX/trade/buy" '{
        "maxPrice": "0.1"
    }' "500" "买入 NFT (预期失败 - 需要合约地址)"
    
    # 卖出 NFT 测试
    test_endpoint "POST" "$API_PREFIX/trade/sell" '{
        "tokenId": 1,
        "minPrice": "0.05"
    }' "500" "卖出 NFT (预期失败 - 需要合约地址)"
    
    # 5. 错误处理测试
    log_info "=== 错误处理测试 ==="
    test_endpoint "GET" "/nonexistent" "" "404" "不存在的路径"
    test_endpoint "POST" "$API_PREFIX/deploy/nft" '{"invalid": "data"}' "400" "无效的请求数据"
    test_endpoint "GET" "$API_PREFIX/pool/invalid-address" "" "400" "无效的合约地址格式"
}

# 交互式测试模式
interactive_mode() {
    echo ""
    log_info "进入交互式测试模式"
    echo "可用的测试命令："
    echo "  1. health - 健康检查"
    echo "  2. docs - API 文档"
    echo "  3. contracts - 获取合约地址"
    echo "  4. price - 获取价格"
    echo "  5. reserves - 获取储备量"
    echo "  6. history - 获取交易历史"
    echo "  7. custom - 自定义请求"
    echo "  q - 退出"
    echo ""
    
    while true; do
        read -p "请输入测试命令: " cmd
        
        case $cmd in
            "1"|"health")
                test_endpoint "GET" "/health" "" "200" "健康检查"
                ;;
            "2"|"docs")
                test_endpoint "GET" "/docs" "" "200" "API 文档"
                ;;
            "3"|"contracts")
                test_endpoint "GET" "$API_PREFIX/deploy/contracts" "" "200" "获取合约地址"
                ;;
            "4"|"price")
                test_endpoint "GET" "$API_PREFIX/trade/price" "" "500" "获取价格"
                ;;
            "5"|"reserves")
                test_endpoint "GET" "$API_PREFIX/trade/reserves" "" "500" "获取储备量"
                ;;
            "6"|"history")
                test_endpoint "GET" "$API_PREFIX/trade/history" "" "500" "获取交易历史"
                ;;
            "7"|"custom")
                read -p "请输入端点路径: " endpoint
                read -p "请输入请求方法 (GET/POST/PUT/DELETE): " method
                test_endpoint "$method" "$endpoint" "" "200" "自定义请求"
                ;;
            "q"|"quit"|"exit")
                log_info "退出交互式模式"
                break
                ;;
            *)
                log_warning "未知命令: $cmd"
                ;;
        esac
    done
}

# 显示帮助信息
show_help() {
    echo "NFT DEX API 测试脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -i, --interactive  交互式测试模式"
    echo "  -u, --url URL  指定 API 基础 URL (默认: http://localhost:3000)"
    echo "  -v, --verbose  详细输出模式"
    echo ""
    echo "示例:"
    echo "  $0                    # 运行所有测试"
    echo "  $0 -i                 # 交互式模式"
    echo "  $0 -u http://localhost:8080  # 指定不同的服务器地址"
}

# 主函数
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -i|--interactive)
                INTERACTIVE_MODE=true
                shift
                ;;
            -u|--url)
                API_BASE_URL="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 显示标题
    echo "=========================================="
    echo "        NFT DEX API 测试脚本"
    echo "=========================================="
    echo "API 基础 URL: $API_BASE_URL"
    echo "API 前缀: $API_PREFIX"
    echo "=========================================="
    echo ""
    
    # 检查服务器状态
    if ! check_server; then
        exit 1
    fi
    
    # 运行测试
    if [ "$INTERACTIVE_MODE" = true ]; then
        interactive_mode
    else
        run_tests
        show_results
    fi
}

# 运行主函数
main "$@"
