#!/bin/bash

# NFT DEX API 演示脚本 (纯 Shell 版本)
# 使用 curl 调用 API 完成所有演示功能

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置变量
API_BASE_URL="${API_BASE_URL:-http://localhost:3000}"
API_PREFIX="/api/v1"
RPC_URL="${RPC_URL:-http://localhost:8545}"
ANVIL_PID=""
API_SERVER_PID=""

# 已部署的合约地址
PAIR_FACTORY_ADDRESS=""
NFT_CONTRACT_ADDRESS=""
PAIR_CONTRACT_ADDRESS=""

# ========== 工具函数 ==========

# 显示标题
show_title() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              NFT DEX API 功能演示 (纯Shell版)              ║${NC}"
    echo -e "${CYAN}║                                                              ║${NC}"
    echo -e "${CYAN}║  本演示将展示以下功能:                                      ║${NC}"
    echo -e "${CYAN}║  • 启动本地 Anvil 节点                                     ║${NC}"
    echo -e "${CYAN}║  • 启动 API 服务器                                         ║${NC}"
    echo -e "${CYAN}║  • 通过 API 部署 NFT 合约和 AMM 系统                      ║${NC}"
    echo -e "${CYAN}║  • 通过 API 演示 NFT 交易功能                             ║${NC}"
    echo -e "${CYAN}║  • 展示价格监控和池子管理                                 ║${NC}"
    echo -e "${CYAN}║                                                              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 等待用户确认
wait_for_user() {
    echo -e "${YELLOW}按 Enter 继续...${NC}"
    read -r
}

# 检查依赖
check_dependencies() {
    local missing_deps=()
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if ! command -v anvil &> /dev/null; then
        missing_deps+=("anvil")
    fi
    
    if ! command -v node &> /dev/null; then
        missing_deps+=("node")
    fi
    
    if ! command -v npm &> /dev/null; then
        missing_deps+=("npm")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}错误: 缺少以下依赖: ${missing_deps[*]}${NC}"
        echo ""
        echo "请安装缺少的依赖:"
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                curl)
                    echo "  - curl: brew install curl (macOS) 或 apt-get install curl (Ubuntu)"
                    ;;
                jq)
                    echo "  - jq: brew install jq (macOS) 或 apt-get install jq (Ubuntu)"
                    ;;
                anvil)
                    echo "  - Foundry: https://book.getfoundry.sh/getting-started/installation"
                    ;;
                node|npm)
                    echo "  - Node.js: https://nodejs.org/"
                    ;;
            esac
        done
        exit 1
    fi
}

# API 调用函数
api_call() {
    local method=$1
    local endpoint=$2
    local data=$3
    local url="${API_BASE_URL}${API_PREFIX}${endpoint}"
    local timeout=60  # 默认超时 60 秒
    
    # 部署和交易操作使用更长的超时
    if [[ "$endpoint" == *"/deploy"* ]] || [[ "$endpoint" == *"/pool/"* ]] || [[ "$endpoint" == *"/trade/"* ]]; then
        timeout=120  # 120 秒超时
    fi
    
    if [[ "$method" == "POST" ]]; then
        if [[ -n "$data" ]]; then
            curl -s -X POST "$url" \
                --max-time "$timeout" \
                --connect-timeout 10 \
                -H "Content-Type: application/json" \
                -d "$data"
        else
            # 如果没有数据，发送空的 JSON 对象
            curl -s -X POST "$url" \
                --max-time "$timeout" \
                --connect-timeout 10 \
                -H "Content-Type: application/json" \
                -d '{}'
        fi
    else
        curl -s -X GET "$url" \
            --max-time "$timeout" \
            --connect-timeout 10
    fi
}

