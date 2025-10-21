#!/bin/bash

# NFT DEX API 演示脚本 (纯 Shell 版本)
# 使用 curl 调用 API 完成所有演示功能

# 严格模式：任何命令失败时立即退出
set -e
set -o pipefail

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

# 获取项目根目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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
    echo -e "${CYAN}║  • 交易前后价格监控                                       ║${NC}"
    echo -e "${CYAN}║  • 通过 API 演示 NFT 交易功能                             ║${NC}"
    echo -e "${CYAN}║  • 展示池子管理和交易历史                                 ║${NC}"
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
    
    if ! command -v cast &> /dev/null; then
        missing_deps+=("cast")
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
                anvil|cast)
                    echo "  - Foundry (包含 anvil 和 cast): https://book.getfoundry.sh/getting-started/installation"
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
            # 可选调试输出到 stderr，包含实际 payload（仅用于可视化，不影响功能）
            if [[ "$VERBOSE_CURL" == "1" ]]; then
                # 将单引号转义，确保在单引号包裹中安全显示
                local _payload_print
                _payload_print=$(printf "%s" "$data" | sed "s/'/'\\''/g")
                echo "curl -s -X POST '$url' --max-time '$timeout' --connect-timeout 10 -H 'Content-Type: application/json' -d '$_payload_print'" >&2
            fi
            curl -s -X POST "$url" \
                --max-time "$timeout" \
                --connect-timeout 10 \
                -H "Content-Type: application/json" \
                -d "$data"
        else
            # 如果没有数据，发送空的 JSON 对象
            if [[ "$VERBOSE_CURL" == "1" ]]; then
                echo "curl -s -X POST '$url' --max-time '$timeout' --connect-timeout 10 -H 'Content-Type: application/json' -d '{}'" >&2
            fi
            curl -s -X POST "$url" \
                --max-time "$timeout" \
                --connect-timeout 10 \
                -H "Content-Type: application/json" \
                -d '{}'
        fi
    else
        if [[ "$VERBOSE_CURL" == "1" ]]; then
            echo "curl -s -X GET '$url' --max-time '$timeout' --connect-timeout 10" >&2
        fi
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
        echo -e "${YELLOW}端口 8545 已被占用，检查 Anvil 是否正常运行...${NC}"
        
        # 验证 Anvil 是否正常工作
        if curl -s -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            "$RPC_URL" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Anvil 节点已在运行且正常工作${NC}"
        else
            echo -e "${RED}❌ 端口被占用但 Anvil 无响应，请手动清理${NC}"
            echo "运行: pkill anvil && ./scripts/start-fresh.sh"
            return 1
        fi
    else
        anvil --host 0.0.0.0 --port 8545 > anvil.log 2>&1 &
        ANVIL_PID=$!
        
        echo "等待 Anvil 启动..."
        sleep 3
        
        # 检查 Anvil 是否启动成功
        if curl -s -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            "$RPC_URL" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Anvil 节点启动成功!${NC}"
        else
            echo -e "${RED}❌ Anvil 节点启动失败${NC}"
            return 1
        fi
    fi
    
    # 不再等待用户确认，直接继续流程
}

