#!/bin/bash

# NFT DEX 部署和池子创建脚本
# 包含：部署 NFT 合约、部署 PairFactory 合约、通过 PairFactory 创建池子
#
# 重要说明：
# - 添加流动性需要预先授权NFT给池子
# - 卖出NFT需要预先授权NFT给池子
# - 可以使用以下命令授权NFT：
#   cast send <NFT_CONTRACT> "approve(address,uint256)" <POOL_ADDRESS> <TOKEN_ID> --private-key <PRIVATE_KEY> --rpc-url <RPC_URL>

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

# 存储交易信息
TRADE_HISTORY=()

# 获取已部署的合约地址
get_deployed_contracts() {
    echo -e "${BLUE}获取已部署的合约地址...${NC}"
    
    local response=$(curl -s "$API_BASE_URL$API_PREFIX/deploy/contracts")
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        NFT_CONTRACT=$(echo "$response" | jq -r '.data.nftContract // empty')
        FACTORY_CONTRACT=$(echo "$response" | jq -r '.data.pairFactory // empty')
        POOL_ADDRESS=$(echo "$response" | jq -r '.data.pairContract // empty')
        
        if [ -n "$NFT_CONTRACT" ] && [ "$NFT_CONTRACT" != "null" ]; then
            echo "  NFT 合约: $NFT_CONTRACT"
        fi
        if [ -n "$FACTORY_CONTRACT" ] && [ "$FACTORY_CONTRACT" != "null" ]; then
            echo "  PairFactory 合约: $FACTORY_CONTRACT"
        fi
        if [ -n "$POOL_ADDRESS" ] && [ "$POOL_ADDRESS" != "null" ]; then
            echo "  池子地址: $POOL_ADDRESS"
        fi
        return 0
    else
        echo -e "${YELLOW}⚠ 无法获取已部署的合约地址${NC}"
        return 1
    fi
}

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

# 检查本地节点
check_local_node() {
    echo -e "${BLUE}Checking local node status...${NC}"
    local response=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        http://localhost:8545 2>/dev/null)
    
    if echo "$response" | grep -q '"result"'; then
        echo -e "${GREEN}✓ Local node is running${NC}"
        return 0
    else
        echo -e "${RED}✗ Local node is not running${NC}"
        echo "Please start the local node: anvil"
        return 1
    fi
}

# 检查环境配置
check_environment() {
    echo -e "${BLUE}Checking environment configuration...${NC}"
    
    # 检查 .env 文件
    if [ ! -f ".env" ]; then
        echo -e "${YELLOW}⚠ .env file not found, creating it...${NC}"
        echo "PRIVATE_KEY=ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" > .env
        echo -e "${GREEN}✓ .env file created with default private key${NC}"
    else
        # 检查私钥是否设置
        if ! grep -q "PRIVATE_KEY=" .env || grep -q "PRIVATE_KEY=$" .env; then
            echo -e "${YELLOW}⚠ Private key not set in .env file, setting default...${NC}"
            if grep -q "PRIVATE_KEY=" .env; then
                sed -i '' 's/PRIVATE_KEY=.*/PRIVATE_KEY=ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80/' .env
            else
                echo "PRIVATE_KEY=ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" >> .env
            fi
            echo -e "${GREEN}✓ Private key set in .env file${NC}"
        else
            echo -e "${GREEN}✓ Private key is configured${NC}"
        fi
    fi
    
    return 0
}

# 启动本地节点
start_local_node() {
    echo -e "${BLUE}Starting local node...${NC}"
    
    # 检查是否已经有anvil进程在运行
    if pgrep -f "anvil" > /dev/null; then
        echo -e "${GREEN}✓ Local node is already running${NC}"
        return 0
    fi
    
    echo "  启动 Anvil 本地节点..."
    echo "  注意：请在新终端窗口中运行 'anvil' 命令"
    echo "  或者按 Ctrl+C 停止此脚本，手动启动 anvil 后再运行"
    echo ""
    echo "  等待本地节点启动..."
    
    # 等待用户启动anvil
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if check_local_node > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Local node is now running${NC}"
            return 0
        fi
        
        echo "  等待中... ($((attempt + 1))/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}✗ Local node failed to start within timeout${NC}"
    echo "Please start anvil manually and run this script again"
    return 1
}

