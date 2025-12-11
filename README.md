# SSL VPN with Proxy Gateway

這個專案提供了基於 Docker 的 SSL VPN 客戶端，並整合了 HTTP/SOCKS5 代理服務器，讓外部請求可以通過代理進入，再經由 SSL VPN 出去。

## 快速開始

```bash
# 1. 修改 VPN 配置
vim conf/forti.conf  # 填入你的 VPN 帳號密碼

# 2. 修改代理密碼（重要！）
vim conf/gost.conf   # 修改 PROXY_PASS 為強密碼

# 3. 構建並啟動
docker compose build
docker compose up -d

# 4. 測試代理（替換為你的服務器IP）
curl -x http://admin:你的密碼@YOUR_SERVER_IP:8080 https://ipinfo.io/ip
```

詳細配置和測試請參考 [PROXY_TEST.md](PROXY_TEST.md)

## 功能特性

- ✅ 自動連接 Fortinet SSL VPN
- ✅ HTTP/HTTPS 代理服務 (端口 8080)
- ✅ SOCKS5 代理服務 (端口 1080)
- ✅ 用戶名/密碼認證保護
- ✅ 所有代理流量自動通過 VPN 出口
- ✅ 支持公網訪問
- ✅ **IP 白名單**：通過 `white_list.conf` 靈活配置允許訪問的 IP/網段/域名
- ✅ **安全開關**：可選擇阻止非 VPN 路由的流量，防止主機 IP 外洩（預設開啟）

## 執行步驟

### 1. 配置 VPN 連接

修改 `conf/forti.conf` 填入你的 VPN 帳號密碼：

```ini
host = 27.105.217.17
port = 20443
username = your_username
password = your_password
```

### 2. 配置白名單（可選但推薦）

修改 `conf/white_list.conf` 設置允許通過 VPN 訪問的 IP 地址、網段和域名：

```bash
# 內網網段
192.168.100.0/24
192.168.101.0/24
192.168.102.0/24
192.168.103.0/24
10.0.0.0/16

# 單個 IP 地址
# 172.16.0.100

# 域名（會自動解析為 IP）
# gitlab.oa.acelink.cc
# jenkins.internal.company.com
```

**白名單說明**：
- 每行一個 IP 地址、CIDR 網段或域名
- 支持註釋（以 `#` 開頭）
- 空行會被忽略
- 域名會在容器啟動時自動解析為 IP 地址
- 域名解析支持 `/etc/hosts` 映射和 DNS 查詢
- 修改後需要重新構建容器：`docker compose up -d --build`

### 3. 配置代理認證（重要！）

修改 `conf/gost.conf` 設置代理服務器的用戶名和密碼：

```bash
# 代理認證憑證
PROXY_USER=admin
PROXY_PASS=changeme123  # 請務必修改為強密碼！

# 安全開關：阻止非匹配流量（預設開啟）
BLOCK_UNMATCH_TRAFFIC=true
```

⚠️ **安全提醒**：
- 因為代理服務會暴露到公網，請務必設置強密碼！
- `BLOCK_UNMATCH_TRAFFIC=true`（預設）會阻止非 VPN 路由的流量，防止主機 IP 外洩
- 只有符合白名單（`white_list.conf`）的流量可以通過代理

### 4. 啟動服務

```bash
# 構建並啟動容器
docker compose up -d

# (可選) 配置主機路由，讓主機流量也能走 VPN
sudo bash forward.bash
```

### 5. 驗證服務

```bash
# 檢查 VPN 是否連接成功
ping 192.168.103.10

# 檢查容器日誌
docker logs -f sslvpn-proxy-1

# 應該看到類似輸出：
# VPN started.
# Starting Gost proxy server...
# Gost proxy started on port 8080 (HTTP) and 1080 (SOCKS5)
```

## 使用代理服務

### HTTP/HTTPS 代理

在你的客戶端（瀏覽器、應用程序）配置 HTTP 代理：

```
代理地址: your-server-ip:8080
用戶名: admin (或你在 gost.conf 設置的)
密碼: changeme123 (或你在 gost.conf 設置的)
```

**瀏覽器配置範例 (Firefox):**

1. 設置 → 網絡設置 → 手動代理配置
2. HTTP 代理: `your-server-ip`，端口: `8080`
3. 勾選「為所有協議使用此代理服務器」
4. 輸入用戶名和密碼

**cURL 範例:**

```bash
curl -x http://admin:changeme123@your-server-ip:8080 https://ipinfo.io
```

### SOCKS5 代理

```
代理地址: your-server-ip:1080
協議: SOCKS5
用戶名: admin
密碼: changeme123
```