# 启动 API 服务器
start_api_server() {
    echo -e "${GREEN}=== 步骤 2: 启动 API 服务器 ===${NC}"
    echo "启动 API 服务器在 $API_BASE_URL..."
    
    # 检查端口是否已被占用
    if lsof -i :3000 &> /dev/null; then
        echo -e "${YELLOW}端口 3000 已被占用，检查 API 服务器是否正常运行...${NC}"
        
        # 验证 API 服务器是否正常工作
        if curl -s "$API_BASE_URL/health" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ API 服务器已在运行且正常工作${NC}"
        else
            echo -e "${RED}❌ 端口被占用但 API 服务器无响应，请手动清理${NC}"
            echo "运行: pkill -f 'npm run dev' && ./scripts/start-fresh.sh"
            return 1
        fi
    else
        # API 目录路径
        API_DIR="$PROJECT_ROOT/api"
        
        if [[ ! -d "$API_DIR" ]]; then
            echo -e "${RED}错误: API 目录不存在: $API_DIR${NC}"
            return 1
        fi
        
        cd "$API_DIR" || return 1
        npm run dev > ../api-server.log 2>&1 &
        API_SERVER_PID=$!
        cd "$PROJECT_ROOT" || return 1
        
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
            return 1
        fi
        echo ""
    fi
    
    # 不再等待用户确认，直接继续流程
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
    echo -e "${BLUE}部署 NFT 合约（将自动铸造 10 个 NFT）...${NC}"
    echo "（此操作可能需要 30-60 秒，请耐心等待...）"
    
    local data='{
        "name": "Demo NFT Collection",
        "symbol": "DEMO",
        "baseURI": "https://api.example.com/metadata/",
        "maxSupply": 10000,
        "maxMintPerAddress": 10,
        "mintPrice": "0.01"
    }'
    
    local response=$(api_call "POST" "/deploy/nft" "$data")
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
        NFT_CONTRACT_ADDRESS=$(echo "$response" | jq -r '.data.contractAddress')
        local tx_hash=$(echo "$response" | jq -r '.data.txHash')
        local minted=$(echo "$response" | jq -r '.data.mintedNFTs // empty')
        local token_ids=$(echo "$response" | jq -r '.data.mintedTokenIds // empty')
        
        if [[ -z "$minted" || "$minted" == "null" ]]; then
            minted="未知"
        fi
        
        echo -e "${GREEN}✅ NFT 合约部署成功${NC}"
        echo "   地址: $NFT_CONTRACT_ADDRESS"
        echo "   交易哈希: $tx_hash"
        echo "   已铸造 NFT: $minted 个"
        
        if [[ -n "$token_ids" && "$token_ids" != "null" && "$token_ids" != "[]" ]]; then
            echo "   Token IDs: $token_ids"
        else
            echo -e "${YELLOW}   ⚠️ 警告: 未能从响应中获取 Token IDs${NC}"
        fi
        
        # 额外验证：使用 cast 查询实际的总供应量
        echo ""
        echo "验证 NFT 铸造状态..."
        sleep 2  # 等待区块链确认
        
        local actual_supply=$(cast call "$NFT_CONTRACT_ADDRESS" "totalSupply()(uint256)" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
        echo "   实际总供应量: $actual_supply"
        
        if [[ "$actual_supply" == "0" ]]; then
            echo -e "${RED}❌ 错误: NFT 铸造失败！总供应量为 0${NC}"
            echo "虽然合约部署成功，但 NFT 没有被铸造"
            return 1
        fi
        
        # 查询第一个 NFT 的所有者
        local owner_of_1=$(cast call "$NFT_CONTRACT_ADDRESS" "ownerOf(uint256)(address)" 1 --rpc-url "$RPC_URL" 2>/dev/null || echo "")
        if [[ -n "$owner_of_1" && "$owner_of_1" != "0x0000000000000000000000000000000000000000" ]]; then
            echo "   Token ID 1 所有者: $owner_of_1"
        else
            echo -e "${YELLOW}   ⚠️ 无法查询 Token ID 1${NC}"
        fi
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
    
    # 先验证 NFT 是否已经铸造
    echo "验证 NFT 铸造状态..."
    
    # 使用 cast 调用合约查询总供应量
    local total_supply=$(cast call "$NFT_CONTRACT_ADDRESS" "totalSupply()(uint256)" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
    
    if [[ -z "$total_supply" || "$total_supply" == "0" ]]; then
        echo -e "${RED}❌ NFT 合约中没有 NFT！总供应量为 0${NC}"
        echo "NFT 可能没有正确铸造。"
        return 1
    fi
    
    echo "NFT 总供应量: $total_supply"
    
    # 验证前 5 个 NFT 的所有者
    local deployer=$(cast call "$NFT_CONTRACT_ADDRESS" "owner()(address)" --rpc-url "$RPC_URL" 2>/dev/null)
    echo "NFT 合约所有者: $deployer"
    
    # 检查 token ID 1 是否存在
    local owner_of_1=$(cast call "$NFT_CONTRACT_ADDRESS" "ownerOf(uint256)(address)" 1 --rpc-url "$RPC_URL" 2>/dev/null || echo "")
    if [[ -z "$owner_of_1" || "$owner_of_1" == "0x0000000000000000000000000000000000000000" ]]; then
        echo -e "${RED}❌ Token ID 1 不存在或所有者为零地址${NC}"
        return 1
    fi
    
    echo "Token ID 1 的所有者: $owner_of_1"
    
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
            # API 已经返回格式化后的 ETH 值（字符串），直接显示
            echo "   ETH 储备: $eth_reserve ETH"
            echo "   NFT 储备: $nft_reserve"
            echo "   当前价格: $current_price ETH"
        fi
    fi
    
    # 查询储备量
    echo ""
    echo "查询储备量..."
    local reserves=$(api_call "GET" "/pool/reserves" "")
    
    if echo "$reserves" | jq -e '.success' > /dev/null 2>&1; then
        local eth_reserve=$(echo "$reserves" | jq -r '.data.ethReserve')
        local nft_reserve=$(echo "$reserves" | jq -r '.data.nftReserve')
        # API 已经返回格式化后的 ETH 值（字符串），直接显示
        echo -e "${GREEN}✅ ETH 储备: $eth_reserve ETH${NC}"
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
        
        # API 已经返回格式化后的 ETH 值（字符串），直接显示
        if [[ "$current" != "null" ]]; then
            echo -e "${GREEN}✅ 当前价格: $current ETH${NC}"
        fi
        if [[ "$sell" != "null" ]]; then
            echo "   卖出价格: $sell ETH"
        fi
        if [[ "$buy_cost" != "null" ]]; then
            echo "   买入总成本: $buy_cost ETH"
            echo "   买入手续费: $buy_fee ETH"
        fi
    fi
    
    wait_for_user
}

# 价格监控（交易前）
demo_price_before_trade() {
    echo -e "${GREEN}=== 步骤 5: 交易前价格查询 ===${NC}"
    echo ""
    
    local reserves=$(api_call "GET" "/pool/reserves" "")
    local prices=$(api_call "GET" "/trade/price" "")
    
    if echo "$reserves" | jq -e '.success' > /dev/null 2>&1; then
        local eth_reserve=$(echo "$reserves" | jq -r '.data.ethReserve')
        local nft_reserve=$(echo "$reserves" | jq -r '.data.nftReserve')
        echo -e "${BLUE}交易前状态：${NC}"
        echo "  ETH 储备: $eth_reserve ETH"
        echo "  NFT 储备: $nft_reserve"
    else
        echo -e "${RED}❌ 储备查询失败${NC}"
        return 1
    fi
    
    if echo "$prices" | jq -e '.success' > /dev/null 2>&1; then
        local current=$(echo "$prices" | jq -r '.data.current')
        if [[ "$current" != "null" ]]; then
            echo "  当前价格: $current ETH"
        fi
    fi
    
    echo ""
    wait_for_user
}

# 价格监控（交易后）
demo_price_after_trade() {
    echo ""
    echo -e "${GREEN}=== 交易后价格查询 ===${NC}"
    echo ""
    
    local reserves=$(api_call "GET" "/pool/reserves" "")
    local prices=$(api_call "GET" "/trade/price" "")
    
    if echo "$reserves" | jq -e '.success' > /dev/null 2>&1; then
        local eth_reserve=$(echo "$reserves" | jq -r '.data.ethReserve')
        local nft_reserve=$(echo "$reserves" | jq -r '.data.nftReserve')
        echo -e "${BLUE}交易后状态：${NC}"
        echo "  ETH 储备: $eth_reserve ETH"
        echo "  NFT 储备: $nft_reserve"
    else
        echo -e "${RED}❌ 储备查询失败${NC}"
        return 1
    fi
    
    if echo "$prices" | jq -e '.success' > /dev/null 2>&1; then
        local current=$(echo "$prices" | jq -r '.data.current')
        if [[ "$current" != "null" ]]; then
            echo "  当前价格: $current ETH"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}✅ 价格监控完成${NC}"
}