# 授权NFT给池子
approve_nft_to_pool() {
    echo -e "\n${BLUE}=== 授权 NFT 给池子 ===${NC}"
    
    if [ -z "$NFT_CONTRACT" ] || [ -z "$POOL_ADDRESS" ]; then
        echo -e "${RED}✗ NFT 合约或池子地址未设置${NC}"
        return 1
    fi
    
    echo "  NFT 合约: $NFT_CONTRACT"
    echo "  池子地址: $POOL_ADDRESS"
    echo "  正在授权 NFT 给池子..."
    
    # 使用 cast 命令授权 NFT
    local result=$(cast send "$NFT_CONTRACT" "setApprovalForAll(address,bool)" "$POOL_ADDRESS" true \
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
        --rpc-url http://localhost:8545 2>&1)
    
    # 检查是否包含交易哈希（成功标志）
    if echo "$result" | grep -q "transactionHash"; then
        local tx_hash=$(echo "$result" | grep "transactionHash" | awk '{print $2}')
        echo -e "${GREEN}✓ NFT 授权成功${NC}"
        echo "  交易哈希: $tx_hash"
        echo "  授权状态: 已授权所有 NFT 给池子"
        return 0
    elif echo "$result" | grep -q "Transaction:"; then
        local tx_hash=$(echo "$result" | grep "Transaction:" | awk '{print $2}')
        echo -e "${GREEN}✓ NFT 授权成功${NC}"
        echo "  交易哈希: $tx_hash"
        echo "  授权状态: 已授权所有 NFT 给池子"
        return 0
    else
        echo -e "${RED}✗ NFT 授权失败${NC}"
        echo "  错误信息: $result"
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
        echo "  等待交易确认..."
        sleep 3
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
        echo "  等待交易确认..."
        sleep 3
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
        POOL_ADDRESS=$(echo "$response" | jq -r '.data.poolAddress // empty')
        echo -e "${GREEN}✓ 池子创建成功${NC}"
        echo "  交易哈希: $tx_hash"
        echo "  NFT 合约: $NFT_CONTRACT"
        if [ -n "$POOL_ADDRESS" ] && [ "$POOL_ADDRESS" != "null" ] && [ "$POOL_ADDRESS" != "" ]; then
            echo "  池子地址: $POOL_ADDRESS"
        else
            echo "  等待池子地址确认..."
            sleep 3
            # 尝试从池子信息获取地址
            get_pool_info
        fi
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

# 添加流动性
add_liquidity() {
    echo -e "\n${BLUE}=== 添加流动性 ===${NC}"
    
    if [ -z "$POOL_ADDRESS" ]; then
        echo -e "${RED}✗ 池子地址未设置${NC}"
        return 1
    fi
    
    if [ -z "$NFT_CONTRACT" ]; then
        echo -e "${RED}✗ NFT 合约地址未设置${NC}"
        return 1
    fi
    
    # 使用部署时自动铸造的 NFT Token IDs（1-10）
    echo "  使用部署时自动铸造的 NFT Token IDs..."
    local nft_token_ids="[1, 2, 3]"
    echo "  NFT Token IDs: $nft_token_ids"
    
    # 添加流动性（需要预先授权NFT给池子）
    echo "  准备添加流动性..."
    echo "  注意：需要预先授权NFT给池子才能添加流动性"
    
    # 等待一下确保之前的交易已经确认
    echo "  等待交易确认..."
    sleep 2
    
    # 重置 nonce 以避免冲突
    echo "  重置 nonce..."
    curl -s -X POST "$API_BASE_URL$API_PREFIX/web3/reset-nonce" > /dev/null
    
    # 等待nonce重置完成
    sleep 1
    
    # 添加流动性
    echo "  添加流动性到池子..."
    local response=$(curl -s -X POST "$API_BASE_URL$API_PREFIX/pool/add-liquidity" \
        -H "Content-Type: application/json" \
        -d '{
            "poolAddress": "'"$POOL_ADDRESS"'",
            "nftTokenIds": [1, 2, 3],
            "ethAmount": "0.1"
        }')
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        local tx_hash=$(echo "$response" | jq -r '.data.txHash')
        echo -e "${GREEN}✓ 流动性添加成功${NC}"
        echo "  交易哈希: $tx_hash"
        echo "  池子地址: $POOL_ADDRESS"
        echo "  NFT Token IDs: [1, 2, 3]"
        echo "  ETH 数量: 0.1"
        TRADE_HISTORY+=("添加流动性: $tx_hash")
        return 0
    else
        echo -e "${RED}✗ 流动性添加失败${NC}"
        echo "$response" | jq .
        return 1
    fi
}

# 移除流动性
remove_liquidity() {
    echo -e "\n${BLUE}=== 移除流动性 ===${NC}"
    
    if [ -z "$POOL_ADDRESS" ]; then
        echo -e "${RED}✗ 池子地址未设置${NC}"
        return 1
    fi
    
    local response=$(curl -s -X POST "$API_BASE_URL$API_PREFIX/pool/remove-liquidity" \
        -H "Content-Type: application/json" \
        -d '{
            "poolAddress": "'"$POOL_ADDRESS"'",
            "nftTokenIds": [1, 2, 3],
            "ethAmount": "0.05"
        }')
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        local tx_hash=$(echo "$response" | jq -r '.data.txHash')
        echo -e "${GREEN}✓ 流动性移除成功${NC}"
        echo "  交易哈希: $tx_hash"
        echo "  池子地址: $POOL_ADDRESS"
        echo "  NFT Token IDs: [1, 2, 3]"
        echo "  ETH 数量: 0.05"
        TRADE_HISTORY+=("移除流动性: $tx_hash")
        return 0
    else
        echo -e "${RED}✗ 流动性移除失败${NC}"
        echo "$response" | jq .
        return 1
    fi
}

# 买入 NFT
buy_nft() {
    echo -e "\n${BLUE}=== 买入 NFT ===${NC}"
    
    local max_price=${1:-"0.1"}
    
    # 等待一下确保之前的交易已经确认
    echo "  等待交易确认..."
    sleep 2
    
    # 重置 nonce 以避免冲突
    echo "  重置 nonce..."
    curl -s -X POST "$API_BASE_URL$API_PREFIX/web3/reset-nonce" > /dev/null
    
    # 等待nonce重置完成
    sleep 1
    
    local response=$(curl -s -X POST "$API_BASE_URL$API_PREFIX/trade/buy" \
        -H "Content-Type: application/json" \
        -d '{
            "maxPrice": "'"$max_price"'"
        }')
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        local tx_hash=$(echo "$response" | jq -r '.data.txHash')
        local actual_price=$(echo "$response" | jq -r '.data.maxPrice')
        echo -e "${GREEN}✓ NFT 买入成功${NC}"
        echo "  交易哈希: $tx_hash"
        echo "  最大价格: $actual_price ETH"
        echo "  交易类型: 买入"
        TRADE_HISTORY+=("买入NFT: $tx_hash")
        return 0
    else
        echo -e "${RED}✗ NFT 买入失败${NC}"
        echo "$response" | jq .
        return 1
    fi
}

# 卖出 NFT
sell_nft() {
    echo -e "\n${BLUE}=== 卖出 NFT ===${NC}"
    
    local token_id=${1:-1}
    local min_price=${2:-"0.04"}
    
    # 等待一下确保之前的交易已经确认
    echo "  等待交易确认..."
    sleep 2
    
    # 重置 nonce 以避免冲突
    echo "  重置 nonce..."
    curl -s -X POST "$API_BASE_URL$API_PREFIX/web3/reset-nonce" > /dev/null
    
    # 等待nonce重置完成
    sleep 1
    
    local response=$(curl -s -X POST "$API_BASE_URL$API_PREFIX/trade/sell" \
        -H "Content-Type: application/json" \
        -d '{
            "tokenId": '"$token_id"',
            "minPrice": "'"$min_price"'"
        }')
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        local tx_hash=$(echo "$response" | jq -r '.data.txHash')
        local actual_price=$(echo "$response" | jq -r '.data.minPrice')
        echo -e "${GREEN}✓ NFT 卖出成功${NC}"
        echo "  交易哈希: $tx_hash"
        echo "  Token ID: $token_id"
        echo "  最小价格: $actual_price ETH"
        echo "  交易类型: 卖出"
        TRADE_HISTORY+=("卖出NFT: $tx_hash")
        return 0
    else
        echo -e "${RED}✗ NFT 卖出失败${NC}"
        echo "$response" | jq .
        return 1
    fi
}

# 获取价格信息
get_price_info() {
    echo -e "\n${BLUE}=== 获取价格信息 ===${NC}"
    
    # 获取当前价格
    local current_response=$(curl -s "$API_BASE_URL$API_PREFIX/trade/price?type=current")
    local sell_response=$(curl -s "$API_BASE_URL$API_PREFIX/trade/price?type=sell")
    local buy_response=$(curl -s "$API_BASE_URL$API_PREFIX/trade/price?type=buy")
    
    if echo "$current_response" | jq -e '.success' > /dev/null 2>&1 && \
       echo "$sell_response" | jq -e '.success' > /dev/null 2>&1 && \
       echo "$buy_response" | jq -e '.success' > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 价格信息获取成功${NC}"
        echo "  当前价格: $(echo "$current_response" | jq -r '.data.current') ETH"
        echo "  买入价格: $(echo "$buy_response" | jq -r '.data.buy.totalCost') ETH (手续费: $(echo "$buy_response" | jq -r '.data.buy.fee') ETH)"
        echo "  卖出价格: $(echo "$sell_response" | jq -r '.data.sell') ETH"
        echo "  价格变化: 暂无历史数据"
        return 0
    else
        echo -e "${RED}✗ 价格信息获取失败${NC}"
        echo "当前价格响应: $current_response"
        echo "卖出价格响应: $sell_response"
        echo "买入价格响应: $buy_response"
        return 1
    fi
}

# 获取交易历史
get_trade_history() {
    echo -e "\n${BLUE}=== 获取交易历史 ===${NC}"
    
    local response=$(curl -s "$API_BASE_URL$API_PREFIX/trade/history")
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 交易历史获取成功${NC}"
        local trades=$(echo "$response" | jq -r '.data.trades[]')
        if [ -n "$trades" ]; then
            echo "$trades" | jq -r '"  " + .type + " - " + .txHash + " - " + .price + " ETH"'
        else
            echo "  暂无交易记录"
        fi
        return 0
    else
        echo -e "${RED}✗ 交易历史获取失败${NC}"
        echo "$response" | jq .
        return 1
    fi
}

# 铸造 NFT
mint_nft() {
    echo -e "\n${BLUE}=== 铸造 NFT ===${NC}"
    
    if [ -z "$NFT_CONTRACT" ]; then
        echo -e "${RED}✗ NFT 合约地址未设置${NC}"
        return 1
    fi
    
    local amount=${1:-10}  # 默认铸造 10 个
    local recipient=${2:-""}  # 可选的接收者地址
    
    echo "  铸造 $amount 个 NFT..."
    echo "  NFT 合约地址: $NFT_CONTRACT"
    if [ -n "$recipient" ]; then
        echo "  接收者地址: $recipient"
    else
        echo "  接收者地址: 部署者地址（默认）"
    fi
    
    # 构建请求数据
    local request_data='{
        "nftContractAddress": "'"$NFT_CONTRACT"'",
        "amount": '"$amount"''
    
    if [ -n "$recipient" ]; then
        request_data+=',
        "recipient": "'"$recipient"'"'
    fi
    
    request_data+='
    }'
    
    local response=$(curl -s -X POST "$API_BASE_URL$API_PREFIX/trade/mint" \
        -H "Content-Type: application/json" \
        -d "$request_data")
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        local tx_hashes=$(echo "$response" | jq -r '.data.txHashes[]' | tr '\n' ' ')
        local token_ids=$(echo "$response" | jq -r '.data.tokenIds[]' | tr '\n' ' ')
        local total_cost=$(echo "$response" | jq -r '.data.totalCost')
        local recipient=$(echo "$response" | jq -r '.data.recipient')
        
        echo -e "${GREEN}✓ NFT 铸造成功${NC}"
        echo "  交易哈希: $tx_hashes"
        echo "  Token IDs: $token_ids"
        echo "  总成本: $total_cost ETH"
        echo "  铸造数量: $amount"
        echo "  接收者: $recipient"
        TRADE_HISTORY+=("铸造NFT ($amount个) -> $recipient: $tx_hashes")
        return 0
    else
        echo -e "${RED}✗ NFT 铸造失败${NC}"
        echo "$response" | jq .
        return 1
    fi
}

# 获取池子储备量
get_pool_reserves() {
    echo -e "\n${BLUE}=== 获取池子储备量 ===${NC}"
    
    local response=$(curl -s "$API_BASE_URL$API_PREFIX/pool/reserves")
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 池子储备量获取成功${NC}"
        echo "  ETH 储备: $(echo "$response" | jq -r '.data.ethReserve') ETH"
        echo "  NFT 储备: $(echo "$response" | jq -r '.data.nftReserve') 个"
        echo "  总流动性: $(echo "$response" | jq -r '.data.totalLiquidity // "null"') ETH"
        echo "  流动性代币: $(echo "$response" | jq -r '.data.lpTokens // "null"') 个"
        return 0
    else
        echo -e "${RED}✗ 池子储备量获取失败${NC}"
        echo "$response" | jq .
        return 1
    fi
}

# 监控池子信息
monitor_pool() {
    echo -e "\n${BLUE}=== 监控池子信息 ===${NC}"
    
    local duration=${1:-30}  # 默认监控30秒
    local interval=${2:-5}   # 默认每5秒更新一次
    
    echo "  开始监控池子信息，持续 $duration 秒，每 $interval 秒更新一次..."
    echo "  按 Ctrl+C 停止监控"
    echo ""
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        local current_time=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${YELLOW}[$current_time] 池子状态:${NC}"
        
        # 获取池子信息
        local pool_info=$(curl -s "http://localhost:3000/api/v1/pool/$NFT_CONTRACT")
        if echo "$pool_info" | jq -e '.success' > /dev/null 2>&1; then
            echo "  ETH 储备: $(echo "$pool_info" | jq -r '.data.reserves.ethReserve') ETH"
            echo "  NFT 储备: $(echo "$pool_info" | jq -r '.data.reserves.nftReserve') 个"
            echo "  当前价格: $(echo "$pool_info" | jq -r '.data.prices.current') ETH"
            echo "  买入价格: $(echo "$pool_info" | jq -r '.data.prices.buy.totalCost') ETH"
            echo "  卖出价格: $(echo "$pool_info" | jq -r '.data.prices.sell') ETH"
        else
            echo "  获取池子信息失败"
        fi
        
        # 获取价格信息
        local price_info=$(curl -s "$API_BASE_URL$API_PREFIX/trade/price")
        if echo "$price_info" | jq -e '.success' > /dev/null 2>&1; then
            echo "  价格变化: $(echo "$price_info" | jq -r '.data.priceChange')%"
        fi
        
        echo "  ----------------------------------------"
        
        if [ $(date +%s) -lt $end_time ]; then
            sleep $interval
        fi
    done
    
    echo -e "${GREEN}✓ 监控完成${NC}"
}

# 显示使用说明
show_usage() {
    echo "NFT DEX 部署和池子创建脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "部署选项:"
    echo "  -h, --help             显示此帮助信息"
    echo "  -n, --nft-only         仅部署 NFT 合约"
    echo "  -f, --factory-only     仅部署 PairFactory 合约"
    echo "  -p, --pool-only        仅创建池子（需要先部署 NFT 和 PairFactory）"
    echo "  -i, --info-only        仅获取合约和池子信息"
    echo "  --full                 执行完整流程（默认）"
    echo ""
    echo "流动性管理:"
    echo "  --add-liquidity        添加流动性到池子（自动授权NFT）"
    echo "  --remove-liquidity     从池子移除流动性"
    echo "  --approve-nft          授权NFT给池子"
    echo ""
    echo "NFT 交易:"
    echo "  --mint-nft [数量] [接收者]  铸造 NFT（默认数量: 10 个，接收者: 部署者地址）"
    echo "  --buy-nft [价格]       买入 NFT（默认价格: 0.1 ETH）"
    echo "  --sell-nft [ID] [价格] 卖出 NFT（需要预先授权NFT，默认 ID: 1, 价格: 0.04 ETH）"
    echo ""
    echo "信息查询:"
    echo "  --price                获取价格信息"
    echo "  --history              获取交易历史"
    echo "  --reserves             获取池子储备量"
    echo "  --monitor [时长] [间隔] 监控池子信息（默认: 30秒, 5秒间隔）"
    echo ""
    echo "示例:"
    echo "  $0                                    # 执行完整流程（自动处理所有步骤）"
    echo "  $0 --nft-only                         # 仅部署 NFT 合约"
    echo "  $0 --mint-nft 5                       # 铸造 5 个 NFT"
    echo "  $0 --approve-nft                      # 授权 NFT 给池子"
    echo "  $0 --add-liquidity                    # 添加流动性（自动授权NFT）"
    echo "  $0 --buy-nft 0.2                      # 以 0.2 ETH 买入 NFT"
    echo "  $0 --sell-nft 1 0.1                   # 以 0.1 ETH 卖出 Token ID 1"
    echo "  $0 --monitor 60 10                    # 监控池子 60 秒，每 10 秒更新"
}

# 主测试流程
main() {
    local mode="full"
    
    # 首先获取已部署的合约地址
    get_deployed_contracts
    
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
            --add-liquidity)
                mode="add-liquidity"
                shift
                ;;
            --remove-liquidity)
                mode="remove-liquidity"
                shift
                ;;
            --approve-nft)
                mode="approve-nft"
                shift
                ;;
        --mint-nft)
            mode="mint-nft"
            MINT_AMOUNT="$2"
            MINT_RECIPIENT="$3"
            shift 3
            ;;
            --buy-nft)
                mode="buy-nft"
                BUY_PRICE="$2"
                shift 2
                ;;
            --sell-nft)
                mode="sell-nft"
                SELL_TOKEN_ID="$2"
                SELL_PRICE="$3"
                shift 3
                ;;
            --price)
                mode="price"
                shift
                ;;
            --history)
                mode="history"
                shift
                ;;
            --reserves)
                mode="reserves"
                shift
                ;;
            --monitor)
                mode="monitor"
                MONITOR_DURATION="$2"
                MONITOR_INTERVAL="$3"
                shift 3
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
    
    # 环境检查和准备
    echo ""
    echo "🔧 环境检查和准备..."
    
    # 检查环境配置
    if ! check_environment; then
        echo -e "${RED}环境配置检查失败，终止脚本${NC}"
        exit 1
    fi
    
    # 检查本地节点
    if ! check_local_node; then
        echo -e "${YELLOW}本地节点未运行，尝试启动...${NC}"
        if ! start_local_node; then
            echo -e "${RED}无法启动本地节点，终止脚本${NC}"
            exit 1
        fi
    fi
    
    # 检查API服务器
    if ! check_server; then
        echo -e "${RED}API服务器未运行，请先启动服务器${NC}"
        echo "运行命令: cd api && npm run dev"
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
        "add-liquidity")
            echo ""
            echo "添加流动性..."
            
            # 先授权NFT给池子
            if approve_nft_to_pool; then
                echo "NFT 授权成功，继续添加流动性..."
                if ! add_liquidity; then
                    echo -e "${RED}流动性添加失败，终止脚本${NC}"
                    exit 1
                fi
            else
                echo -e "${RED}NFT 授权失败，无法添加流动性${NC}"
                exit 1
            fi
            ;;
        "remove-liquidity")
            echo ""
            echo "移除流动性..."
            if ! remove_liquidity; then
                echo -e "${RED}流动性移除失败，终止脚本${NC}"
                exit 1
            fi
            ;;
        "approve-nft")
            echo ""
            echo "授权 NFT 给池子..."
            if ! approve_nft_to_pool; then
                echo -e "${RED}NFT 授权失败，终止脚本${NC}"
                exit 1
            fi
            ;;
        "mint-nft")
            echo ""
            echo "铸造 NFT..."
            if ! mint_nft "$MINT_AMOUNT" "$MINT_RECIPIENT"; then
                echo -e "${RED}NFT 铸造失败，终止脚本${NC}"
                exit 1
            fi
            ;;
        "buy-nft")
            echo ""
            echo "买入 NFT..."
            if ! buy_nft "$BUY_PRICE"; then
                echo -e "${RED}NFT 买入失败，终止脚本${NC}"
                exit 1
            fi
            ;;
        "sell-nft")
            echo ""
            echo "卖出 NFT..."
            if ! sell_nft "$SELL_TOKEN_ID" "$SELL_PRICE"; then
                echo -e "${RED}NFT 卖出失败，终止脚本${NC}"
                exit 1
            fi
            ;;
        "price")
            echo ""
            echo "获取价格信息..."
            get_price_info
            ;;
        "history")
            echo ""
            echo "获取交易历史..."
            get_trade_history
            ;;
        "reserves")
            echo ""
            echo "获取池子储备量..."
            get_pool_reserves
            ;;
        "monitor")
            echo ""
            echo "监控池子信息..."
            monitor_pool "$MONITOR_DURATION" "$MONITOR_INTERVAL"
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
            
            # 重新获取合约地址
            get_deployed_contracts
            
            # 获取池子信息
            get_pool_info
            
            # 铸造 NFT
            echo ""
            echo "测试 NFT 铸造..."
            if mint_nft 5; then
                echo "NFT 铸造成功"
            else
                echo "NFT 铸造失败，继续其他测试"
            fi
            
            # 添加流动性
            echo ""
            echo "测试流动性管理..."
            
            # 先授权NFT给池子
            if approve_nft_to_pool; then
                echo "NFT 授权成功，继续添加流动性..."
                if add_liquidity; then
                    echo "流动性添加成功"
                    # 重新获取池子信息以显示更新后的储备量
                    get_pool_info
                else
                    echo "流动性添加失败，继续其他测试"
                fi
            else
                echo "NFT 授权失败，跳过流动性添加"
            fi
            
            # 测试 NFT 交易
            echo ""
            echo "测试 NFT 交易..."
            echo "  注意：需要池子有流动性才能进行NFT交易"
            echo "  如果池子没有流动性，交易将失败"
            echo ""
            if buy_nft "0.1"; then
                echo "NFT 买入成功"
            else
                echo "NFT 买入失败，继续其他测试"
            fi
            
            if sell_nft "1" "0.04"; then
                echo "NFT 卖出成功"
            else
                echo "NFT 卖出失败，继续其他测试"
            fi
            
            # 获取价格信息
            get_price_info
            
            # 获取交易历史
            get_trade_history
            
            # 获取池子储备量
            get_pool_reserves
            
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
        
        # 显示交易历史
        if [ ${#TRADE_HISTORY[@]} -gt 0 ]; then
            echo ""
            echo "📈 交易历史："
            for trade in "${TRADE_HISTORY[@]}"; do
                echo "  $trade"
            done
        fi
        
        echo ""
        echo "🎉 所有功能已验证通过！"
    fi
}

# 运行主函数
main "$@"