**cURL 範例:**

```bash
curl --socks5 admin:changeme123@your-server-ip:1080 https://ipinfo.io
```

## 架構說明

```
┌─────────────────────────────────────────────────────────────────┐
│                        外部客戶端                                │
│  (瀏覽器、應用程序、命令行工具等)                                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ HTTP/SOCKS5 請求 (需要認證)
                         │ 用戶名: admin / 密碼: your_password
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                     公網服務器 (Host)                             │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Docker 容器 (10.73.0.5)                                  │   │
│  │                                                            │   │
│  │  ┌────────────────────────────────────┐                  │   │
│  │  │  Gost 代理服務器                    │                  │   │
│  │  │  - HTTP Proxy:  :8080              │                  │   │
│  │  │  - SOCKS5 Proxy: :1080             │◄─────── 端口映射  │   │
│  │  │  - 用戶名/密碼認證                  │         8080:8080│   │
│  │  └─────────────┬──────────────────────┘         1080:1080│   │
│  │                │                                          │   │
│  │                │ iptables NAT + 路由策略                   │   │
│  │                ↓                                          │   │
│  │  ┌────────────────────────────────────┐                  │   │
│  │  │  ppp0 接口 (VPN Tunnel)             │                  │   │
│  │  │  IP: 10.212.134.222                │                  │   │
│  │  │  Routes: 192.168.100-103.0/24      │                  │   │
│  │  └─────────────┬──────────────────────┘                  │   │
│  │                │                                          │   │
│  │                │ SSL/TLS 加密隧道                          │   │
│  └────────────────┼──────────────────────────────────────────┘   │
└───────────────────┼──────────────────────────────────────────────┘
                    │
                    │ HTTPS:20443
                    ↓
┌─────────────────────────────────────────────────────────────────┐
│         Fortinet SSL VPN Gateway (27.105.217.17:20443)          │
│         - 認證和授權                                              │
│         - VPN 隧道管理                                           │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ 內部網絡路由
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                     目標網站/內部服務                             │
│  - 192.168.100.0/24                                             │
│  - 192.168.101.0/24                                             │
│  - 192.168.102.0/24                                             │
│  - 192.168.103.0/24                                             │
│  - 或任何其他外部網站                                             │
└─────────────────────────────────────────────────────────────────┘

流量方向: 客戶端 → 代理認證 → Docker容器 → VPN隧道 → VPN網關 → 目標
返回方向: 目標 → VPN網關 → VPN隧道 → Docker容器 → 代理 → 客戶端
```

## 流量路由說明

### Split-Tunnel 模式 (當前配置)

此 VPN 配置為 **分離隧道模式**，流量分流如下：

1. **訪問內網資源**（192.168.100-103.0/24, 10.0.0.0/16）：
   - 客戶端 → 代理認證 → Docker 容器 → **VPN 隧道 (ppp0)** → VPN 網關 → 內網服務器

2. **訪問外網資源**（Google, YouTube 等公網網站）：
   - 客戶端 → 代理認證 → Docker 容器 → **直接出口 (eth0)** → 公網
   - 出口 IP：你的服務器公網 IP（61.61.91.209）

### 如果需要所有流量都走 VPN (Full-Tunnel)

如果你希望代理的**所有流量**（包括訪問外網）都通過 VPN 出去，需要：

1. 確認 VPN 網關支持全流量模式（非 split-tunnel）
2. 修改 VPN 配置文件 `conf/forti.conf`，移除或調整路由限制
3. 聯繫 VPN 管理員確認是否允許全流量訪問

**注意**：當前 VPN 配置只允許訪問特定內網網段，不支持全流量模式。

## 安全建議

1. **強密碼**: 務必修改 `conf/gost.conf` 中的默認密碼
2. **流量控制**: 保持 `BLOCK_UNMATCH_TRAFFIC=true`（預設開啟），防止主機 IP 意外外洩
   - 開啟時：只允許 VPN 路由的流量通過，其他流量會被阻止
   - 關閉時：所有流量都可通過代理，非 VPN 路由的流量會使用主機 IP
3. **防火牆**: 如果不需要公網訪問，可以配置防火牆限制訪問 IP
4. **日誌監控**: 定期檢查 `/var/log/gost.log` 查看訪問記錄
5. **證書驗證**: VPN 連接已啟用證書驗證 (trusted-cert)

## 故障排除

### 代理無法連接

```bash
# 檢查端口是否監聽
docker exec sslvpn-proxy-1 netstat -tlnp | grep -E "8080|1080"

# 檢查 Gost 進程
docker exec sslvpn-proxy-1 ps aux | grep gost
```