# 交易演示
demo_trading() {
    echo -e "${GREEN}=== 步骤 6: 交易功能演示 ===${NC}"
    echo ""
    
    # 获取当前价格
    local current_price=""
    local prices=$(api_call "GET" "/trade/price" "")
    
    if echo "$prices" | jq -e '.success' > /dev/null 2>&1; then
        current_price=$(echo "$prices" | jq -r '.data.current')
        if [[ "$current_price" == "null" || -z "$current_price" ]]; then
            echo -e "${RED}❌ 无法获取当前价格${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ 价格查询失败${NC}"
        return 1
    fi
    
    # 买入 NFT
    echo ""
    echo -e "${BLUE}=== 购买 NFT ===${NC}"
    echo "准备购买一个 NFT..."
    echo ""
    
    # 设置 5% 滑点
    # current_price 是 ETH 字符串（如 "0.1"），计算带滑点的价格
    local max_price_eth=$(echo "scale=18; $current_price * 1.05" | bc)
    # 规范化为以数字开头的十进制（避免 .11 这种形式导致 schema 校验失败）
    if [[ "$max_price_eth" == .* ]]; then
        max_price_eth="0$max_price_eth"
    fi
    echo "当前价格: $current_price ETH"
    echo "最大价格: $max_price_eth ETH (含 5% 滑点)"
    
    # API 期望 ETH 字符串，会自动转换为 wei，所以直接传递 ETH 值
    local buy_data=$(jq -n --arg price "$max_price_eth" '{maxPrice: $price}')
    local buy_response=$(api_call "POST" "/trade/buy" "$buy_data")
    
    if echo "$buy_response" | jq -e '.success' > /dev/null 2>&1; then
        local tx_hash=$(echo "$buy_response" | jq -r '.data.txHash')
        echo -e "${GREEN}✅ NFT 购买成功!${NC}"
        echo "   交易哈希: $tx_hash"
    else
        echo -e "${RED}❌ NFT 购买失败${NC}"
        echo "$buy_response" | jq '.'
        return 1
    fi
    
    wait_for_user
    
    # 卖出 NFT
    echo ""
    echo -e "${BLUE}=== 出售 NFT ===${NC}"
    echo "准备出售 NFT..."
    echo ""
    
    # 重新查询卖出价格（购买后价格会变化）
    local sell_prices=$(api_call "GET" "/trade/price?type=sell" "")
    local sell_current_price=""
    
    if echo "$sell_prices" | jq -e '.success' > /dev/null 2>&1; then
        sell_current_price=$(echo "$sell_prices" | jq -r '.data.sell')
        if [[ "$sell_current_price" == "null" || -z "$sell_current_price" ]]; then
            echo -e "${RED}❌ 无法获取卖出价格${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ 价格查询失败${NC}"
        return 1
    fi
    
    # 选择当前账户实际持有的一个 NFT 作为出售目标
    local seller_address="${SELLER_ADDRESS:-0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266}"
    local owner_balance=$(cast call "$NFT_CONTRACT_ADDRESS" "balanceOf(address)(uint256)" "$seller_address" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
    local token_id_to_sell=""
    if [[ "$owner_balance" != "0" ]]; then
        token_id_to_sell=$(cast call "$NFT_CONTRACT_ADDRESS" "tokenOfOwnerByIndex(address,uint256)(uint256)" "$seller_address" 0 --rpc-url "$RPC_URL" 2>/dev/null || echo "")
    fi
    if [[ -z "$token_id_to_sell" ]]; then
        echo -e "${RED}❌ 当前账户无可出售的 NFT${NC}"
        return 1
    fi
    echo "将出售的 Token ID: $token_id_to_sell"

    # 设置 5% 滑点
    # sell_current_price 是 ETH 字符串（如 "0.083..."），计算带滑点的价格
    local min_price_eth=$(echo "scale=18; $sell_current_price * 0.95" | bc)
    # 规范化，避免以 . 开头
    if [[ "$min_price_eth" == .* ]]; then
        min_price_eth="0$min_price_eth"
    fi
    echo "卖出价格: $sell_current_price ETH"
    echo "最小价格: $min_price_eth ETH (含 5% 滑点)"
    
    # 确保池子对该 tokenId 拥有转移权限（approve）
    local approve_payload=$(jq -n \
        --arg nft "$NFT_CONTRACT_ADDRESS" \
        --arg pool "$PAIR_CONTRACT_ADDRESS" \
        --argjson id "$token_id_to_sell" \
        '{nftContractAddress: $nft, poolAddress: $pool, tokenId: $id}')
    local approve_resp=$(api_call "POST" "/pool/approve-nft" "$approve_payload")
    if ! echo "$approve_resp" | jq -e '.success' > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  NFT 授权池子失败，可能已授权，继续尝试出售...${NC}"
    fi

    # API 期望 ETH 字符串，会自动转换为 wei，所以直接传递 ETH 值
    local sell_data=$(jq -n --arg id "$token_id_to_sell" --arg price "$min_price_eth" '{tokenId: ($id | tonumber), minPrice: $price}')
    local sell_response=$(api_call "POST" "/trade/sell" "$sell_data")
    
    if echo "$sell_response" | jq -e '.success' > /dev/null 2>&1; then
        local tx_hash=$(echo "$sell_response" | jq -r '.data.txHash')
        echo -e "${GREEN}✅ NFT 出售成功!${NC}"
        echo "   交易哈希: $tx_hash"
    else
        echo -e "${RED}❌ NFT 出售失败${NC}"
        echo "$sell_response" | jq '.'
        return 1
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
            else
                echo -e "${RED}❌ 池子不存在${NC}"
                return 1
            fi
        else
            echo -e "${RED}❌ 查询池子信息失败${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ NFT 合约地址未设置${NC}"
        return 1
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
    
    # 写入 PRIVATE_KEY 到项目根目录的 .env 文件
    echo "PRIVATE_KEY=ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" > "$PROJECT_ROOT/.env"
    echo -e "${GREEN}✅ 已将 PRIVATE_KEY 写入 $PROJECT_ROOT/.env${NC}"
    echo ""
    
    wait_for_user
    
    start_anvil || { echo -e "${RED}❌ Anvil 启动失败，脚本终止${NC}"; exit 1; }
    start_api_server || { echo -e "${RED}❌ API 服务器启动失败，脚本终止${NC}"; exit 1; }
    deploy_contracts || { echo -e "${RED}❌ 合约部署失败，脚本终止${NC}"; exit 1; }
    demo_contract_query || { echo -e "${RED}❌ 合约查询失败，脚本终止${NC}"; exit 1; }
    demo_price_before_trade || { echo -e "${RED}❌ 交易前价格查询失败，脚本终止${NC}"; exit 1; }
    demo_trading || { echo -e "${RED}❌ 交易演示失败，脚本终止${NC}"; exit 1; }
    demo_price_after_trade || { echo -e "${RED}❌ 交易后价格查询失败，脚本终止${NC}"; exit 1; }
    demo_pool_management || { echo -e "${RED}❌ 池子管理失败，脚本终止${NC}"; exit 1; }
    
    show_summary
    wait_for_user
}

# 运行主函数
main "$@"

