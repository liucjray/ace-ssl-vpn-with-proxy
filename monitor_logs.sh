#!/bin/bash

# VPN Proxy 实时日志监控工具
# 用于监控代理服务的访问日志

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

CONTAINER_NAME="sslvpn-proxy-1"

# 显示菜单
show_menu() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        VPN Proxy 日志监控工具                          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}请选择监控模式：${NC}"
    echo
    echo -e "  ${GREEN}1${NC}) 实时监控所有流量（彩色输出）"
    echo -e "  ${GREEN}2${NC}) 只监控 HTTP 代理请求"
    echo -e "  ${GREEN}3${NC}) 只监控 SOCKS5 代理请求"
    echo -e "  ${GREEN}4${NC}) 监控 VPN 隧道流量"
    echo -e "  ${GREEN}5${NC}) 查看访问统计"
    echo -e "  ${GREEN}6${NC}) 实时监控（简洁模式）"
    echo -e "  ${GREEN}7${NC}) 查看最近 50 条日志"
    echo -e "  ${GREEN}8${NC}) 搜索特定 IP 的访问记录"
    echo -e "  ${GREEN}9${NC}) 导出日志到文件"
    echo -e "  ${RED}0${NC}) 退出"
    echo
    echo -n -e "${YELLOW}请输入选项 [0-9]: ${NC}"
}

# 检查容器是否运行
check_container() {
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        echo -e "${RED}错误: 容器 $CONTAINER_NAME 未运行${NC}"
        echo "请先启动容器: docker compose up -d"
        exit 1
    fi
}

# 1. 实时监控所有流量（彩色）
monitor_all_colorized() {
    echo -e "${CYAN}开始实时监控所有流量...${NC}"
    echo -e "${YELLOW}提示: 按 Ctrl+C 停止监控${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    docker logs -f "$CONTAINER_NAME" 2>&1 | while read line; do
        # 高亮不同类型的日志
        if echo "$line" | grep -q "socks5"; then
            echo -e "${MAGENTA}[SOCKS5]${NC} $line"
        elif echo "$line" | grep -q "http"; then
            echo -e "${GREEN}[HTTP]${NC} $line"
        elif echo "$line" | grep -q "VPN"; then
            echo -e "${BLUE}[VPN]${NC} $line"
        elif echo "$line" | grep -qi "error\|fail"; then
            echo -e "${RED}[ERROR]${NC} $line"
        else
            echo "$line"
        fi
    done
}

# 2. 只监控 HTTP 请求
monitor_http() {
    echo -e "${GREEN}监控 HTTP/HTTPS 代理请求...${NC}"
    echo -e "${YELLOW}提示: 按 Ctrl+C 停止监控${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    docker exec "$CONTAINER_NAME" tail -f /var/log/gost.log 2>/dev/null | grep --line-buffered -i "http" | while read line; do
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${GREEN}[$timestamp]${NC} $line"
    done
}

# 3. 只监控 SOCKS5 请求
monitor_socks5() {
    echo -e "${MAGENTA}监控 SOCKS5 代理请求...${NC}"
    echo -e "${YELLOW}提示: 按 Ctrl+C 停止监控${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    docker exec "$CONTAINER_NAME" tail -f /var/log/gost.log 2>/dev/null | grep --line-buffered -i "socks" | while read line; do
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')

        # 解析源 IP 和目标地址
        if echo "$line" | grep -q "->"; then
            source=$(echo "$line" | grep -oP '\d+\.\d+\.\d+\.\d+:\d+' | head -1)
            target=$(echo "$line" | grep -oP '\d+\.\d+\.\d+\.\d+:\d+' | tail -1)
            echo -e "${CYAN}[$timestamp]${NC} ${YELLOW}$source${NC} → ${GREEN}$target${NC}"
        else
            echo -e "${CYAN}[$timestamp]${NC} $line"
        fi
    done
}

# 4. 监控 VPN 隧道
monitor_vpn() {
    echo -e "${BLUE}监控 VPN 隧道流量...${NC}"
    echo -e "${YELLOW}提示: 按 Ctrl+C 停止监控${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    docker logs -f "$CONTAINER_NAME" 2>&1 | grep --line-buffered -iE "vpn|ppp0|tunnel|gateway"
}