# 启动 Anvil 节点
start_anvil() {
    echo -e "${GREEN}=== 步骤 1: 启动 Anvil 本地节点 ===${NC}"
    echo "启动 Anvil 节点在 $RPC_URL..."
    
    # 检查端口是否已被占用
    if lsof -i :8545 &> /dev/null; then
        echo -e "${YELLOW}端口 8545 已被占用，可能 Anvil 已在运行${NC}"
        echo "跳过启动步骤..."
    else
        anvil --host 0.0.0.0 --port 8545 > anvil.log 2>&1 &
        ANVIL_PID=$!
        
        echo "等待 Anvil 启动..."
        sleep 3
        
        # 检查 Anvil 是否启动成功
        if curl -s -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            "$RPC_URL" > /dev/null; then
            echo -e "${GREEN}✅ Anvil 节点启动成功!${NC}"
        else
            echo -e "${RED}❌ Anvil 节点启动失败${NC}"
            exit 1
        fi
    fi
    
    wait_for_user
}

# 启动 API 服务器
start_api_server() {
    echo -e "${GREEN}=== 步骤 2: 启动 API 服务器 ===${NC}"
    echo "启动 API 服务器在 $API_BASE_URL..."
    
    # 检查端口是否已被占用
    if lsof -i :3000 &> /dev/null; then
        echo -e "${YELLOW}端口 3000 已被占用，可能 API 服务器已在运行${NC}"
        echo "跳过启动步骤..."
    else
        # 获取项目根目录
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
        PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
        API_DIR="$PROJECT_ROOT/api"
        
        if [[ ! -d "$API_DIR" ]]; then
            echo -e "${RED}错误: API 目录不存在: $API_DIR${NC}"
            exit 1
        fi
        
        cd "$API_DIR" || exit 1
        npm run dev > ../api-server.log 2>&1 &
        API_SERVER_PID=$!
        cd "$PROJECT_ROOT" || exit 1
        
        echo "等待 API 服务器启动..."
        
        # 等待 API 服务器就绪
        local max_attempts=30
        local attempt=0
        while [[ $attempt -lt $max_attempts ]]; do
            if curl -s "$API_BASE_URL/health" > /dev/null 2>&1; then
                echo -e "${GREEN}✅ API 服务器启动成功!${NC}"
                break
            fi
            sleep 1
            ((attempt++))
            echo -n "."
        done
        
        if [[ $attempt -eq $max_attempts ]]; then
            echo -e "${RED}❌ API 服务器启动超时${NC}"
            exit 1
        fi
        echo ""
    fi
    
    wait_for_user
}

# 部署 PairFactory
deploy_pair_factory() {
    echo ""
    echo -e "${BLUE}部署 PairFactory 合约...${NC}"
    echo "（此操作可能需要 30-60 秒，请耐心等待...）"
    
    local response=$(api_call "POST" "/deploy/pair-factory" "")
    local exit_code=$?
    
    # 检查 curl 是否超时或失败
    if [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}❌ API 请求失败 (curl 错误码: $exit_code)${NC}"
        echo "可能原因: 网络超时、API 服务器未响应或交易失败"
        return 1
    fi
    
    # 检查响应是否为空
    if [[ -z "$response" ]]; then
        echo -e "${RED}❌ API 返回空响应${NC}"
        echo "可能原因: API 服务器未启动或网络连接问题"
        return 1
    fi
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        PAIR_FACTORY_ADDRESS=$(echo "$response" | jq -r '.data.contractAddress')
        local tx_hash=$(echo "$response" | jq -r '.data.txHash')
        echo -e "${GREEN}✅ PairFactory 部署成功${NC}"
        echo "   地址: $PAIR_FACTORY_ADDRESS"
        echo "   交易哈希: $tx_hash"
    else
        echo -e "${RED}❌ PairFactory 部署失败${NC}"
        echo "$response" | jq '.'
        return 1
    fi
}

