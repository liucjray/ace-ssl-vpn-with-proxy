# FoxyProxy 配置指南

## 📋 可用代理端口

| 端口 | 协议 | 认证 | 说明 |
|------|------|------|------|
| 8080 | HTTP | 需要用户名/密码 | 推荐用于 FoxyProxy |
| 1080 | SOCKS5 | 需要用户名/密码 | 某些应用不支持 |
| **1081** | **SOCKS5** | **无需认证** | **FoxyProxy SOCKS5 专用** |

---

## 🦊 FoxyProxy 配置方法

### 方法 1：HTTP 代理（最推荐）

HTTP 代理在 FoxyProxy 中支持最好，完美支持用户名/密码认证。

#### Chrome/Edge + FoxyProxy 配置：

1. **安装 FoxyProxy**
   - 打开 Chrome/Edge 扩展商店
   - 搜索 "FoxyProxy"
   - 安装 "FoxyProxy Standard"

2. **添加代理配置**
   - 点击 FoxyProxy 图标 → Options
   - 点击 "Add New Proxy"
   - 填写配置：

   ```
   Title/Name:      VPN Proxy HTTP
   Proxy Type:      HTTP
   Proxy IP:        YOUR_SERVER_IP
   Port:            8080
   Username:        admin
   Password:        changeme123
   ```

3. **启用代理**
   - 点击 FoxyProxy 图标
   - 选择 "Use proxy VPN Proxy HTTP for all URLs"

4. **测试**
   - 访问 https://ipinfo.io
   - 应该看到你的服务器 IP: 61.61.91.209

---

### 方法 2：SOCKS5 代理（无需认证）

如果你更喜欢 SOCKS5，使用 **1081 端口**（无需认证）。

#### Chrome/Edge + FoxyProxy 配置：

1. **添加代理配置**
   - 点击 FoxyProxy 图标 → Options
   - 点击 "Add New Proxy"
   - 填写配置：

   ```
   Title/Name:      VPN Proxy SOCKS5
   Proxy Type:      SOCKS5
   Proxy IP:        YOUR_SERVER_IP
   Port:            1081
   Username:        (留空)
   Password:        (留空)
   ```

2. **启用代理**
   - 点击 FoxyProxy 图标
   - 选择 "Use proxy VPN Proxy SOCKS5 for all URLs"

⚠️ **安全提示**：1081 端口无需认证，建议配合防火墙使用：
```bash
# 只允许你的 IP 访问
sudo iptables -I INPUT -p tcp --dport 1081 -s YOUR_HOME_IP -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 1081 -j DROP
```

---

### 方法 3：Firefox 原生 SOCKS5

Firefox 可以直接在设置中配置 SOCKS5 代理。

#### Firefox 配置：

1. **打开设置**
   - 设置 → 常规 → 网络设置 → 设置

2. **手动代理配置**
   ```
   SOCKS Host:      YOUR_SERVER_IP
   Port:            1081
   SOCKS v5:        ✅ 选中
   代理 DNS:         ✅ 选中（推荐）
   ```

3. **测试**
   - 访问 https://ipinfo.io
   - 应该看到服务器 IP

---

## 🎯 推荐配置

### 适合大多数用户：HTTP 代理 (8080)

**优点**：
- ✅ 完美支持用户名/密码认证
- ✅ FoxyProxy 完全兼容
- ✅ 更安全（需要认证）
- ✅ 日志更详细

**缺点**：
- ⚠️ 只支持 HTTP/HTTPS 协议

### 适合高级用户：SOCKS5 (1081)

**优点**：
- ✅ 支持所有 TCP 协议
- ✅ 可以代理任何应用
- ✅ 性能略好

**缺点**：
- ⚠️ 无认证（需要防火墙保护）
- ⚠️ 某些浏览器支持不完善

---

## 🧪 测试步骤

### 1. 测试代理连接

**在浏览器中**：
1. 配置 FoxyProxy（使用上述任一方法）
2. 访问：https://ipinfo.io
3. 检查显示的 IP 是否为：`61.61.91.209`（你的服务器 IP）