# 5. 查看访问统计
show_statistics() {
    echo -e "${CYAN}正在生成访问统计...${NC}"
    echo

    # 获取完整日志
    LOGFILE=$(mktemp)
    docker exec "$CONTAINER_NAME" cat /var/log/gost.log 2>/dev/null > "$LOGFILE"

    # 统计总请求数
    total_requests=$(grep -c "route.go" "$LOGFILE" 2>/dev/null || echo 0)
    http_requests=$(grep -c "\[http\]" "$LOGFILE" 2>/dev/null || echo 0)
    socks_requests=$(grep -c "socks5" "$LOGFILE" 2>/dev/null || echo 0)

    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}总请求数:${NC}        $total_requests"
    echo -e "${YELLOW}HTTP 请求:${NC}       $http_requests"
    echo -e "${YELLOW}SOCKS5 请求:${NC}     $socks_requests"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    # 统计访问最多的目标
    echo -e "${CYAN}访问最多的目标 IP (Top 10):${NC}"
    grep -oP '\d+\.\d+\.\d+\.\d+:\d+' "$LOGFILE" 2>/dev/null | \
        grep -v "10.73.0" | \
        sort | uniq -c | sort -rn | head -10 | \
        awk '{printf "  %-6s %s\n", $1, $2}'
    echo

    # 统计来源 IP
    echo -e "${CYAN}访问来源 IP:${NC}"
    grep -oP '10\.73\.0\.\d+:\d+' "$LOGFILE" 2>/dev/null | \
        cut -d: -f1 | sort | uniq -c | sort -rn | \
        awk '{printf "  %-6s %s\n", $1, $2}'
    echo

    rm -f "$LOGFILE"

    echo -e "${YELLOW}按任意键返回菜单...${NC}"
    read -n 1
}

# 6. 实时监控（简洁模式）
monitor_simple() {
    echo -e "${CYAN}实时监控（简洁模式）...${NC}"
    echo -e "${YELLOW}提示: 按 Ctrl+C 停止监控${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "%-20s %-25s → %-25s\n" "时间" "来源" "目标"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    docker exec "$CONTAINER_NAME" tail -f /var/log/gost.log 2>/dev/null | \
        grep --line-buffered "\->" | \
        while read line; do
            timestamp=$(date '+%H:%M:%S')
            source=$(echo "$line" | grep -oP '\d+\.\d+\.\d+\.\d+:\d+' | head -1)
            target=$(echo "$line" | grep -oP '\d+\.\d+\.\d+\.\d+:\d+' | tail -1)

            # 标记内网地址
            if echo "$target" | grep -qE "192\.168\.|10\.0\."; then
                target="${GREEN}${target}${NC} [内网]"
            fi

            printf "%-20s %-25s → %s\n" "$timestamp" "$source" "$target"
        done
}

# 7. 查看最近日志
show_recent_logs() {
    echo -e "${CYAN}最近 50 条日志:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    docker exec "$CONTAINER_NAME" tail -50 /var/log/gost.log 2>/dev/null | while read line; do
        if echo "$line" | grep -q "socks5"; then
            echo -e "${MAGENTA}$line${NC}"
        elif echo "$line" | grep -qi "error"; then
            echo -e "${RED}$line${NC}"
        else
            echo "$line"
        fi
    done
    echo
    echo -e "${YELLOW}按任意键返回菜单...${NC}"
    read -n 1
}

# 8. 搜索特定 IP
search_ip() {
    echo -n -e "${YELLOW}请输入要搜索的 IP 地址: ${NC}"
    read search_ip

    echo -e "${CYAN}搜索 IP: $search_ip${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    docker exec "$CONTAINER_NAME" grep "$search_ip" /var/log/gost.log 2>/dev/null | tail -30 | while read line; do
        echo -e "${GREEN}$line${NC}"
    done

    echo
    echo -e "${YELLOW}按任意键返回菜单...${NC}"
    read -n 1
}

# 9. 导出日志
export_logs() {
    timestamp=$(date '+%Y%m%d_%H%M%S')
    output_file="gost_logs_${timestamp}.txt"

    echo -e "${CYAN}正在导出日志...${NC}"
    docker exec "$CONTAINER_NAME" cat /var/log/gost.log 2>/dev/null > "$output_file"

    if [ -f "$output_file" ]; then
        lines=$(wc -l < "$output_file")
        size=$(du -h "$output_file" | cut -f1)
        echo -e "${GREEN}✓ 日志已导出到: $output_file${NC}"
        echo -e "${YELLOW}  行数: $lines, 大小: $size${NC}"
    else
        echo -e "${RED}✗ 导出失败${NC}"
    fi

    echo
    echo -e "${YELLOW}按任意键返回菜单...${NC}"
    read -n 1
}

# 主程序
main() {
    check_container

    while true; do
        show_menu
        read -r choice

        case $choice in
            1) monitor_all_colorized ;;
            2) monitor_http ;;
            3) monitor_socks5 ;;
            4) monitor_vpn ;;
            5) show_statistics ;;
            6) monitor_simple ;;
            7) show_recent_logs ;;
            8) search_ip ;;
            9) export_logs ;;
            0) echo -e "${GREEN}再见！${NC}"; exit 0 ;;
            *) echo -e "${RED}无效选项，请重试${NC}"; sleep 2 ;;
        esac
    done
}

main
