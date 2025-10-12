#!/bin/bash

# NFT DEX 演示脚本
# 展示完整的 NFT DEX 功能

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
ANVIL_PID=""
DEPLOYED_CONTRACTS=""
# Anvil 默认私钥 (第一个账户)
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

# 显示标题
show_title() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    NFT DEX 功能演示                        ║${NC}"
    echo -e "${CYAN}║                                                              ║${NC}"
    echo -e "${CYAN}║  本演示将展示以下功能:                                      ║${NC}"
    echo -e "${CYAN}║  • 启动本地 Anvil 节点                                     ║${NC}"
    echo -e "${CYAN}║  • 部署 NFT 合约和 AMM 系统                               ║${NC}"
    echo -e "${CYAN}║  • 演示 NFT 交易功能                                       ║${NC}"
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
    
    if ! command -v forge &> /dev/null; then
        missing_deps+=("forge")
    fi
    
    if ! command -v cast &> /dev/null; then
        missing_deps+=("cast")
    fi
    
    if ! command -v anvil &> /dev/null; then
        missing_deps+=("anvil")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}警告: 未找到 jq 命令，合约地址提取可能失败${NC}"
        echo "请安装 jq: brew install jq (macOS) 或 apt-get install jq (Ubuntu)"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}错误: 缺少以下依赖: ${missing_deps[*]}${NC}"
        echo "请安装 Foundry: https://book.getfoundry.sh/getting-started/installation"
        exit 1
    fi
}

# 启动 Anvil 节点
start_anvil() {
    echo -e "${GREEN}=== 步骤 1: 启动 Anvil 本地节点 ===${NC}"
    echo "启动 Anvil 节点在 http://localhost:8545..."
    
    anvil --host 0.0.0.0 --port 8545 > anvil.log 2>&1 &
    ANVIL_PID=$!
    
    echo "等待 Anvil 启动..."
    sleep 3
    
    # 检查 Anvil 是否启动成功
    if curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' "$RPC_URL" > /dev/null; then
        echo -e "${GREEN}✅ Anvil 节点启动成功!${NC}"
    else
        echo -e "${RED}❌ Anvil 节点启动失败${NC}"
        exit 1
    fi
    
    wait_for_user
}

# 部署合约
deploy_contracts() {
    echo -e "${GREEN}=== 步骤 2: 部署合约 ===${NC}"
    echo "部署 AMM 系统 (NFT + AMM 合约)..."
    
    # 设置环境变量
    export PRIVATE_KEY="$PRIVATE_KEY"
    echo "PRIVATE_KEY: $PRIVATE_KEY"
    
    # 获取发送者地址
    SENDER_ADDRESS=$(cast wallet address --private-key "$PRIVATE_KEY")
    echo "SENDER_ADDRESS: $SENDER_ADDRESS"
    
    # 部署 AMM 系统
    forge script script/DeployAMMSystem.s.sol:DeployAMMSystem --fork-url "$RPC_URL" --broadcast --private-key "$PRIVATE_KEY" --sig "runLocal()" > deploy.log 2>&1
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ 合约部署成功!${NC}"
        
        # 从日志中提取合约地址
        NFT_ADDRESS=$(grep "NFT Contract:" deploy.log | awk '{print $3}' | tail -1)
        AMM_ADDRESS=$(grep "AMM Marketplace:" deploy.log | awk '{print $3}' | tail -1)
        
        # 如果从日志中提取失败，尝试从广播文件中获取
        if [[ -z "$NFT_ADDRESS" || -z "$AMM_ADDRESS" ]]; then
            echo "从日志中提取合约地址失败，尝试从广播文件中获取..."
            
            # 查找最新的广播文件
            BROADCAST_DIR="broadcast/DeployAMMSystem.s.sol/31337"
            if [[ -d "$BROADCAST_DIR" ]]; then
                LATEST_RUN=$(ls -t "$BROADCAST_DIR" | grep -E "^[0-9]+$" | head -1)
                if [[ -n "$LATEST_RUN" ]]; then
                    RUN_DIR="$BROADCAST_DIR/$LATEST_RUN"
                    if [[ -f "$RUN_DIR/run-latest.json" ]]; then
                        # 从 JSON 文件中提取合约地址
                        NFT_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "StandardNFT") | .contractAddress' "$RUN_DIR/run-latest.json" 2>/dev/null | head -1)
                        AMM_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "Pair") | .contractAddress' "$RUN_DIR/run-latest.json" 2>/dev/null | head -1)
                    fi
                fi
            fi
        fi
        
        if [[ -n "$NFT_ADDRESS" && -n "$AMM_ADDRESS" ]]; then
            DEPLOYED_CONTRACTS="NFT: $NFT_ADDRESS, AMM: $AMM_ADDRESS"
            echo "NFT 合约地址: $NFT_ADDRESS"
            echo "AMM 合约地址: $AMM_ADDRESS"
            
            # 显示 LP Token 信息（添加流动性后）
            echo -e "\n${BLUE}=== 流动性添加完成 ===${NC}"
            show_lp_token_info "$AMM_ADDRESS" "$RPC_URL"
        else
            echo -e "${YELLOW}⚠️ 无法提取合约地址，但部署可能已成功${NC}"
            echo "请手动检查 deploy.log 文件"
        fi
    else
        echo -e "${RED}❌ 合约部署失败${NC}"
        echo "查看 deploy.log 了解详情"
        echo "部署日志内容:"
        cat deploy.log
        exit 1
    fi
    
    wait_for_user
}

