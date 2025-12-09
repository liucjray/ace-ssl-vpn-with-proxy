# Proxy 测试指南

## 服务状态确认

### 1. 检查容器运行状态
```bash
docker ps | grep sslvpn
```

### 2. 查看服务日志
```bash
docker logs sslvpn-proxy-1
```

应该看到：
```
VPN started.
Routing configured: All proxy traffic will exit via VPN (ppp0)
Starting Gost proxy server...
Gost proxy started on port 8080 (HTTP) and 1080 (SOCKS5)
Authentication: admin:changeme123
```

### 3. 验证端口监听
```bash
docker exec sslvpn-proxy-1 netstat -tlnp | grep -E "8080|1080"
```

应该看到：
```
tcp  0  0 :::8080  :::*  LISTEN  27/gost
tcp  0  0 :::1080  :::*  LISTEN  27/gost
```

## 代理功能测试

### HTTP 代理测试

从本机测试：
```bash
curl -x http://admin:changeme123@localhost:8080 https://ipinfo.io/ip
```

从其他机器测试（替换 YOUR_SERVER_IP）：
```bash
curl -x http://admin:changeme123@YOUR_SERVER_IP:8080 https://ipinfo.io/ip
```

### SOCKS5 代理测试

```bash
curl --socks5 admin:changeme123@localhost:1080 https://ipinfo.io/ip
```

### 测试代理是否通过 VPN 出口

```bash
# 通过代理访问，检查返回的 IP
curl -x http://admin:changeme123@localhost:8080 https://ipinfo.io
```

返回的 IP 应该是 VPN 的出口 IP（不是你本机的公网 IP）

### 浏览器配置测试（Chrome）

1. 安装 Proxy SwitchyOmega 扩展
2. 创建新配置：
   - 协议：HTTP
   - 服务器：YOUR_SERVER_IP
   - 端口：8080
   - 认证：勾选
   - 用户名：admin
   - 密码：changeme123
3. 启用该代理配置
4. 访问 https://ipinfo.io 查看出口 IP

### 浏览器配置测试（Firefox）

1. 设置 → 常规 → 网络设置 → 设置
2. 选择「手动代理配置」
3. HTTP 代理：YOUR_SERVER_IP，端口：8080
4. 勾选「为所有协议使用此代理服务器」
5. 点击「确定」
6. 访问 https://ipinfo.io 查看出口 IP

## VPN 连接测试

### 检查 VPN 接口
```bash
docker exec sslvpn-proxy-1 ip a show ppp0
```

### 检查 VPN 路由
```bash
docker exec sslvpn-proxy-1 ip route
```

应该看到通过 ppp0 的路由：
```
192.168.100.0/24 dev ppp0 scope link
192.168.101.0/24 dev ppp0 scope link
192.168.102.0/24 dev ppp0 scope link
192.168.103.0/24 dev ppp0 scope link
```

### Ping 测试内网地址
```bash
docker exec sslvpn-proxy-1 ping -c 3 192.168.103.10
```

## 安全检查

### 1. 确认已修改默认密码

查看当前密码配置：
```bash
cat conf/gost.conf
```

⚠️ **如果密码仍然是 `changeme123`，请立即修改！**

修改方法：
```bash
vim conf/gost.conf
# 修改 PROXY_PASS 为强密码
# 然后重启容器
docker compose restart
```

### 2. 查看代理访问日志
```bash
docker exec sslvpn-proxy-1 tail -f /var/log/gost.log
```

### 3. 限制访问 IP（可选）

如果只想允许特定 IP 访问代理：
```bash
# 只允许 1.2.3.4 访问
sudo iptables -I INPUT -p tcp --dport 8080 -s 1.2.3.4 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 8080 -j DROP
sudo iptables -I INPUT -p tcp --dport 1080 -s 1.2.3.4 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 1080 -j DROP
```

## 性能测试

### 测试代理速度
```bash
# 下载测试（通过代理）
curl -x http://admin:changeme123@localhost:8080 \
  -o /dev/null \
  -w "Speed: %{speed_download} bytes/sec\nTime: %{time_total}s\n" \
  http://speedtest.tele2.net/10MB.zip
```

### 测试延迟
```bash
# 通过代理访问多次，查看延迟
for i in {1..5}; do
  curl -x http://admin:changeme123@localhost:8080 \
    -w "Time: %{time_total}s\n" \
    -o /dev/null -s \
    https://www.google.com
done
```

## 故障排除

### 问题：代理无法连接

检查步骤：
1. 确认容器运行：`docker ps`
2. 检查端口映射：`docker port sslvpn-proxy-1`
3. 检查防火墙：`sudo iptables -L -n | grep 8080`
4. 查看容器日志：`docker logs sslvpn-proxy-1`

### 问题：认证失败

检查：
1. 用户名密码是否正确
2. 查看配置：`cat conf/gost.conf`
3. 重启容器：`docker compose restart`

### 问题：流量未走 VPN

检查：
1. ppp0 接口是否启动：`docker exec sslvpn-proxy-1 ip a show ppp0`
2. 路由表：`docker exec sslvpn-proxy-1 ip route`
3. 测试 IP：`curl -x http://admin:changeme123@localhost:8080 https://ipinfo.io/ip`

### 问题：VPN 断开连接

检查：
1. VPN 日志：`docker logs sslvpn-proxy-1 | grep -i error`
2. VPN 配置：`cat conf/forti.conf`
3. 重启容器：`docker compose restart`

## 当前测试结果

- ✅ VPN 连接成功：IP 10.212.134.222
- ✅ HTTP 代理工作：端口 8080
- ✅ SOCKS5 代理工作：端口 1080
- ✅ 出口 IP：61.61.91.209 (通过 VPN)
- ✅ 认证保护：admin/changeme123

## 下一步

1. **立即修改密码**（如果用于生产环境）
2. 配置防火墙规则（如需限制访问）
3. 监控日志，确保无异常访问
4. 考虑设置自动重启策略
5. 定期检查 VPN 连接状态
