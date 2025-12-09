#!/bin/bash

# VPN Proxy 远程测试脚本
# 在另一台电脑上运行此脚本来测试代理和内网访问

# ============ 配置区 ============
PROXY_SERVER="YOUR_SERVER_IP"  # 替换为你的服务器公网 IP
PROXY_USER="admin"
PROXY_PASS="changeme123"       # 替换为你设置的密码
HTTP_PORT="8080"
SOCKS_PORT="1080"

# 内网测试目标
INTERNAL_IPS=(
    "192.168.103.10"
    "192.168.100.1"
    "192.168.101.1"
    "192.168.102.1"
)

# ============ 颜色定义 ============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============ 函数定义 ============
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# ============ 检查依赖 ============
check_dependencies() {
    print_header "检查依赖工具"

    local deps=("curl" "nc")
    local missing=()

    for dep in "${deps[@]}"; do
        if command -v $dep &> /dev/null; then
            print_success "$dep 已安装"
        else
            print_error "$dep 未安装"
            missing+=($dep)
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        print_warning "请安装缺失的工具："
        echo "  Ubuntu/Debian: sudo apt install ${missing[*]}"
        echo "  CentOS/RHEL:   sudo yum install ${missing[*]}"
        echo "  macOS:         brew install ${missing[*]}"
        exit 1
    fi
    echo
}

# ============ 测试外网连接 ============
test_internet() {
    print_header "测试代理基本功能（访问外网）"

    echo "测试 HTTP 代理..."
    if IP=$(curl -x http://${PROXY_USER}:${PROXY_PASS}@${PROXY_SERVER}:${HTTP_PORT} \
           -s --connect-timeout 10 https://ipinfo.io/ip 2>/dev/null); then
        print_success "HTTP 代理可用 - 出口 IP: ${IP}"
    else
        print_error "HTTP 代理连接失败"
        return 1
    fi

    echo "测试 SOCKS5 代理..."
    if IP=$(curl --socks5 ${PROXY_USER}:${PROXY_PASS}@${PROXY_SERVER}:${SOCKS_PORT} \
           -s --connect-timeout 10 https://ipinfo.io/ip 2>/dev/null); then
        print_success "SOCKS5 代理可用 - 出口 IP: ${IP}"
    else
        print_error "SOCKS5 代理连接失败"
        return 1
    fi

    echo
}

# ============ 测试内网 HTTP 访问 ============
test_internal_http() {
    print_header "测试内网 HTTP 访问（通过 HTTP 代理）"

    for ip in "${INTERNAL_IPS[@]}"; do
        echo -n "测试 http://${ip} ... "

        # 尝试访问 HTTP (端口 80)
        response=$(curl -x http://${PROXY_USER}:${PROXY_PASS}@${PROXY_SERVER}:${HTTP_PORT} \
                   -s -o /dev/null -w "%{http_code}" \
                   --connect-timeout 5 --max-time 10 \
                   http://${ip} 2>/dev/null)

        if [ "$response" != "000" ] && [ ! -z "$response" ]; then
            print_success "HTTP $response"
        else
            print_error "无响应或超时"
        fi
    done
    echo
}

# ============ 测试内网端口连通性 ============
test_internal_ports() {
    print_header "测试内网常用端口（通过 SOCKS5）"

    local ports=(22 80 443 3389 8080)

    for ip in "${INTERNAL_IPS[@]}"; do
        echo "测试 ${ip}:"
        for port in "${ports[@]}"; do
            echo -n "  端口 ${port} ... "

            # 使用 curl 通过 SOCKS5 测试端口
            if timeout 3 curl --socks5 ${PROXY_USER}:${PROXY_PASS}@${PROXY_SERVER}:${SOCKS_PORT} \
               -s --connect-timeout 3 \
               telnet://${ip}:${port} &>/dev/null; then
                print_success "开放"
            else
                echo -e "${RED}关闭/超时${NC}"
            fi
        done
        echo
    done
}

# ============ 生成配置示例 ============
show_config_examples() {
    print_header "客户端配置示例"

    echo -e "${YELLOW}【浏览器配置 - Firefox】${NC}"
    echo "  1. 设置 → 网络设置 → 手动代理配置"
    echo "  2. SOCKS Host: ${PROXY_SERVER}"
    echo "  3. Port: ${SOCKS_PORT}"
    echo "  4. SOCKS v5，勾选「远程 DNS」"
    echo "  5. 用户名: ${PROXY_USER}, 密码: ${PROXY_PASS}"
    echo

    echo -e "${YELLOW}【命令行 - curl】${NC}"
    echo "  # HTTP 代理"
    echo "  curl -x http://${PROXY_USER}:${PROXY_PASS}@${PROXY_SERVER}:${HTTP_PORT} http://192.168.103.10"
    echo
    echo "  # SOCKS5 代理"
    echo "  curl --socks5 ${PROXY_USER}:${PROXY_PASS}@${PROXY_SERVER}:${SOCKS_PORT} http://192.168.103.10"
    echo

    echo -e "${YELLOW}【proxychains 配置】${NC}"
    echo "  编辑 /etc/proxychains4.conf，添加："
    echo "  socks5  ${PROXY_SERVER}  ${SOCKS_PORT}  ${PROXY_USER}  ${PROXY_PASS}"
    echo
    echo "  使用: proxychains4 curl http://192.168.103.10"
    echo
}

# ============ 主程序 ============
main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║   VPN Proxy 远程测试工具 v1.0          ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"

    # 检查配置
    if [[ "$PROXY_SERVER" == "YOUR_SERVER_IP" ]]; then
        print_error "请先修改脚本中的 PROXY_SERVER 为你的实际服务器 IP"
        exit 1
    fi

    echo "目标服务器: ${PROXY_SERVER}"
    echo "HTTP 端口:  ${HTTP_PORT}"
    echo "SOCKS 端口: ${SOCKS_PORT}"
    echo

    # 执行测试
    check_dependencies

    if test_internet; then
        test_internal_http
        test_internal_ports
    else
        print_error "代理基本连接失败，请检查："
        echo "  1. 服务器 IP 地址是否正确"
        echo "  2. 防火墙是否放行 ${HTTP_PORT} 和 ${SOCKS_PORT} 端口"
        echo "  3. 用户名密码是否正确"
        exit 1
    fi

    show_config_examples

    print_header "测试完成"
    print_success "代理服务器工作正常"
    echo "现在你可以配置浏览器或应用程序使用该代理访问内网资源"
}

# 运行主程序
main "$@"
