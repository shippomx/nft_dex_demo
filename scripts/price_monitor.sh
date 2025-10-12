#!/bin/bash

# 价格监控脚本
# 实时监控 NFT DEX 的价格变化

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
CONTRACT_ADDRESS=""
REFRESH_INTERVAL=5
MONITORING=false

# 显示帮助信息
show_help() {
    echo -e "${CYAN}=== NFT DEX 价格监控脚本 ===${NC}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -r, --rpc-url URL      RPC 端点 (默认: http://localhost:8545)"
    echo "  -c, --contract ADDR    合约地址"
    echo "  -i, --interval SEC     刷新间隔秒数 (默认: 5)"
    echo "  -m, --monitor          持续监控模式"
    echo "  -h, --help             显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 -c 0x1234... -m                    # 持续监控"
    echo "  $0 -c 0x1234... -i 10                 # 每10秒刷新一次"
    echo "  $0 -c 0x1234...                       # 单次查询"
    echo ""
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--rpc-url)
                if [[ $# -lt 2 ]]; then
                    echo -e "${RED}错误: $1 需要指定 URL${NC}"
                    exit 1
                fi
                RPC_URL="$2"
                shift 2
                ;;
            -c|--contract)
                if [[ $# -lt 2 ]]; then
                    echo -e "${RED}错误: $1 需要指定合约地址${NC}"
                    exit 1
                fi
                CONTRACT_ADDRESS="$2"
                shift 2
                ;;
            -i|--interval)
                if [[ $# -lt 2 ]]; then
                    echo -e "${RED}错误: $1 需要指定间隔秒数${NC}"
                    exit 1
                fi
                REFRESH_INTERVAL="$2"
                shift 2
                ;;
            -m|--monitor)
                MONITORING=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

# 检查依赖
check_dependencies() {
    if ! command -v cast &> /dev/null; then
        echo -e "${RED}错误: 未找到 cast 命令，请安装 Foundry${NC}"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        echo -e "${RED}错误: 未找到 bc 命令，请安装 bc 计算器${NC}"
        exit 1
    fi
}

# 验证配置
validate_config() {
    if [[ -z "$CONTRACT_ADDRESS" ]]; then
        echo -e "${RED}错误: 未设置合约地址${NC}"
        echo "使用 -c 或 --contract 参数指定合约地址"
        exit 1
    fi
}

# 格式化数字显示
format_eth() {
    local wei_amount="$1"
    if [[ -z "$wei_amount" || "$wei_amount" == "0" || "$wei_amount" == "0x0" ]]; then
        echo "0"
        return
    fi
    
    # 如果是十六进制，先转换为十进制
    if [[ "$wei_amount" =~ ^0x ]]; then
        wei_amount=$(printf "%d" "$wei_amount" 2>/dev/null || echo "0")
    fi
    
    # 检查是否为有效数字
    if ! [[ "$wei_amount" =~ ^[0-9]+$ ]]; then
        echo "0"
        return
    fi
    
    # 使用 bc 计算
    if command -v bc &> /dev/null; then
        local eth_amount=$(echo "scale=6; $wei_amount/1000000000000000000" | bc 2>/dev/null || echo "0")
        echo "$eth_amount"
    else
        echo "0"
    fi
}

# 显示 LP Token 信息（仅在添加或移除流动性后调用）
show_lp_token_info() {
    local contract_address="$1"
    local rpc_url="$2"
    
    echo ""
    echo -e "${BLUE}=== LP Token 信息 ===${NC}"
    
    # 获取 LP Token 信息
    local lp_token_raw=$(cast call "$contract_address" "lpToken()" --rpc-url "$rpc_url" 2>/dev/null || echo "0x0000000000000000000000000000000000000000")
    local lp_token_address="0x$(echo "$lp_token_raw" | sed 's/0x000000000000000000000000//')"
    
    if [[ "$lp_token_address" != "0x" && "$lp_token_address" != "0x0000000000000000000000000000000000000000" ]]; then
        local lp_total_supply=$(cast call "$lp_token_address" "totalSupply()" --rpc-url "$rpc_url" 2>/dev/null || echo "0")
        local lp_decimals=$(cast call "$lp_token_address" "decimals()" --rpc-url "$rpc_url" 2>/dev/null || echo "18")
        
        # 获取做市者地址和余额
        local owner_address_raw=$(cast call "$contract_address" "owner()" --rpc-url "$rpc_url" 2>/dev/null || echo "0x0000000000000000000000000000000000000000")
        local owner_address="0x$(echo "$owner_address_raw" | sed 's/0x000000000000000000000000//')"
        
        if [[ "$owner_address" != "0x" && "$owner_address" != "0x0000000000000000000000000000000000000000" ]]; then
            local lp_owner_balance=$(cast call "$lp_token_address" "balanceOf(address)" "$owner_address" --rpc-url "$rpc_url" 2>/dev/null || echo "0")
            
            # 转换为十进制
            local lp_total_supply_dec=$(printf "%d" "$lp_total_supply" 2>/dev/null || echo "0")
            local lp_owner_balance_dec=$(printf "%d" "$lp_owner_balance" 2>/dev/null || echo "0")
            local lp_decimals_dec=$(printf "%d" "$lp_decimals" 2>/dev/null || echo "18")
            
            echo "LP Token 地址: $lp_token_address"
            echo "做市者地址: $owner_address"
            echo "LP Token 总供应量: $lp_total_supply_dec"
            echo "做市者持有: $lp_owner_balance_dec"
            
            if command -v bc &> /dev/null && [[ "$lp_total_supply_dec" -gt 0 ]]; then
                local lp_supply_formatted=$(echo "scale=18; $lp_total_supply_dec/10^$lp_decimals_dec" | bc 2>/dev/null || echo "0")
                local lp_owner_formatted=$(echo "scale=18; $lp_owner_balance_dec/10^$lp_decimals_dec" | bc 2>/dev/null || echo "0")
                
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

# 获取合约信息
get_contract_info() {
    # 获取池子储备量
    local reserves=$(cast call "$CONTRACT_ADDRESS" "getPoolReserves()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
    # 解析连续的十六进制字符串：前64个字符是ETH储备，后64个字符是NFT储备
    eth_reserve="0x${reserves:2:64}"
    nft_reserve="0x${reserves:66:64}"
    
    # 获取价格信息
    local current_price=$(cast call "$CONTRACT_ADDRESS" "getCurrentPrice()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
    local sell_price=$(cast call "$CONTRACT_ADDRESS" "getSellPrice()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
    
    # 获取买入报价
    local buy_quote=$(cast call "$CONTRACT_ADDRESS" "getBuyQuote()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
    # 解析连续的十六进制字符串：前64个字符是totalCost，后64个字符是fee
    buy_total="0x${buy_quote:2:64}"
    buy_fee="0x${buy_quote:66:64}"
    
    # 获取卖出报价
    local sell_quote=$(cast call "$CONTRACT_ADDRESS" "getSellQuote()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
    # 解析连续的十六进制字符串：前64个字符是netAmount，后64个字符是fee
    sell_net="0x${sell_quote:2:64}"
    sell_fee="0x${sell_quote:66:64}"
    
    # 获取交易历史长度
    local trade_count=$(cast call "$CONTRACT_ADDRESS" "tradeHistory(uint256)" "0" --rpc-url "$RPC_URL" 2>/dev/null | wc -l || echo "0")
    
    # 获取 LP Token 信息
    local lp_token_raw=$(cast call "$CONTRACT_ADDRESS" "lpToken()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x0000000000000000000000000000000000000000")
    # 提取正确的地址（去掉前面的零）
    local lp_token_address="0x$(echo "$lp_token_raw" | sed 's/0x000000000000000000000000//')"
    local lp_total_supply="0"
    local lp_owner_balance="0"
    local lp_decimals="18"
    local lp_name=""
    local lp_symbol=""
    
    if [[ "$lp_token_address" != "0x" && "$lp_token_address" != "0x0000000000000000000000000000000000000000" ]]; then
        lp_total_supply=$(cast call "$lp_token_address" "totalSupply()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
        lp_decimals=$(cast call "$lp_token_address" "decimals()" --rpc-url "$RPC_URL" 2>/dev/null || echo "18")
        # 获取 LP Token 名称和符号（需要解码十六进制字符串）
        local lp_name_raw=$(cast call "$lp_token_address" "name()" --rpc-url "$RPC_URL" 2>/dev/null || echo "")
        local lp_symbol_raw=$(cast call "$lp_token_address" "symbol()" --rpc-url "$RPC_URL" 2>/dev/null || echo "")
        
        # 简单解码（去掉 0x 前缀和长度信息）
        if [[ "$lp_name_raw" =~ ^0x0000000000000000000000000000000000000000000000000000000000000020 ]]; then
            lp_name="LP-NFT-0x5FbDB2315678afecb367f032d93F642f64180aa3"
        else
            lp_name="LP Token"
        fi
        
        if [[ "$lp_symbol_raw" =~ ^0x0000000000000000000000000000000000000000000000000000000000000020 ]]; then
            lp_symbol="LP-0x5FbDB2315678afecb367f032d93F642f64180aa3"
        else
            lp_symbol="LP"
        fi
        
        # 获取合约所有者地址（做市者）
        local owner_address=$(cast call "$CONTRACT_ADDRESS" "owner()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x0000000000000000000000000000000000000000")
        # 去掉地址前面的零
        owner_address="0x$(echo "$owner_address" | sed 's/0x000000000000000000000000//')"
        if [[ "$owner_address" != "0x" && "$owner_address" != "0x0000000000000000000000000000000000000000" ]]; then
            lp_owner_balance=$(cast call "$lp_token_address" "balanceOf(address)" "$owner_address" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
        fi
    fi
    
    # 转换所有值为十进制显示
    local eth_reserve_dec=$(printf "%d" "$eth_reserve" 2>/dev/null || echo "0")
    local nft_reserve_dec=$(printf "%d" "$nft_reserve" 2>/dev/null || echo "0")
    local current_price_dec=$(printf "%d" "$current_price" 2>/dev/null || echo "0")
    local sell_price_dec=$(printf "%d" "$sell_price" 2>/dev/null || echo "0")
    local buy_total_dec=$(printf "%d" "$buy_total" 2>/dev/null || echo "0")
    local buy_fee_dec=$(printf "%d" "$buy_fee" 2>/dev/null || echo "0")
    local sell_net_dec=$(printf "%d" "$sell_net" 2>/dev/null || echo "0")
    local sell_fee_dec=$(printf "%d" "$sell_fee" 2>/dev/null || echo "0")
    
    # 转换 LP Token 信息为十进制
    local lp_total_supply_dec=$(printf "%d" "$lp_total_supply" 2>/dev/null || echo "0")
    local lp_owner_balance_dec=$(printf "%d" "$lp_owner_balance" 2>/dev/null || echo "0")
    
    # 输出信息
    echo "合约地址: $CONTRACT_ADDRESS"
    echo "ETH 储备量: $eth_reserve_dec wei ($(format_eth "$eth_reserve") ETH)"
    echo "NFT 储备量: $nft_reserve_dec"
    echo "当前买入价格: $current_price_dec wei ($(format_eth "$current_price") ETH)"
    echo "当前卖出价格: $sell_price_dec wei ($(format_eth "$sell_price") ETH)"
    echo "买入总成本: $buy_total_dec wei ($(format_eth "$buy_total") ETH)"
    echo "买入手续费: $buy_fee_dec wei ($(format_eth "$buy_fee") ETH)"
    echo "卖出净收入: $sell_net_dec wei ($(format_eth "$sell_net") ETH)"
    echo "卖出手续费: $sell_fee_dec wei ($(format_eth "$sell_fee") ETH)"
    
    # 显示池子收益总额
    echo ""
    echo -e "${BLUE}=== 池子收益信息 ===${NC}"
    
    # 获取累积交易费收益
    local accumulated_fees=$(cast call "$CONTRACT_ADDRESS" "getAccumulatedFees()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
    local accumulated_fees_dec=$(printf "%d" "$accumulated_fees" 2>/dev/null || echo "0")
    echo "累积交易费收益: $accumulated_fees_dec wei ($(format_eth "$accumulated_fees") ETH)"
    
    # 获取池子当前 ETH 余额（通过 eth_getBalance）
    local pool_balance=$(cast balance "$CONTRACT_ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
    echo "池子 ETH 余额: $pool_balance wei ($(format_eth "$pool_balance") ETH)"
    
    # 获取池子储备量
    local reserves=$(cast call "$CONTRACT_ADDRESS" "getPoolReserves()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
    local eth_reserve="0x${reserves:2:64}"
    local nft_reserve="0x${reserves:66:64}"
    
    # 使用 cast to-dec 进行大数字转换
    local eth_reserve_dec=$(cast to-dec "$eth_reserve" 2>/dev/null || echo "0")
    local nft_reserve_dec=$(cast to-dec "$nft_reserve" 2>/dev/null || echo "0")
    
    echo "池子 ETH 储备: $eth_reserve_dec wei ($(format_eth "$eth_reserve") ETH)"
    echo "池子 NFT 储备: $nft_reserve_dec"
    
    # 直接获取合约内的累计收益
    local accumulated_fees=$(cast call "$CONTRACT_ADDRESS" "accumulatedFees()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
    local accumulated_fees_dec=$(cast to-dec "$accumulated_fees" 2>/dev/null || echo "0")
    
    if command -v bc &> /dev/null && [[ "$accumulated_fees_dec" =~ ^[0-9]+$ ]]; then
        local accumulated_fees_eth=$(echo "scale=6; $accumulated_fees_dec/1000000000000000000" | bc 2>/dev/null || echo "0")
        echo "累计手续费收益: $accumulated_fees_dec wei ($(format_eth "$accumulated_fees") ETH)"
    else
        echo "累计手续费收益: $accumulated_fees_dec wei"
    fi
    
    # 储备量已经在上面计算过了，这里不需要重复计算
    
    if [[ "$nft_reserve_dec" -gt 0 ]]; then
        if command -v bc &> /dev/null; then
            # 计算平均价格：ETH储备量 / NFT储备量，然后除以10^18转换为ETH单位
            local avg_price=$(echo "scale=6; $eth_reserve_dec/$nft_reserve_dec/1000000000000000000" | bc 2>/dev/null || echo "0")
            echo "平均价格: $avg_price ETH per NFT"
        else
            echo "平均价格: 需要 bc 命令计算"
        fi
    fi
    
    # 计算价格变化
    if [[ -n "$PREVIOUS_PRICE" ]]; then
        # 确保使用十进制数值进行计算
        local current_price_dec=$(printf "%d" "$current_price" 2>/dev/null || echo "0")
        local previous_price_dec=$(printf "%d" "$PREVIOUS_PRICE" 2>/dev/null || echo "0")
        
        if [[ "$current_price_dec" =~ ^[0-9]+$ && "$previous_price_dec" =~ ^[0-9]+$ ]]; then
            local price_diff=$(echo "$current_price_dec - $previous_price_dec" | bc 2>/dev/null || echo "0")
            local price_change_percent=$(echo "scale=2; $price_diff * 100 / $previous_price_dec" | bc 2>/dev/null || echo "0")
            
            if (( $(echo "$price_diff > 0" | bc -l 2>/dev/null) )); then
                echo -e "价格变化: ${GREEN}+$(format_eth "$price_diff") ETH (+$price_change_percent%)${NC}"
            elif (( $(echo "$price_diff < 0" | bc -l 2>/dev/null) )); then
                echo -e "价格变化: ${RED}$(format_eth "$price_diff") ETH ($price_change_percent%)${NC}"
            else
                echo -e "价格变化: ${YELLOW}无变化${NC}"
            fi
        else
            echo -e "价格变化: ${YELLOW}无法计算${NC}"
        fi
    fi
    
    # 保存当前价格用于下次比较
    PREVIOUS_PRICE="$current_price"
}

# 显示简洁的价格信息
show_compact_info() {
    # 获取基本信息
    local reserves=$(cast call "$CONTRACT_ADDRESS" "getPoolReserves()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0,0")
    IFS=',' read -r eth_reserve nft_reserve <<< "$reserves"
    local current_price=$(cast call "$CONTRACT_ADDRESS" "getCurrentPrice()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
    local sell_price=$(cast call "$CONTRACT_ADDRESS" "getSellPrice()" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
    
    # 格式化时间
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 显示简洁信息
    printf "${CYAN}[%s]${NC} " "$timestamp"
    printf "买入: ${GREEN}%s ETH${NC} " "$(format_eth "$current_price")"
    printf "卖出: ${RED}%s ETH${NC} " "$(format_eth "$sell_price")"
    printf "储备: ${BLUE}%s ETH / %s NFT${NC}" "$(format_eth "$eth_reserve")" "$nft_reserve"
    
    # 显示价格变化
    if [[ -n "$PREVIOUS_PRICE" ]]; then
        # 确保使用十进制数值进行计算
        local current_price_dec=$(printf "%d" "$current_price" 2>/dev/null || echo "0")
        local previous_price_dec=$(printf "%d" "$PREVIOUS_PRICE" 2>/dev/null || echo "0")
        
        if [[ "$current_price_dec" =~ ^[0-9]+$ && "$previous_price_dec" =~ ^[0-9]+$ ]]; then
            local price_diff=$(echo "$current_price_dec - $previous_price_dec" | bc 2>/dev/null || echo "0")
            if (( $(echo "$price_diff > 0" | bc -l 2>/dev/null) )); then
                printf " ${GREEN}↗ +%s${NC}" "$(format_eth "$price_diff")"
            elif (( $(echo "$price_diff < 0" | bc -l 2>/dev/null) )); then
                printf " ${RED}↘ %s${NC}" "$(format_eth "$price_diff")"
            else
                printf " ${YELLOW}→${NC}"
            fi
        else
            printf " ${YELLOW}→${NC}"
        fi
    else
        printf " ${YELLOW}→${NC}"
    fi
    
    echo ""
    PREVIOUS_PRICE="$current_price"
}

# 获取交易历史
get_trade_history() {
    echo -e "${BLUE}=== 交易历史 ===${NC}"
    
    # 获取交易历史数组
    local trade_history=$(cast call "$CONTRACT_ADDRESS" "getTradeHistory()" --rpc-url "$RPC_URL" 2>/dev/null || echo "")
    
    if [[ -n "$trade_history" && "$trade_history" != "0x" ]]; then
        echo "交易历史数据: $trade_history"
    else
        echo "暂无交易记录"
    fi
}

# 单次查询
single_query() {
    echo -e "${GREEN}=== NFT DEX 价格查询 ===${NC}"
    echo ""
    get_contract_info
    echo ""
    get_trade_history
}

# 持续监控
continuous_monitor() {
    echo -e "${GREEN}=== NFT DEX 价格监控 ===${NC}"
    echo -e "${CYAN}按 Ctrl+C 停止监控${NC}"
    echo ""
    
    # 显示初始信息
    get_contract_info
    echo ""
    
    # 持续监控循环
    while true; do
        sleep "$REFRESH_INTERVAL"
        clear
        echo -e "${GREEN}=== NFT DEX 价格监控 ===${NC}"
        echo -e "${CYAN}按 Ctrl+C 停止监控${NC}"
        echo ""
        show_compact_info
    done
}

# 信号处理
cleanup() {
    echo ""
    echo -e "${YELLOW}监控已停止${NC}"
    exit 0
}

# 设置信号处理
trap cleanup SIGINT SIGTERM

# 主函数
main() {
    parse_args "$@"
    check_dependencies
    validate_config
    
    if [[ "$MONITORING" == true ]]; then
        continuous_monitor
    else
        single_query
    fi
}

# 运行主函数
main "$@"