# 演示合约查询
demo_contract_query() {
    echo -e "${GREEN}=== 步骤 3: 查询合约信息 ===${NC}"
    
    if [[ -z "$AMM_ADDRESS" ]]; then
        echo -e "${RED}错误: 未找到 AMM 合约地址${NC}"
        return
    fi
    
    echo "查询 AMM 合约信息..."
    
    # 查询当前价格
    echo "获取当前价格..."
    current_price=$(cast call "$AMM_ADDRESS" "getCurrentPrice()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
    current_price_dec=$(cast to-dec "$current_price" 2>/dev/null || echo "0")
    
    # 使用 cast from-wei 转换为 ETH 显示
    current_price_eth=$(cast from-wei "$current_price" 2>/dev/null || echo "0")
    echo "当前价格: $current_price_eth ETH"
    
    # 查询储备量
    echo "获取池子储备量..."
    reserves=$(cast call "$AMM_ADDRESS" "getPoolReserves()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
    # 解析连续的十六进制字符串：前64个字符是ETH储备，后64个字符是NFT储备
    eth_reserve="0x${reserves:2:64}"
    nft_reserve="0x${reserves:66:64}"
    eth_reserve_dec=$(cast to-dec "$eth_reserve" 2>/dev/null || echo "0")
    nft_reserve_dec=$(cast to-dec "$nft_reserve" 2>/dev/null || echo "0")
    echo "ETH 储备: $eth_reserve_dec wei"
    echo "NFT 储备: $nft_reserve_dec"
    
    # 使用 cast from-wei 转换为 ETH 显示
    eth_reserve_eth=$(cast from-wei "$eth_reserve" 2>/dev/null || echo "0")
    echo "ETH 储备: $eth_reserve_eth ETH"
    
    # 查询交易费用
    echo "获取交易费用..."
    trading_fee=$(cast call "$AMM_ADDRESS" "TRADING_FEE()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
    trading_fee_dec=$(cast to-dec "$trading_fee" 2>/dev/null || echo "0")
    echo "交易费用: $trading_fee_dec basis points"
    
    # 查询累计收益
    echo "获取累计收益..."
    accumulated_fees=$(cast call "$AMM_ADDRESS" "accumulatedFees()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
    accumulated_fees_eth=$(cast from-wei "$accumulated_fees" 2>/dev/null || echo "0")
    echo "累计收益: $accumulated_fees_eth ETH"
    
    wait_for_user
}

# 演示价格监控
demo_price_monitor() {
    echo -e "${GREEN}=== 步骤 4: 价格监控演示 ===${NC}"
    
    if [[ -z "$AMM_ADDRESS" ]]; then
        echo -e "${RED}错误: 未找到 AMM 合约地址${NC}"
        return
    fi
    
    echo "启动价格监控 (5秒后自动停止)..."
    echo -e "${YELLOW}按 Ctrl+C 可以提前停止${NC}"
    
    # 检查价格监控脚本是否存在
    if [[ -f "./scripts/price_monitor.sh" ]]; then
        # 在后台运行价格监控 (使用 gtimeout 如果存在，否则直接运行)
        if command -v gtimeout &> /dev/null; then
            gtimeout 10s ./scripts/price_monitor.sh -c "$AMM_ADDRESS" -m || true
        elif command -v timeout &> /dev/null; then
            timeout 10s ./scripts/price_monitor.sh -c "$AMM_ADDRESS" -m || true
        else
            echo "运行价格监控脚本..."
            ./scripts/price_monitor.sh -c "$AMM_ADDRESS" -m &
            MONITOR_PID=$!
            sleep 10
            kill $MONITOR_PID 2>/dev/null || true
        fi
    else
        echo "价格监控脚本不存在，使用简单查询代替..."
        for i in {1..5}; do
            current_price=$(cast call "$AMM_ADDRESS" "getCurrentPrice()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
            reserves=$(cast call "$AMM_ADDRESS" "getPoolReserves()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
            eth_reserve="0x${reserves:2:64}"
            nft_reserve="0x${reserves:66:64}"
            echo "第 $i 次查询 - 价格: $current_price wei, ETH储备: $eth_reserve, NFT储备: $nft_reserve"
            sleep 1
        done
    fi
    
    wait_for_user
}

# 演示交易功能
demo_trading() {
    echo -e "${GREEN}=== 步骤 5: 交易功能演示 ===${NC}"
    
    if [[ -z "$AMM_ADDRESS" ]]; then
        echo -e "${RED}错误: 未找到 AMM 合约地址${NC}"
        return
    fi
    
    echo "查询当前价格信息..."
    
    # 获取价格信息
    current_price=$(cast call "$AMM_ADDRESS" "getCurrentPrice()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
    reserves=$(cast call "$AMM_ADDRESS" "getPoolReserves()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
    # 解析连续的十六进制字符串
    eth_reserve="0x${reserves:2:64}"
    nft_reserve="0x${reserves:66:64}"
    
    # 使用 cast to-dec 转换十六进制为十进制
    current_price_dec=$(cast to-dec "$current_price" 2>/dev/null || echo "0")
    eth_reserve_dec=$(cast to-dec "$eth_reserve" 2>/dev/null || echo "0")
    nft_reserve_dec=$(cast to-dec "$nft_reserve" 2>/dev/null || echo "0")
    
    # 使用 cast from-wei 转换为 ETH 单位
    current_price_eth=$(cast from-wei "$current_price" 2>/dev/null || echo "0")
    eth_reserve_eth=$(cast from-wei "$eth_reserve" 2>/dev/null || echo "0")
    
    echo "当前价格: $current_price_eth ETH"
    echo "ETH 储备: $eth_reserve_eth ETH"
    echo "NFT 储备: $nft_reserve_dec"
    
    # 显示累计收益
    accumulated_fees=$(cast call "$AMM_ADDRESS" "accumulatedFees()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
    accumulated_fees_eth=$(cast from-wei "$accumulated_fees" 2>/dev/null || echo "0")
    echo "累计收益: $accumulated_fees_eth ETH"
    
    # 显示交易历史
    echo "查询交易历史..."
    trade_count=$(cast call "$AMM_ADDRESS" "getTradeHistory()" --rpc-url "$RPC_URL" 2>/dev/null | wc -l || echo "0")
    echo "交易历史记录数: $trade_count"
    
    wait_for_user
    
    # 演示购买 NFT
    echo -e "\n${BLUE}=== 购买 NFT 演示 ===${NC}"
    echo "准备购买一个 NFT..."
    
    # 使用已经转换的十进制价格
    price_wei="$current_price_dec"
    echo "当前价格: $current_price_eth ETH"
    
    # 使用已经转换的十进制 NFT 储备量
    # nft_reserve_dec 已经在上面计算过了
    if [[ "$nft_reserve_dec" -eq 0 ]]; then
        echo -e "${YELLOW}⚠️ 池中没有 NFT 可以购买${NC}"
    else
        echo "池中有 $nft_reserve_dec 个 NFT 可以购买"
        
        # 设置最大价格为当前价格的 110% (10% 滑点容忍度)
        # 使用 bc 进行大数计算避免溢出
        if command -v bc &> /dev/null; then
            max_price=$(echo "$price_wei * 110 / 100" | bc)
        else
            max_price=$((price_wei * 110 / 100))
        fi
        max_price_eth=$(cast from-wei "$max_price" 2>/dev/null || echo "0")
        echo "设置最大价格: $max_price_eth ETH (10% 滑点容忍度)"
        
        # 授权 AMM 合约转移 NFT (如果需要)
        echo "检查 NFT 授权..."
        NFT_ADDRESS=$(grep "NFT Contract:" deploy.log | awk '{print $3}' | tail -1)
        if [[ -n "$NFT_ADDRESS" ]]; then
            echo "授权 AMM 合约转移 NFT..."
            approve_tx=$(cast send "$NFT_ADDRESS" "setApprovalForAll(address,bool)" "$AMM_ADDRESS" "true" \
                --rpc-url "$RPC_URL" \
                --private-key "$PRIVATE_KEY" 2>&1)
            
            if echo "$approve_tx" | grep -q "transactionHash"; then
                echo "✅ 授权成功"
            else
                echo "⚠️ 授权可能失败，但继续尝试购买..."
            fi
        fi
        
        # 计算总成本（价格 + 手续费）
        # 手续费是价格的 2% (200/10000)
        if command -v bc &> /dev/null; then
            fee=$(echo "$price_wei * 200 / 10000" | bc)
            total_cost=$(echo "$price_wei + $fee" | bc)
        else
            fee=$((price_wei * 200 / 10000))
            total_cost=$((price_wei + fee))
        fi
        
        # 转换为 ETH 显示
        fee_eth=$(cast from-wei "$fee" 2>/dev/null || echo "0")
        total_cost_eth=$(cast from-wei "$total_cost" 2>/dev/null || echo "0")
        echo "价格: $current_price_eth ETH, 手续费: $fee_eth ETH, 总成本: $total_cost_eth ETH"
        
        # 购买 NFT
        echo "尝试购买 NFT..."
        buy_tx=$(cast send "$AMM_ADDRESS" "buyNFT(uint256)" "$max_price" \
            --rpc-url "$RPC_URL" \
            --private-key "$PRIVATE_KEY" \
            --value "$total_cost" 2>&1)
        
        echo "购买交易结果: $buy_tx"
        
        if echo "$buy_tx" | grep -q "transactionHash"; then
            echo -e "${GREEN}✅ NFT 购买成功！${NC}"
            
            # 查询购买后的状态
            echo "查询购买后的状态..."
            new_reserves=$(cast call "$AMM_ADDRESS" "getPoolReserves()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
            new_eth_reserve="0x${new_reserves:2:64}"
            new_nft_reserve="0x${new_reserves:66:64}"
            new_nft_reserve_dec=$(cast to-dec "$new_nft_reserve" 2>/dev/null || echo "0")
            echo "购买后 NFT 储备: $new_nft_reserve_dec"
            
            # 显示购买后的累计收益
            new_accumulated_fees=$(cast call "$AMM_ADDRESS" "accumulatedFees()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
            new_accumulated_fees_eth=$(cast from-wei "$new_accumulated_fees" 2>/dev/null || echo "0")
            echo "购买后累计收益: $new_accumulated_fees_eth ETH"
            
            # 调用价格监控脚本显示最新状态
            echo -e "\n${BLUE}=== 购买后价格监控 ===${NC}"
            if [[ -f "./scripts/price_monitor.sh" ]]; then
                ./scripts/price_monitor.sh --contract "$AMM_ADDRESS" --rpc-url "$RPC_URL"
            else
                echo "价格监控脚本不存在"
            fi
            
            wait_for_user
            
            # 演示出售 NFT
            echo -e "\n${BLUE}=== 出售 NFT 演示 ===${NC}"
            echo "准备出售刚购买的 NFT (ID: 1)..."
            
            # 设置最小价格为当前价格的 90% (10% 滑点容忍度)
            # 使用 bc 进行大数计算避免溢出
            if command -v bc &> /dev/null; then
                min_price=$(echo "$price_wei * 90 / 100" | bc)
            else
                min_price=$((price_wei * 90 / 100))
            fi
            min_price_eth=$(cast from-wei "$min_price" 2>/dev/null || echo "0")
            echo "设置最小价格: $min_price_eth ETH (10% 滑点容忍度)"
            
            # 出售 NFT
            echo "尝试出售 NFT..."
            sell_tx=$(cast send "$AMM_ADDRESS" "sellNFT(uint256,uint256)" "1" "$min_price" \
                --rpc-url "$RPC_URL" \
                --private-key "$PRIVATE_KEY" 2>&1)
            
            echo "出售交易结果: $sell_tx"
            
            if echo "$sell_tx" | grep -q "transactionHash"; then
                echo -e "${GREEN}✅ NFT 出售成功！${NC}"
                
                # 查询出售后的状态
                echo "查询出售后的状态..."
                final_reserves=$(cast call "$AMM_ADDRESS" "getPoolReserves()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
                final_eth_reserve="0x${final_reserves:2:64}"
                final_nft_reserve="0x${final_reserves:66:64}"
                final_nft_reserve_dec=$(cast to-dec "$final_nft_reserve" 2>/dev/null || echo "0")
                echo "出售后 NFT 储备: $final_nft_reserve_dec"
                
                # 显示出售后的累计收益
                final_accumulated_fees=$(cast call "$AMM_ADDRESS" "accumulatedFees()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
                final_accumulated_fees_eth=$(cast from-wei "$final_accumulated_fees" 2>/dev/null || echo "0")
                echo "出售后累计收益: $final_accumulated_fees_eth ETH"
                
                # 调用价格监控脚本显示最新状态
                echo -e "\n${BLUE}=== 出售后价格监控 ===${NC}"
                if [[ -f "./scripts/price_monitor.sh" ]]; then
                    ./scripts/price_monitor.sh --contract "$AMM_ADDRESS" --rpc-url "$RPC_URL"
                else
                    echo "价格监控脚本不存在"
                fi
            else
                echo -e "${RED}❌ NFT 出售失败: $sell_tx${NC}"
            fi
        else
            echo -e "${RED}❌ NFT 购买失败: $buy_tx${NC}"
        fi
    fi
    
    wait_for_user
}

# 演示池子管理
demo_pool_management() {
    echo -e "${GREEN}=== 步骤 6: 池子管理演示 ===${NC}"
    
    echo "池子管理功能演示..."
    echo "当前 AMM 池子信息:"
    
    if [[ -n "$AMM_ADDRESS" ]]; then
        # 查询池子状态
        is_paused=$(cast call "$AMM_ADDRESS" "paused()" --rpc-url "$RPC_URL" 2>/dev/null || echo "false")
        echo "池子状态: $([ "$is_paused" = "true" ] && echo "已暂停" || echo "正常运行")"
        
        # 查询所有者
        owner=$(cast call "$AMM_ADDRESS" "owner()" --rpc-url "$RPC_URL" 2>/dev/null || echo "未知")
        echo "池子所有者: $owner"
        
        # 查询 LP Token 信息
        lp_token=$(cast call "$AMM_ADDRESS" "lpToken()" --rpc-url "$RPC_URL" 2>/dev/null || echo "未知")
        echo "LP Token 合约: $lp_token"
        
        if [[ "$lp_token" != "未知" && "$lp_token" != "0x0000000000000000000000000000000000000000" ]]; then
            total_supply=$(cast call "$lp_token" "totalSupply()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
            echo "LP Token 总供应量: $total_supply"
        fi
        
        # 显示累计收益
        accumulated_fees=$(cast call "$AMM_ADDRESS" "accumulatedFees()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
        accumulated_fees_eth=$(cast from-wei "$accumulated_fees" 2>/dev/null || echo "0")
        echo "累计收益: $accumulated_fees_eth ETH"
    else
        echo "错误: 未找到 AMM 合约地址"
    fi
    
    wait_for_user
}

# 清理资源
cleanup() {
    echo -e "${YELLOW}清理资源...${NC}"
    
    if [[ -n "$ANVIL_PID" ]]; then
        echo "停止 Anvil 节点..."
        kill "$ANVIL_PID" 2>/dev/null || true
    fi
    
    # 清理日志文件
    rm -f anvil.log deploy.log
    
    echo -e "${GREEN}清理完成!${NC}"
}

# 显示 LP Token 信息（仅在添加或移除流动性后调用）
show_lp_token_info() {
    local amm_address="$1"
    local rpc_url="$2"
    
    echo ""
    echo -e "${BLUE}=== LP Token 信息 ===${NC}"
    
    # 获取 LP Token 信息
    local lp_token_raw=$(cast call "$amm_address" "lpToken()" --rpc-url "$rpc_url" 2>/dev/null || echo "0x0000000000000000000000000000000000000000")
    local lp_token_address="0x$(echo "$lp_token_raw" | sed 's/0x000000000000000000000000//')"
    
    if [[ "$lp_token_address" != "0x" && "$lp_token_address" != "0x0000000000000000000000000000000000000000" ]]; then
        local lp_total_supply=$(cast call "$lp_token_address" "totalSupply()" --rpc-url "$rpc_url" 2>/dev/null || echo "0")
        local lp_decimals=$(cast call "$lp_token_address" "decimals()" --rpc-url "$rpc_url" 2>/dev/null || echo "18")
        
        # 获取做市者地址和余额
        local owner_address_raw=$(cast call "$amm_address" "owner()" --rpc-url "$rpc_url" 2>/dev/null || echo "0x0000000000000000000000000000000000000000")
        local owner_address="0x$(echo "$owner_address_raw" | sed 's/0x000000000000000000000000//')"
        
        if [[ "$owner_address" != "0x" && "$owner_address" != "0x0000000000000000000000000000000000000000" ]]; then
            local lp_owner_balance=$(cast call "$lp_token_address" "balanceOf(address)" "$owner_address" --rpc-url "$rpc_url" 2>/dev/null || echo "0")
            
            # 转换为十进制
            local lp_total_supply_dec=$(cast to-dec "$lp_total_supply" 2>/dev/null || echo "0")
            local lp_owner_balance_dec=$(cast to-dec "$lp_owner_balance" 2>/dev/null || echo "0")
            local lp_decimals_dec=$(cast to-dec "$lp_decimals" 2>/dev/null || echo "18")
            
            echo "LP Token 地址: $lp_token_address"
            echo "做市者地址: $owner_address"
            echo "LP Token 总供应量: $lp_total_supply_dec"
            echo "做市者持有: $lp_owner_balance_dec"
            
            if command -v bc &> /dev/null && [[ "$lp_total_supply_dec" -gt 0 ]]; then
                # 计算做市者持有的比例
                local ownership_percentage=$(echo "scale=2; $lp_owner_balance_dec * 100 / $lp_total_supply_dec" | bc 2>/dev/null || echo "0")
                echo "做市者持有比例: $ownership_percentage%"
            fi
        else
            echo "无法获取做市者地址"
        fi
    else
        echo "LP Token 未部署或不可用"
    fi
}

# 显示总结
show_summary() {
    echo -e "${GREEN}=== 演示总结 ===${NC}"
    echo ""
    echo "本次演示展示了以下功能:"
    echo "✅ 启动本地 Anvil 节点"
    echo "✅ 部署 NFT 和 AMM 合约"
    echo "✅ 查询合约信息"
    echo "✅ 价格监控功能"
    echo "✅ 交易查询功能"
    echo ""
    echo "部署的合约:"
    if [[ -n "$DEPLOYED_CONTRACTS" ]]; then
        echo "$DEPLOYED_CONTRACTS"
    else
        echo "无"
    fi
    
}

# 信号处理
trap cleanup EXIT INT TERM

# 主函数
main() {
    show_title
    check_dependencies
    wait_for_user
    
    start_anvil
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
