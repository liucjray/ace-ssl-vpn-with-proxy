# VPN Proxy 日志监控指南

## 🚀 快速开始

### 最简单的方法 - 使用监控工具

```bash
cd /home/user/codes/acelink/sslvpn
./monitor_logs.sh
```

选择监控模式，实时查看流量！

---

## 📊 监控工具功能一览

### 模式 1：实时监控所有流量（彩色）
- 显示所有请求，带颜色标识
- HTTP 请求：绿色
- SOCKS5 请求：紫色
- VPN 相关：蓝色
- 错误信息：红色

### 模式 2：只监控 HTTP 代理
```
[2025-12-09 15:28:31] [route] 10.73.0.1:54032 -> http://:8080 -> ipinfo.io:443
```

### 模式 3：只监控 SOCKS5 代理
```
[15:28:45] 10.73.0.1:39260 → 34.117.59.81:443
```

### 模式 5：访问统计
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
总请求数:        156
HTTP 请求:       89
SOCKS5 请求:     67
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

访问最多的目标 IP (Top 10):
  24     192.168.103.10:80
  18     8.8.8.8:53
  15     34.117.59.81:443
  ...
```

### 模式 6：简洁模式
```
时间                 来源                      → 目标
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
15:28:31            10.73.0.1:54032          → 34.117.59.81:443
15:28:45            10.73.0.1:39260          → 192.168.103.10:80 [内网]
```

---

## 📝 命令行监控（不用工具）

### 实时查看所有日志
```bash
docker logs -f sslvpn-proxy-1
```

### 只看代理请求
```bash
# Gost 专用日志
docker exec sslvpn-proxy-1 tail -f /var/log/gost.log

# SOCKS5 请求
docker logs -f sslvpn-proxy-1 | grep socks5

# HTTP 请求
docker logs -f sslvpn-proxy-1 | grep "route.go"
```

### 查看最近的日志
```bash
# 最近 50 条
docker logs --tail 50 sslvpn-proxy-1

# 最近 100 条代理日志
docker exec sslvpn-proxy-1 tail -100 /var/log/gost.log
```

### 搜索特定内容
```bash
# 搜索特定 IP
docker exec sslvpn-proxy-1 grep "192.168.103.10" /var/log/gost.log

# 搜索特定时间段
docker logs sslvpn-proxy-1 | grep "07:28:"

# 查找错误
docker logs sslvpn-proxy-1 | grep -i error
```

---

## 📈 统计和分析

### 统计总请求数
```bash
docker exec sslvpn-proxy-1 grep -c "route.go" /var/log/gost.log
```

### 统计 HTTP 和 SOCKS5 请求
```bash
echo "HTTP 请求: $(docker exec sslvpn-proxy-1 grep -c 'http://:8080' /var/log/gost.log)"
echo "SOCKS5 请求: $(docker exec sslvpn-proxy-1 grep -c 'socks5://:1080' /var/log/gost.log)"
```

### 查看访问最多的 IP
```bash
docker exec sslvpn-proxy-1 grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' /var/log/gost.log | \
    sort | uniq -c | sort -rn | head -10
```

---

## 🔍 日志格式说明

### HTTP 代理日志格式
```
2025/12/09 07:28:31 http.go:256: [route] 来源IP:端口 -> http://:8080 -> 目标地址:端口
```

**示例**：
```
2025/12/09 07:28:31 http.go:256: [route] 10.73.0.1:54032 -> http://:8080 -> ipinfo.io:443
```

**解读**：
- `2025/12/09 07:28:31` - 时间戳
- `[route]` - 路由日志
- `10.73.0.1:54032` - 客户端 IP 和端口
- `http://:8080` - 通过 HTTP 代理
- `ipinfo.io:443` - 访问的目标地址

### SOCKS5 代理日志格式
```
2025/12/09 07:28:45 socks.go:889: [socks5] 来源IP:端口 -> socks5://:1080 -> 目标IP:端口
2025/12/09 07:28:45 socks.go:976: [socks5] 来源IP:端口 <-> 目标IP:端口
```

**示例**：
```
2025/12/09 07:28:45 socks.go:889: [socks5] 10.73.0.1:39260 -> socks5://:1080 -> 192.168.103.10:80
2025/12/09 07:28:45 socks.go:976: [socks5] 10.73.0.1:39260 <-> 192.168.103.10:80
```

**解读**：
- 第一行：建立连接
- 第二行：数据传输开始
- `<->` 表示双向通信已建立