# 部署 NFT 合约
deploy_nft() {
    echo ""
    echo -e "${BLUE}部署 NFT 合约...${NC}"
    
    local data='{
        "name": "Demo NFT Collection",
        "symbol": "DEMO",
        "baseURI": "https://api.example.com/metadata/",
        "maxSupply": 10000,
        "maxMintPerAddress": 10,
        "mintPrice": "0.01"
    }'
    
    local response=$(api_call "POST" "/deploy/nft" "$data")
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        NFT_CONTRACT_ADDRESS=$(echo "$response" | jq -r '.data.contractAddress')
        local tx_hash=$(echo "$response" | jq -r '.data.txHash')
        # 从消息中提取铸造数量，或从 data 中获取（如果存在）
        local minted=$(echo "$response" | jq -r '.data.mintedNFTs // empty')
        if [[ -z "$minted" || "$minted" == "null" ]]; then
            # 从消息中提取数字（例如: "with 10 NFTs minted"）
            minted=$(echo "$response" | jq -r '.message' | grep -oE '[0-9]+' | head -1)
            [[ -z "$minted" ]] && minted="10"  # 默认值
        fi
        echo -e "${GREEN}✅ NFT 合约部署成功${NC}"
        echo "   地址: $NFT_CONTRACT_ADDRESS"
        echo "   交易哈希: $tx_hash"
        echo "   已铸造 NFT: $minted 个"
    else
        echo -e "${RED}❌ NFT 合约部署失败${NC}"
        echo "$response" | jq '.'
        return 1
    fi
}