### VPN 未連接

```bash
# 檢查 ppp0 接口
docker exec sslvpn-proxy-1 ip a show ppp0

# 查看 VPN 日誌
docker logs sslvpn-proxy-1 | grep -i "vpn\|ppp"
```

### 流量未走 VPN

```bash
# 檢查路由表
docker exec sslvpn-proxy-1 ip route

# 檢查 iptables 規則
docker exec sslvpn-proxy-1 iptables -t nat -L -n -v
```

## 端口說明

- **8080**: HTTP/HTTPS 代理端口 (已映射到主機)
- **1080**: SOCKS5 代理端口 (已映射到主機)
- **20443**: Fortinet SSL VPN 端口 (出站連接)

## 自定義配置

### 修改 IP 白名單

編輯 `conf/white_list.conf`，添加或移除允許訪問的 IP 地址、網段和域名：

```bash
# 白名單範例
192.168.100.0/24           # 整個 C 類網段
10.10.0.0/16               # B 類網段
172.16.100.50              # 單個 IP 地址
gitlab.oa.acelink.cc       # 域名（自動解析）
jenkins.internal.com       # 內部域名
```

**使用提示**：
- 當 `BLOCK_UNMATCH_TRAFFIC=true` 時，只有白名單中的地址可以通過代理訪問
- **支持域名**：域名會在容器啟動時自動解析為 IP 地址
  - 優先使用 `getent hosts`（支持 `/etc/hosts` 映射）
  - 如果失敗則使用 DNS 查詢（`nslookup`）
- **配合 extra_hosts 使用**：如果內網域名需要特定映射，可在 `docker-compose.yml` 中添加：
  ```yaml
  extra_hosts:
    - "gitlab.oa.acelink.cc:192.168.101.200"
  ```
- 如果白名單文件不存在或無法讀取，系統會自動使用預設的網段（192.168.100-103.0/24, 10.0.0.0/16）
- 修改白名單後，需要重新構建容器：`docker compose up -d --build`

**實際案例**：訪問內網 GitLab

1. 在 `docker-compose.yml` 中添加域名映射：
   ```yaml
   extra_hosts:
     - "gitlab.oa.acelink.cc:192.168.101.200"
   ```

2. 在 `conf/white_list.conf` 中添加域名：
   ```bash
   gitlab.oa.acelink.cc
   ```
   或直接添加 IP：
   ```bash
   192.168.101.200
   ```

3. 重新構建容器：
   ```bash
   docker compose up -d --build
   ```

4. 查看解析結果：
   ```bash
   docker logs sslvpn-proxy-1 | grep gitlab
   # 應該看到：✓ Allowed: gitlab.oa.acelink.cc → 192.168.101.200
   ```

### 修改流量安全開關

編輯 `conf/gost.conf`，調整 `BLOCK_UNMATCH_TRAFFIC` 設置：

```bash
# 預設：開啟（推薦）- 只允許 VPN 路由的流量通過
BLOCK_UNMATCH_TRAFFIC=true

# 若要關閉：允許所有流量通過（警告：可能外洩主機 IP）
BLOCK_UNMATCH_TRAFFIC=false
```

**行為差異**：
- `true`（推薦）：
  - ✅ 只允許訪問 192.168.100-103.0/24、10.0.0.0/16 等 VPN 路由
  - ✅ 訪問其他網站會被阻止，確保主機 IP 不會外洩
  - ✅ 最安全的模式

- `false`：
  - ⚠️ 允許訪問任何網站
  - ⚠️ 非 VPN 路由的流量會使用主機 IP（可能外洩）
  - ⚠️ 僅在確實需要時使用

### 修改代理端口

編輯 `conf/gost.conf`:

```bash
PROXY_ADDR=:9999  # 修改為其他端口
```

同時修改 `docker-compose.yml`:

```yaml
ports:
  - "9999:9999"  # 對應修改
```

### 添加 IP 白名單

如需限制訪問 IP，可以在主機上配置 iptables:

```bash
# 只允許特定 IP 訪問代理
iptables -I INPUT -p tcp --dport 8080 -s 1.2.3.4 -j ACCEPT
iptables -I INPUT -p tcp --dport 8080 -j DROP
```

## 相關文件

- `Dockerfile`: 容器鏡像構建配置
- `docker-compose.yml`: 服務編排配置
- `conf/forti.conf`: VPN 連接配置
- `conf/gost.conf`: 代理服務器配置
- `conf/white_list.conf`: IP 白名單配置
- `scripts/up.sh`: 容器啟動腳本
- `scripts/keepalive.sh`: VPN 健康檢查腳本