### VPN 隧道日志
```
DEBUG:  pppd ---> gateway (86 bytes)
DEBUG:  gateway ---> pppd (86 bytes)
INFO:   Interface ppp0 is UP.
```

---

## 💾 日志导出和备份

### 导出日志到文件
```bash
# 导出所有日志
docker exec sslvpn-proxy-1 cat /var/log/gost.log > gost_logs_$(date +%Y%m%d).txt

# 导出最近 1000 条
docker logs --tail 1000 sslvpn-proxy-1 > vpn_logs_$(date +%Y%m%d).txt
```

### 按日期导出
```bash
# 今天的日志
docker exec sslvpn-proxy-1 grep "$(date +%Y/%m/%d)" /var/log/gost.log > today.log

# 昨天的日志
docker exec sslvpn-proxy-1 grep "$(date -d yesterday +%Y/%m/%d)" /var/log/gost.log > yesterday.log
```

---

## 🔄 日志轮转和清理

### 查看日志大小
```bash
docker exec sslvpn-proxy-1 du -h /var/log/gost.log
```

### 清空日志（谨慎使用）
```bash
# 备份后清空
docker exec sslvpn-proxy-1 sh -c "cat /var/log/gost.log > /tmp/backup.log && > /var/log/gost.log"

# 只保留最近 10000 行
docker exec sslvpn-proxy-1 sh -c "tail -10000 /var/log/gost.log > /tmp/gost.log.new && mv /tmp/gost.log.new /var/log/gost.log"
```

---

## 🎨 高级用法

### 实时监控特定 IP 的访问
```bash
docker exec sslvpn-proxy-1 tail -f /var/log/gost.log | grep --color "192.168.103.10"
```

### 监控内网访问（192.168.x.x）
```bash
docker exec sslvpn-proxy-1 tail -f /var/log/gost.log | grep --color "192.168"
```

### 彩色实时监控
```bash
docker logs -f sslvpn-proxy-1 2>&1 | \
    sed 's/\[http\]/\x1b[32m[HTTP]\x1b[0m/g' | \
    sed 's/\[socks5\]/\x1b[35m[SOCKS5]\x1b[0m/g'
```

### 创建自定义监控脚本
```bash
#!/bin/bash
# 实时监控并发送告警

docker exec sslvpn-proxy-1 tail -f /var/log/gost.log | while read line; do
    # 检测可疑活动
    if echo "$line" | grep -q "error\|fail"; then
        echo "[ALERT] $(date): $line" >> /var/log/vpn_alerts.log
        # 这里可以添加发送通知的代码
    fi

    # 显示日志
    echo "[$(date +%H:%M:%S)] $line"
done
```

---

## 🛠️ 故障排查

### 日志不更新？
```bash
# 检查 Gost 进程
docker exec sslvpn-proxy-1 ps aux | grep gost

# 重启容器
docker compose restart

# 查看容器状态
docker logs sslvpn-proxy-1 | tail -50
```

### 日志太多？
```bash
# 启用日志过滤，只记录重要信息
# 修改 scripts/up.sh 中的 Gost 启动参数
# 移除 -D 参数以减少 debug 信息
```

### 想看更详细的日志？
```bash
# 当前已启用 -D 参数（debug 模式）
# 已经是最详细的日志级别
```

---

## 📞 常见场景

### 场景 1：检查特定用户的访问
```bash
# 假设用户从 1.2.3.4 访问
docker exec sslvpn-proxy-1 grep "1.2.3.4" /var/log/gost.log
```

### 场景 2：监控内网服务器被访问情况
```bash
# 实时监控 192.168.103.10 的访问
docker exec sslvpn-proxy-1 tail -f /var/log/gost.log | grep "192.168.103.10"
```

### 场景 3：查看代理使用率
```bash
# 每分钟的请求数
watch -n 60 'docker exec sslvpn-proxy-1 grep -c "route.go" /var/log/gost.log'
```

### 场景 4：安全审计
```bash
# 导出完整日志用于审计
timestamp=$(date +%Y%m%d_%H%M%S)
docker exec sslvpn-proxy-1 cat /var/log/gost.log > audit_${timestamp}.log
echo "审计日志已保存: audit_${timestamp}.log"
```

---

## 📚 相关文档

- [README.md](README.md) - 主要文档
- [PROXY_TEST.md](PROXY_TEST.md) - 测试指南
- [DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md) - 部署总结

---

**提示**: 日志文件在容器重启后会保留（除非删除容器）。建议定期备份重要日志。