# 创建流动性池
create_pool() {
    echo ""
    echo -e "${BLUE}创建流动性池...${NC}"
    
    # 先检查池子是否已存在
    local check_pool=$(api_call "GET" "/pool/$NFT_CONTRACT_ADDRESS" "")
    local pool_exists=$(echo "$check_pool" | jq -r '.data.exists')
    
    if [[ "$pool_exists" == "true" ]]; then
        PAIR_CONTRACT_ADDRESS=$(echo "$check_pool" | jq -r '.data.poolAddress')
        echo -e "${YELLOW}⚠️ 池子已存在，跳过创建${NC}"
        echo "   池子地址: $PAIR_CONTRACT_ADDRESS"
        return 0
    fi
    
    local data=$(jq -n --arg nft "$NFT_CONTRACT_ADDRESS" '{nftContractAddress: $nft}')
    
    local response=$(api_call "POST" "/pool/create" "$data")
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        PAIR_CONTRACT_ADDRESS=$(echo "$response" | jq -r '.data.poolAddress')
        local tx_hash=$(echo "$response" | jq -r '.data.txHash')
        
        # 如果 API 返回的地址无效，通过合约查询获取
        if [[ "$PAIR_CONTRACT_ADDRESS" == "null" || -z "$PAIR_CONTRACT_ADDRESS" || "$PAIR_CONTRACT_ADDRESS" == "0x0000000000000000000000000000000000000000" ]]; then
            echo -e "${YELLOW}⚠️ API 未返回池子地址，尝试从合约查询...${NC}"
            
            if [[ -n "$PAIR_FACTORY_ADDRESS" && "$PAIR_FACTORY_ADDRESS" != "null" ]]; then
                # 使用 cast call 直接查询合约
                PAIR_CONTRACT_ADDRESS=$(cast call "$PAIR_FACTORY_ADDRESS" "getPool(address)(address)" "$NFT_CONTRACT_ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null)
                
                if [[ -n "$PAIR_CONTRACT_ADDRESS" && "$PAIR_CONTRACT_ADDRESS" != "0x0000000000000000000000000000000000000000" ]]; then
                    echo -e "${GREEN}✅ 从合约获取池子地址成功${NC}"
                    echo "   池子地址: $PAIR_CONTRACT_ADDRESS"
                else
                    echo -e "${RED}❌ 无法获取池子地址${NC}"
                    return 1
                fi
            else
                echo -e "${RED}❌ PairFactory 地址未设置，无法查询${NC}"
                return 1
            fi
        else
            echo -e "${GREEN}✅ 流动性池创建成功${NC}"
            echo "   池子地址: $PAIR_CONTRACT_ADDRESS"
        fi
        
        echo "   交易哈希: $tx_hash"
    else
        echo -e "${RED}❌ 流动性池创建失败${NC}"
        echo "$response" | jq '.'
        return 1
    fi
}

# 批量授权 NFT
batch_approve_nft() {
    echo ""
    echo -e "${BLUE}批量授权 NFT...${NC}"
    
    local data=$(jq -n \
        --arg nft "$NFT_CONTRACT_ADDRESS" \
        --arg pool "$PAIR_CONTRACT_ADDRESS" \
        --argjson ids '[1,2,3,4,5]' \
        '{nftContractAddress: $nft, poolAddress: $pool, tokenIds: $ids}')
    
    local response=$(api_call "POST" "/pool/batch-approve-nft" "$data")
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        echo -e "${GREEN}✅ NFT 授权成功 (5 个)${NC}"
    else
        echo -e "${RED}❌ NFT 授权失败${NC}"
        echo "$response" | jq '.'
        return 1
    fi
}

# 添加流动性
add_liquidity() {
    echo ""
    echo -e "${BLUE}添加流动性 (5 NFTs + 0.5 ETH)...${NC}"
    
    local data=$(jq -n \
        --arg pool "$PAIR_CONTRACT_ADDRESS" \
        --argjson ids '[1,2,3,4,5]' \
        --arg eth "0.5" \
        '{poolAddress: $pool, nftTokenIds: $ids, ethAmount: $eth}')
    
    local response=$(api_call "POST" "/pool/add-liquidity" "$data")
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        local tx_hash=$(echo "$response" | jq -r '.data.txHash')
        echo -e "${GREEN}✅ 流动性添加成功${NC}"
        echo "   交易哈希: $tx_hash"
    else
        echo -e "${RED}❌ 流动性添加失败${NC}"
        echo "$response" | jq '.'
        return 1
    fi
}

# 部署合约
deploy_contracts() {
    echo -e "${GREEN}=== 步骤 3: 部署合约 ===${NC}"
    
    deploy_pair_factory || return 1
    sleep 1
    
    deploy_nft || return 1
    sleep 1
    
    create_pool || return 1
    sleep 1
    
    batch_approve_nft || return 1
    sleep 1
    
    add_liquidity || return 1
    
    echo ""
    echo -e "${GREEN}✅ 所有合约部署完成!${NC}"
    wait_for_user
}

# 查询合约信息
demo_contract_query() {
    echo -e "${GREEN}=== 步骤 4: 查询合约信息 ===${NC}"
    
    if [[ -z "$NFT_CONTRACT_ADDRESS" || -z "$PAIR_CONTRACT_ADDRESS" ]]; then
        echo -e "${RED}错误: 合约地址未设置${NC}"
        return 1
    fi
    
    # 查询池子信息
    echo ""
    echo "查询池子信息..."
    local pool_info=$(api_call "GET" "/pool/$NFT_CONTRACT_ADDRESS" "")
    
    if echo "$pool_info" | jq -e '.success' > /dev/null 2>&1; then
        local exists=$(echo "$pool_info" | jq -r '.data.exists')
        if [[ "$exists" == "true" ]]; then
            local pool_addr=$(echo "$pool_info" | jq -r '.data.poolAddress')
            local eth_reserve=$(echo "$pool_info" | jq -r '.data.reserves.ethReserve')
            local nft_reserve=$(echo "$pool_info" | jq -r '.data.reserves.nftReserve')
            local current_price=$(echo "$pool_info" | jq -r '.data.prices.current')
            
            echo -e "${GREEN}✅ 池子地址: $pool_addr${NC}"
            echo "   ETH 储备: $(echo "scale=6; $eth_reserve / 1000000000000000000" | bc) ETH"
            echo "   NFT 储备: $nft_reserve"
            echo "   当前价格: $(echo "scale=6; $current_price / 1000000000000000000" | bc) ETH"
        fi
    fi
    
    # 查询储备量
    echo ""
    echo "查询储备量..."
    local reserves=$(api_call "GET" "/pool/reserves" "")
    
    if echo "$reserves" | jq -e '.success' > /dev/null 2>&1; then
        local eth_reserve=$(echo "$reserves" | jq -r '.data.ethReserve')
        local nft_reserve=$(echo "$reserves" | jq -r '.data.nftReserve')
        echo -e "${GREEN}✅ ETH 储备: $(echo "scale=6; $eth_reserve / 1000000000000000000" | bc) ETH${NC}"
        echo "   NFT 储备: $nft_reserve"
    fi
    
    # 查询价格信息
    echo ""
    echo "查询价格信息..."
    local prices=$(api_call "GET" "/trade/price" "")
    
    if echo "$prices" | jq -e '.success' > /dev/null 2>&1; then
        local current=$(echo "$prices" | jq -r '.data.current')
        local sell=$(echo "$prices" | jq -r '.data.sell')
        local buy_cost=$(echo "$prices" | jq -r '.data.buy.totalCost')
        local buy_fee=$(echo "$prices" | jq -r '.data.buy.fee')
        
        if [[ "$current" != "null" ]]; then
            echo -e "${GREEN}✅ 当前价格: $(echo "scale=6; $current / 1000000000000000000" | bc) ETH${NC}"
        fi
        if [[ "$sell" != "null" ]]; then
            echo "   卖出价格: $(echo "scale=6; $sell / 1000000000000000000" | bc) ETH"
        fi
        if [[ "$buy_cost" != "null" ]]; then
            echo "   买入总成本: $(echo "scale=6; $buy_cost / 1000000000000000000" | bc) ETH"
            echo "   买入手续费: $(echo "scale=6; $buy_fee / 1000000000000000000" | bc) ETH"
        fi
    fi
    
    wait_for_user
}

# 价格监控
demo_price_monitor() {
    echo -e "${GREEN}=== 步骤 5: 价格监控演示 ===${NC}"
    echo "启动价格监控 (显示 5 次)..."
    echo ""
    
    for i in {1..5}; do
        echo "第 $i 次查询:"
        
        local reserves=$(api_call "GET" "/pool/reserves" "")
        local prices=$(api_call "GET" "/trade/price" "")
        
        if echo "$reserves" | jq -e '.success' > /dev/null 2>&1; then
            local eth_reserve=$(echo "$reserves" | jq -r '.data.ethReserve')
            local nft_reserve=$(echo "$reserves" | jq -r '.data.nftReserve')
            echo "  ETH 储备: $(echo "scale=6; $eth_reserve / 1000000000000000000" | bc) ETH"
            echo "  NFT 储备: $nft_reserve"
        fi
        
        if echo "$prices" | jq -e '.success' > /dev/null 2>&1; then
            local current=$(echo "$prices" | jq -r '.data.current')
            if [[ "$current" != "null" ]]; then
                echo "  当前价格: $(echo "scale=6; $current / 1000000000000000000" | bc) ETH"
            fi
        fi
        
        echo ""
        sleep 2
    done
    
    echo -e "${GREEN}✅ 价格监控完成${NC}"
    wait_for_user
}

# 交易演示
demo_trading() {
    echo -e "${GREEN}=== 步骤 6: 交易功能演示 ===${NC}"
    
    # 获取当前价格
    echo ""
    echo "查询当前价格和报价..."
    local prices=$(api_call "GET" "/trade/price" "")
    local quote=$(api_call "GET" "/trade/quote" "")
    
    local current_price=""
    if echo "$prices" | jq -e '.success' > /dev/null 2>&1; then
        current_price=$(echo "$prices" | jq -r '.data.current')
        if [[ "$current_price" != "null" ]]; then
            echo -e "${GREEN}当前价格: $(echo "scale=6; $current_price / 1000000000000000000" | bc) ETH${NC}"
        fi
    fi
    
    if echo "$quote" | jq -e '.success' > /dev/null 2>&1; then
        local total_cost=$(echo "$quote" | jq -r '.data.totalCost')
        local fee=$(echo "$quote" | jq -r '.data.fee')
        echo "买入总成本: $(echo "scale=6; $total_cost / 1000000000000000000" | bc) ETH"
        echo "买入手续费: $(echo "scale=6; $fee / 1000000000000000000" | bc) ETH"
    fi
    
    wait_for_user
    
    # 买入 NFT
    echo ""
    echo -e "${BLUE}=== 购买 NFT ===${NC}"
    echo "准备购买一个 NFT..."
    
    if [[ -n "$current_price" && "$current_price" != "null" ]]; then
        # 设置 5% 滑点
        local max_price=$(echo "$current_price * 1.05 / 1" | bc)
        echo "最大价格: $(echo "scale=6; $max_price / 1000000000000000000" | bc) ETH (含 5% 滑点)"
        
        local buy_data=$(jq -n --arg price "$max_price" '{maxPrice: $price}')
        local buy_response=$(api_call "POST" "/trade/buy" "$buy_data")
        
        if echo "$buy_response" | jq -e '.success' > /dev/null 2>&1; then
            local tx_hash=$(echo "$buy_response" | jq -r '.data.txHash')
            echo -e "${GREEN}✅ NFT 购买成功!${NC}"
            echo "   交易哈希: $tx_hash"
            
            # 查询购买后状态
            sleep 2
            echo ""
            echo "查询购买后状态..."
            local new_reserves=$(api_call "GET" "/pool/reserves" "")
            if echo "$new_reserves" | jq -e '.success' > /dev/null 2>&1; then
                local nft_reserve=$(echo "$new_reserves" | jq -r '.data.nftReserve')
                echo "购买后 NFT 储备: $nft_reserve"
            fi
        else
            echo -e "${RED}❌ NFT 购买失败${NC}"
            echo "$buy_response" | jq '.'
        fi
    fi
    
    wait_for_user
    
    # 卖出 NFT
    echo ""
    echo -e "${BLUE}=== 出售 NFT ===${NC}"
    echo "准备出售 NFT (ID: 1)..."
    
    if [[ -n "$current_price" && "$current_price" != "null" ]]; then
        # 设置 5% 滑点
        local min_price=$(echo "$current_price * 0.95 / 1" | bc)
        echo "最小价格: $(echo "scale=6; $min_price / 1000000000000000000" | bc) ETH (含 5% 滑点)"
        
        local sell_data=$(jq -n --arg id "1" --arg price "$min_price" '{tokenId: ($id | tonumber), minPrice: $price}')
        local sell_response=$(api_call "POST" "/trade/sell" "$sell_data")
        
        if echo "$sell_response" | jq -e '.success' > /dev/null 2>&1; then
            local tx_hash=$(echo "$sell_response" | jq -r '.data.txHash')
            echo -e "${GREEN}✅ NFT 出售成功!${NC}"
            echo "   交易哈希: $tx_hash"
            
            # 查询出售后状态
            sleep 2
            echo ""
            echo "查询出售后状态..."
            local final_reserves=$(api_call "GET" "/pool/reserves" "")
            if echo "$final_reserves" | jq -e '.success' > /dev/null 2>&1; then
                local nft_reserve=$(echo "$final_reserves" | jq -r '.data.nftReserve')
                echo "出售后 NFT 储备: $nft_reserve"
            fi
        else
            echo -e "${RED}❌ NFT 出售失败${NC}"
            echo "$sell_response" | jq '.'
        fi
    fi
    
    wait_for_user
}

# 池子管理
demo_pool_management() {
    echo -e "${GREEN}=== 步骤 7: 池子管理演示 ===${NC}"
    
    echo ""
    echo "查询池子管理信息..."
    
    # 获取池子信息
    if [[ -n "$NFT_CONTRACT_ADDRESS" ]]; then
        local pool_info=$(api_call "GET" "/pool/$NFT_CONTRACT_ADDRESS" "")
        
        if echo "$pool_info" | jq -e '.success' > /dev/null 2>&1; then
            local exists=$(echo "$pool_info" | jq -r '.data.exists')
            if [[ "$exists" == "true" ]]; then
                local pool_addr=$(echo "$pool_info" | jq -r '.data.poolAddress')
                local eth_reserve=$(echo "$pool_info" | jq -r '.data.reserves.ethReserve')
                local nft_reserve=$(echo "$pool_info" | jq -r '.data.reserves.nftReserve')
                local current_price=$(echo "$pool_info" | jq -r '.data.prices.current')
                
                echo -e "${GREEN}✅ 池子地址: $pool_addr${NC}"
                echo "   NFT 合约: $NFT_CONTRACT_ADDRESS"
                echo "   ETH 储备: $(echo "scale=6; $eth_reserve / 1000000000000000000" | bc) ETH"
                echo "   NFT 储备: $nft_reserve"
                echo "   当前价格: $(echo "scale=6; $current_price / 1000000000000000000" | bc) ETH"
            fi
        fi
    fi
    
    # 查询交易历史
    echo ""
    echo "查询交易历史..."
    local history=$(api_call "GET" "/trade/history?limit=5&offset=0" "")
    
    if echo "$history" | jq -e '.success' > /dev/null 2>&1; then
        local total=$(echo "$history" | jq -r '.data.pagination.total')
        echo -e "${GREEN}交易历史总数: $total${NC}"
        
        local items=$(echo "$history" | jq -r '.data.items')
        if [[ "$items" != "null" && "$items" != "[]" ]]; then
            echo ""
            echo "最近的交易:"
            echo "$items" | jq -r '.[] | "  • \(if .isBuy then "买入" else "卖出" end) - 价格: \(.price) wei"' | head -5
        fi
    fi
    
    echo ""
    echo -e "${GREEN}✅ 池子管理演示完成${NC}"
    wait_for_user
}

# 显示总结
show_summary() {
    echo -e "${GREEN}=== 演示总结 ===${NC}"
    echo ""
    echo "本次演示展示了以下功能:"
    echo "✅ 启动本地 Anvil 节点"
    echo "✅ 启动 API 服务器"
    echo "✅ 通过 API 部署 PairFactory、NFT 和 AMM 合约"
    echo "✅ 通过 API 创建流动性池并添加流动性"
    echo "✅ 通过 API 查询合约信息和价格"
    echo "✅ 价格监控功能"
    echo "✅ 通过 API 进行交易 (买入和卖出 NFT)"
    echo "✅ 通过 API 管理池子和查询交易历史"
    echo ""
    echo "部署的合约:"
    if [[ -n "$PAIR_FACTORY_ADDRESS" ]]; then
        echo "  PairFactory: $PAIR_FACTORY_ADDRESS"
    fi
    if [[ -n "$NFT_CONTRACT_ADDRESS" ]]; then
        echo "  NFT 合约: $NFT_CONTRACT_ADDRESS"
    fi
    if [[ -n "$PAIR_CONTRACT_ADDRESS" ]]; then
        echo "  AMM 池子: $PAIR_CONTRACT_ADDRESS"
    fi
    echo ""
    echo -e "${CYAN}API 文档地址: ${API_BASE_URL}/docs${NC}"
    echo ""
}

# 清理资源
cleanup() {
    echo -e "${YELLOW}清理资源...${NC}"
    
    if [[ -n "$ANVIL_PID" ]] && kill -0 "$ANVIL_PID" 2>/dev/null; then
        echo "停止 Anvil 节点..."
        kill "$ANVIL_PID" 2>/dev/null || true
    fi
    
    if [[ -n "$API_SERVER_PID" ]] && kill -0 "$API_SERVER_PID" 2>/dev/null; then
        echo "停止 API 服务器..."
        kill "$API_SERVER_PID" 2>/dev/null || true
    fi
    
    # 清理日志文件
    rm -f anvil.log api-server.log
    
    echo -e "${GREEN}清理完成!${NC}"
}

# 信号处理
trap cleanup EXIT INT TERM

# 主函数
main() {
    show_title
    check_dependencies
    wait_for_user
    
    start_anvil
    start_api_server
    deploy_contracts
    demo_contract_query
    demo_price_monitor
    demo_trading
    demo_pool_management
    
    show_summary
    wait_for_user
}

# 运行主函数
main "$@"