### 2. 测试内网访问

**访问内网资源**：
1. 启用 FoxyProxy 代理
2. 在浏览器访问：`http://192.168.103.10`
3. 应该能访问到 VPN 内网的资源

### 3. 使用模式切换

FoxyProxy 支持多种模式：
- **Disabled**: 直接连接（不用代理）
- **Use proxy for all URLs**: 所有流量走代理
- **Use proxy based on patterns**: 根据规则自动切换

**推荐设置（智能模式）**：
```
规则 1: *.192.168.*     → 使用 VPN Proxy
规则 2: 10.*            → 使用 VPN Proxy
规则 3: 其他             → 直接连接
```

---

## 🔧 故障排除

### 问题 1：FoxyProxy 无法连接

**检查项**：
1. 服务器 IP 是否正确
2. 端口是否开放：
   ```bash
   telnet YOUR_SERVER_IP 8080
   ```
3. 防火墙是否放行：
   ```bash
   sudo iptables -L -n | grep 8080
   ```
4. 代理服务是否运行：
   ```bash
   docker logs sslvpn-proxy-1 | tail -20
   ```

### 问题 2：SOCKS5 认证失败

**解决方案**：
- 使用 **1081 端口**（无需认证）
- 或者改用 **HTTP 代理 8080 端口**

### 问题 3：访问内网失败

**检查 VPN 连接**：
```bash
# 从服务器测试
docker exec sslvpn-proxy-1 ping -c 3 192.168.103.10

# 查看路由
docker exec sslvpn-proxy-1 ip route
```

### 问题 4：速度慢

**优化建议**：
1. 使用 SOCKS5 代理（性能更好）
2. 只对内网流量使用代理（Pattern 模式）
3. 检查 VPN 连接质量

---

## 📊 性能对比

| 代理类型 | 速度 | 兼容性 | 安全性 | 推荐度 |
|---------|------|--------|--------|--------|
| HTTP (8080) | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| SOCKS5 (1081) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## 🎓 高级配置

### 自动切换（推荐）

**FoxyProxy Pattern 配置**：

1. **内网流量走代理**：
   ```
   Pattern: 192.168.*
   Pattern Type: Wildcard
   Proxy: VPN Proxy
   ```

2. **公网直接连接**：
   ```
   Pattern: *
   Pattern Type: Wildcard
   Proxy: [Direct]
   ```

这样只有访问内网时才使用代理，其他流量直接连接。

### Chrome 启动参数

如果不想用扩展，可以用命令行：
```bash
# HTTP 代理
chrome --proxy-server="http://YOUR_SERVER_IP:8080"

# SOCKS5 代理
chrome --proxy-server="socks5://YOUR_SERVER_IP:1081"
```

### 系统级代理（全局）

**Windows**：
```
设置 → 网络和 Internet → 代理
手动设置代理：
  地址: YOUR_SERVER_IP
  端口: 8080
  用户名: admin
  密码: changeme123
```

**macOS**：
```
系统偏好设置 → 网络 → 高级 → 代理
Web 代理 (HTTP):
  服务器: YOUR_SERVER_IP
  端口: 8080
  认证: admin / changeme123
```

**Linux**：
```bash
export http_proxy="http://admin:changeme123@YOUR_SERVER_IP:8080"
export https_proxy="http://admin:changeme123@YOUR_SERVER_IP:8080"
```

---

## 📞 获取帮助

如果遇到问题：
1. 查看日志：
   ```bash
   ./monitor_logs.sh
   ```

2. 测试连接：
   ```bash
   curl -x http://admin:changeme123@YOUR_SERVER_IP:8080 https://ipinfo.io/ip
   ```

3. 参考文档：
   - [README.md](README.md)
   - [PROXY_TEST.md](PROXY_TEST.md)
   - [LOG_MONITORING_GUIDE.md](LOG_MONITORING_GUIDE.md)

---

**更新日期**: 2025-12-09
**状态**: ✅ 已测试通过
