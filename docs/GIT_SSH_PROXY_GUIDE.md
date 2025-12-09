# Git SSH 通過 SOCKS5 Proxy 連接指南

本指南說明如何在**你的本地電腦**上配置 Git SSH，通過 SOCKS5 proxy 訪問內網 GitLab。

## 前置條件

1. 本地電腦已經配置 proxy 連接到服務器：
   - HTTP Proxy: `localhost:8080`（需要認證：admin/changeme123）
   - SOCKS5 Proxy: `localhost:1080`（需要認證：admin/changeme123）
   - SOCKS5 Proxy: `localhost:1081`（無需認證）✅ 推薦使用

2. 確認 proxy 連接正常：
   ```bash
   curl -x socks5://localhost:1081 http://192.168.101.200
   ```

## 配置方法

### 方法 1：SSH Config 配置（推薦）

在**你的本地電腦**上編輯 `~/.ssh/config` 文件：

```bash
# Linux/Mac
nano ~/.ssh/config

# Windows (Git Bash)
notepad ~/.ssh/config
```

添加以下配置：

```bash
Host gitlab.oa.acelink.cc
    HostName gitlab.oa.acelink.cc
    User git
    Port 22
    ProxyCommand nc -X 5 -x 127.0.0.1:1081 %h %p
```

**說明**：
- `nc -X 5`：使用 SOCKS5 協議
- `-x 127.0.0.1:1081`：SOCKS5 proxy 地址（無需認證的端口）
- `%h %p`：自動替換為目標主機和端口

#### Windows 用戶注意

如果你的 Windows 沒有 `nc` 命令，使用 `connect` 或 `ncat`：

**使用 Git for Windows 內建的 connect**：
```bash
Host gitlab.oa.acelink.cc
    HostName gitlab.oa.acelink.cc
    User git
    Port 22
    ProxyCommand connect -S 127.0.0.1:1081 %h %p
```

**或使用 ncat（需要安裝 nmap）**：
```bash
Host gitlab.oa.acelink.cc
    HostName gitlab.oa.acelink.cc
    User git
    Port 22
    ProxyCommand ncat --proxy-type socks5 --proxy 127.0.0.1:1081 %h %p
```

### 方法 2：臨時使用環境變數

如果只是臨時使用，不想修改配置文件：

```bash
# Linux/Mac
export GIT_SSH_COMMAND="ssh -o ProxyCommand='nc -X 5 -x 127.0.0.1:1081 %h %p'"

# Windows (PowerShell)
$env:GIT_SSH_COMMAND="ssh -o ProxyCommand='connect -S 127.0.0.1:1081 %h %p'"

# 然後執行 git 命令
git clone git@gitlab.oa.acelink.cc:teemo/sifangpay.git
git pull
```

### 方法 3：針對單個倉庫配置

在已經 clone 的倉庫目錄中：

```bash
cd your-repo
git config core.sshCommand "ssh -o ProxyCommand='nc -X 5 -x 127.0.0.1:1081 %h %p'"
```

這樣只對當前倉庫生效。

## 測試連接

配置完成後，測試 SSH 連接：

```bash
ssh -T git@gitlab.oa.acelink.cc
```

成功的話會看到 GitLab 的歡迎訊息：
```
Welcome to GitLab, @your-username!
```

如果連接失敗，加上 `-v` 參數查看詳細信息：
```bash
ssh -v git@gitlab.oa.acelink.cc
```

## 使用 Git

配置完成後，正常使用 Git 命令即可：

```bash
# Clone 倉庫
git clone git@gitlab.oa.acelink.cc:teemo/sifangpay.git

# 在已有倉庫中 pull/push
cd sifangpay
git pull
git push
```

## 配置多個內網 Git 服務器

如果有多個內網 Git 服務器，在 `~/.ssh/config` 中添加多個 Host：

```bash
# GitLab
Host gitlab.oa.acelink.cc
    HostName gitlab.oa.acelink.cc
    User git
    ProxyCommand nc -X 5 -x 127.0.0.1:1081 %h %p

# 內網 GitHub Enterprise
Host github.internal.company.com
    HostName github.internal.company.com
    User git
    ProxyCommand nc -X 5 -x 127.0.0.1:1081 %h %p

# 或者使用萬用字元配置所有 *.oa.acelink.cc
Host *.oa.acelink.cc
    User git
    ProxyCommand nc -X 5 -x 127.0.0.1:1081 %h %p
```

## 故障排除

### 1. nc: command not found

**解決方案**：
- Mac: `brew install netcat`
- Linux: `sudo apt install netcat` 或 `sudo yum install nc`
- Windows: 使用 `connect` 或安裝 nmap (`choco install nmap`)

### 2. Connection timeout

檢查：
- SOCKS5 proxy 是否正常運行
- 防火牆是否允許連接到 1081 端口
- 服務器上的 VPN 是否正常連接

```bash
# 測試 proxy 連接
curl -v -x socks5://localhost:1081 http://192.168.101.200
```

### 3. Authentication failed

如果使用 1080 端口（需要認證），確認用戶名密碼正確。建議使用 1081（無需認證）端口。

### 4. Host key verification failed

第一次連接時添加主機密鑰：
```bash
ssh-keyscan -H gitlab.oa.acelink.cc >> ~/.ssh/known_hosts
```

## 安全建議

1. 建議使用 SSH key 認證而非密碼
2. 將 SSH private key 設置適當權限：
   ```bash
   chmod 600 ~/.ssh/id_rsa
   chmod 644 ~/.ssh/id_rsa.pub
   ```
3. 不要在公共網絡使用未加密的 proxy

## 參考資料

- SSH Config 文檔：`man ssh_config`
- Git SSH 配置：https://git-scm.com/docs/git-config#Documentation/git-config.txt-coresshCommand
- ProxyCommand 說明：`man nc`
