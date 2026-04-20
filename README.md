# AssppWeb

> **Note**: This project is a fork of [Lakr233/AssppWeb](https://github.com/Lakr233/AssppWeb), optimized for personal usage scenarios with enhanced cross-platform compatibility and deployment scripts.
>
> **注意**：本项目是 [Lakr233/AssppWeb](https://github.com/Lakr233/AssppWeb) 的 Fork 版本，针对个人使用场景进行了优化，增强了跨平台兼容性和部署脚本。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Docker Pulls](https://img.shields.io/docker/pulls/ghcr.io/yueying23/assppweb)](https://github.com/yueying23/AssppWeb/pkgs/container/assppweb)
[![Node.js Version](https://img.shields.io/badge/Node.js-20+-green)](https://nodejs.org/)

**一个基于零信任架构的 Apple App Store 侧载工具（Web 版）**

在浏览器中管理多个 Apple ID，搜索应用、获取许可证、下载并签名 IPA 文件，实现安全的 iOS 应用侧载。所有凭证永不离开您的浏览器，服务器无法触碰任何敏感信息。

---

## 🛡️ 核心特性

### 🔐 零信任安全架构
- **凭证不离端**：Apple 密码、Token、Cookies 仅存储在浏览器 IndexedDB 中
- **端到端加密**：通过 libcurl.js WASM + Mbed TLS 1.3 直接与 Apple 通信
- **Wisp 隧道**：所有流量通过 WebSocket 多路复用 TCP 隧道传输，服务器无法解密
- **加盐哈希**：可选的 `VITE_ACCOUNT_HASH_SALT` 防止彩虹表攻击和跨实例枚举

### 📱 完整的 Apple 协议支持
- **多账户管理**：支持添加多个 Apple ID，每账户独立设备标识符（Device ID）
- **双因素认证**：完整支持 2FA 流程
- **应用搜索**：基于 iTunes API 的应用搜索和版本查询
- **许可证获取**：自动处理购买流程获取下载权限
- **IPA 签名**：自动注入 SINF DRM 签名和 iTunesMetadata 元数据

### 🚀 现代化用户体验
- **响应式设计**：完美支持桌面端和移动端
- **暗黑模式**：系统级主题自动切换，无闪烁（FOUC-free）
- **多语言支持**：中文、英文、日文、韩文、俄文、繁体中文
- **实时进度**：分块下载显示详细进度，支持暂停/恢复

### 📦 灵活的部署方式
- **Docker 一键部署**：官方镜像 `ghcr.io/yueying23/assppweb:latest`
- **本地构建运行**：提供自动化构建脚本 `app/build.sh` 和 `app/start.sh`
- **开发友好**：前后端分离，支持热重载开发模式

---

## ⚡ 快速开始

### 方式一：Docker Compose（推荐）

```
# 1. 克隆仓库
git clone https://github.com/yueying23/AssppWeb.git
cd AssppWeb

# 2. 配置环境变量
cp .env.example .env
nano .env  # 编辑 ACCESS_PASSWORD 和 VITE_ACCOUNT_HASH_SALT

# 3. 启动服务
docker compose up -d

# 4. 访问应用
# http://localhost:8080
```

### 方式二：Docker 命令

```
docker run -d \
  --name asspp-web \
  -p 8080:8080 \
  -v asspp-data:/data \
  -e ACCESS_PASSWORD="your-access-password" \
  -e VITE_ACCOUNT_HASH_SALT=$(openssl rand -hex 32) \
  ghcr.io/yueying23/assppweb:latest
```

### 方式三：从源码构建

```
# 1. 构建应用
chmod +x scripts/build.sh scripts/start.sh
./scripts/build.sh

# 2. 交互式配置（首次推荐）
./scripts/start.sh -i

# 3. 或直接启动
./scripts/start.sh
```

---

## 🏗️ 架构说明

### 零信任数据流

```
┌─ 浏览器（客户端）─────────────────────────────────┐
│  凭证（IndexedDB）：email, password, cookies      │
│    passwordToken, DSID, deviceIdentifier, pod     │
│                                                    │
│  Apple 协议（libcurl.js WASM + Mbed TLS 1.3）：   │
│    1. Bag 获取 → 后端代理 → 解析认证 URL            │
│    2. 认证 → 获取 token, cookies, pod              │
│    3. 购买 → 获取许可证                             │
│    4. 下载信息 → 获取 CDN URL + SINFs + 元数据     │
│    5. 版本列表/查询                                 │
│                                                    │
│  TLS 1.3 加密 via Wisp over WebSocket             │
└──────────────────────┬─────────────────────────────┘
                       │ Wisp 多路复用 TCP（服务器无法读取）
┌─ 服务器（Wisp 代理） ┴─────────────────────────────┐
│  • Wisp 服务器 (@mercuryworkshop/wisp-js)          │
│  • 盲目 TCP 中继（不解密）                          │
│  • Bag 代理：GET /api/bag?guid=<id>                │
│  • IPA 编译：下载 CDN → 注入 SINF → 生成 manifest  │
└────────────────────────────────────────────────────┘
```

**关键不变量**：服务器**永远无法看到** Apple 凭证。所有 Apple TLS 在浏览器端终止。服务器仅接收公开的 CDN URL 和非秘密元数据。

---

## ⚙️ 配置

### 环境变量

| 变量名 | 默认值 | 说明 | 必需 |
|--------|--------|------|------|
| `PORT` | `8080` | 服务端口 | 否 |
| `DATA_DIR` | `/data` (Docker) 或 `$HOME/asspp-data` | 数据存储目录 | 否 |
| `ACCESS_PASSWORD` | - | 访问密码（留空表示无需密码） | 否 |
| `VITE_ACCOUNT_HASH_SALT` | - | 账户哈希盐值（防止彩虹表攻击） | 推荐 |
| `DOWNLOAD_THREADS` | `8` | 下载线程数（1-32） | 否 |
| `MAX_DOWNLOAD_MB` | `0` | 最大下载文件大小 MB（0 表示不限制） | 否 |
| `AUTO_CLEANUP_DAYS` | `0` | 自动清理天数（0 表示禁用） | 否 |
| `PUBLIC_BASE_URL` | - | 公共基础 URL（Nginx 反代时使用） | 否 |
| `UNSAFE_DANGEROUSLY_DISABLE_HTTPS_REDIRECT` | `false` | 禁用 HTTPS 重定向 | 否 |

### 安全配置建议

```
# 生成账户哈希盐值（防止彩虹表攻击）
export VITE_ACCOUNT_HASH_SALT=$(openssl rand -hex 32)

# 设置访问密码
export ACCESS_PASSWORD="your-strong-password"
```

⚠️ **重要**：`VITE_ACCOUNT_HASH_SALT` 一旦设置后不要更改，否则所有现有账户的 Hash 将失效。

---

## 📖 使用指南

### 1. 首次访问

- 如果设置了 `ACCESS_PASSWORD`，输入密码解锁
- 系统使用简单的 Token 验证机制（SHA256 哈希对比）

### 2. 添加 Apple 账户

1. 点击侧边栏 **"账户"** 菜单
2. 点击 **"添加账户"** 按钮
3. 输入 Apple ID 和密码
4. 如有双因素认证，输入 6 位验证码
5. （可选）自定义设备标识符（12 位十六进制）
6. 点击 **"认证"** 完成添加

### 3. 搜索应用

1. 切换到 **"搜索"** 页面
2. 输入应用名称或 Bundle ID
3. 浏览搜索结果，查看应用详情
4. 点击应用卡片查看详细版本历史

### 4. 下载与安装

1. 在应用详情页选择要下载的版本
2. 选择已认证的 Apple 账户
3. 点击 **"下载"** 按钮
4. 在 **"下载列表"** 中监控进度
5. 下载完成后点击 **"安装"** 生成 itms-services 链接
6. 使用 iOS 设备扫描二维码或点击链接进行 OTA 安装

---

## 🔧 开发

### 环境要求

- Node.js 20+
- npm 9+
- Git

### 本地开发

```
# 终端 1：启动后端
cd src/backend
npm install
npm run dev

# 终端 2：启动前端
cd src/frontend
npm install
npm run dev
```

前端开发服务器（默认 `localhost:5173`）会自动代理 `/api` 请求到后端（默认 `localhost:8080`）。

### 测试

```
# 后端测试
cd src/backend
npm test

# 前端测试
cd src/frontend
npm test

# E2E 测试（需要 Docker）
cd e2e
pnpm test
```

### 代码规范

项目遵循严格的代码规范，详见 [AGENTS.md](AGENTS.md)（英文）或 [AGENTS-CN.md](AGENTS-CN.md)（中文）。

**关键规范**：
- TypeScript 缩进 2 空格，使用单引号
- 导入顺序：React → 布局 → 通用组件 → Hooks → API → 工具 → 配置 → 类型
- `transition-colors` 仅用于交互元素（input、button），禁止用于静态容器
- 新增共享组件必须同步更新 AGENTS.md 文档

---

## 📦 部署

### 生产环境部署

#### Docker Compose（推荐）

```
# docker-compose.yml
version: '3.8'
services:
  asspp-web:
    image: ghcr.io/yueying23/assppweb:latest
    ports:
      - "8080:8080"
    volumes:
      - asspp-data:/data
    environment:
      - ACCESS_PASSWORD=${ACCESS_PASSWORD}
      - VITE_ACCOUNT_HASH_SALT=${VITE_ACCOUNT_HASH_SALT}
    restart: unless-stopped

volumes:
  asspp-data:
```

```
# 创建 .env 文件
cat > .env << EOF
ACCESS_PASSWORD=$(openssl rand -base64 32)
VITE_ACCOUNT_HASH_SALT=$(openssl rand -hex 32)
EOF

# 启动服务
docker compose up -d
```

#### Nginx 反向代理（iOS安装应用必不可少）

**推荐使用项目提供的优化配置模板 [`nginx.conf.example`](nginx.conf.example)。**

该模板针对 AssppWeb 的 Wisp 协议（WebSocket）进行了优化，包含以下特性：
- ✅ WebSocket 完整支持（Wisp 协议必需）
- ✅ SSL/TLS 1.2/1.3 安全配置
- ✅ Gzip 压缩优化
- ✅ 安全头（CSP、HSTS、X-Frame-Options 等）
- ✅ 性能优化（缓冲、超时、连接复用）
- ✅ HTTP 到 HTTPS 自动重定向

**快速部署步骤：**

```
# 1. 复制配置文件
sudo cp nginx.conf.example /etc/nginx/sites-available/assppweb

# 2. 编辑配置（修改域名、证书路径等）
sudo nano /etc/nginx/sites-available/assppweb

# 3. 创建软链接启用站点
sudo ln -s /etc/nginx/sites-available/assppweb /etc/nginx/sites-enabled/

# 4. 测试配置语法
sudo nginx -t

# 5. 重载 Nginx
sudo systemctl reload nginx
```

**手动配置示例（基础版）：**

如果您需要自定义配置，可以参考以下基础模板：

```
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    # SSL 证书配置
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    # SSL 优化
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # 客户端最大 body 大小
    client_max_body_size 500M;

    location / {
        proxy_pass http://localhost:8080;
        
        # 基础代理头
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket 支持 (Wisp 协议必需)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # 缓冲设置 (优化实时进度流)
        proxy_buffering off;
        proxy_request_buffering off;
    }
}

# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}
```

⚠️ **重要提示**：
- iOS 安装链接 `itms-services://` 需要 HTTPS，必须把 AssppWeb 放在一个带有有效 TLS 证书的反向代理后面。
- 若遇到无限重定向（因 `X-Forwarded-Proto` 错误），可设置 `UNSAFE_DANGEROUSLY_DISABLE_HTTPS_REDIRECT=true` 并强制代理端 HTTPS。
- WebSocket 支持是必需的，否则 Wisp 协议无法工作，应用将无法与 Apple 服务器通信。
- 建议使用 Let's Encrypt 免费证书：`sudo certbot --nginx -d your-domain.com`
- 生产环境请务必配置 `ACCESS_PASSWORD` 环境变量。

---

### Linux 原生部署 (Systemd + Nginx)

除了 Docker 部署，您还可以选择在 Linux 服务器上原生部署 AssppWeb，配合 Nginx 反代实现生产环境运行。

#### 前置要求

- Ubuntu 20.04+ / Debian 11+ / CentOS 8+
- Node.js 20+
- Nginx
- Git

#### 步骤 1：安装依赖

```
# Ubuntu/Debian
sudo apt update
sudo apt install -y nodejs npm nginx git curl

# 验证 Node.js 版本 (需要 20+)
node --version

# 如果版本过低，使用 NodeSource 安装最新版
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

#### 步骤 2：克隆并构建项目

```
# 克隆仓库
sudo mkdir -p /opt
cd /opt
sudo git clone https://github.com/yueying23/AssppWeb.git
cd AssppWeb

# 构建项目
chmod +x scripts/build.sh
./scripts/build.sh

# 设置权限
sudo chown -R www-data:www-data /opt/AssppWeb
```

#### 步骤 3：配置环境变量

```
# 复制环境变量模板
sudo cp .env.example .env

# 生成安全密钥
export ACCESS_PASSWORD=$(openssl rand -base64 32)
export VITE_ACCOUNT_HASH_SALT=$(openssl rand -hex 32)

# 写入 .env 文件
cat > .env << EOF
PORT=8080
DATA_DIR=/opt/AssppWeb/data
ACCESS_PASSWORD=$ACCESS_PASSWORD
VITE_ACCOUNT_HASH_SALT=$VITE_ACCOUNT_HASH_SALT
DOWNLOAD_THREADS=8
MAX_DOWNLOAD_MB=0
AUTO_CLEANUP_DAYS=0
EOF

# 设置权限（仅 root 可读）
sudo chmod 600 .env
sudo chown www-data:www-data .env
```

#### 步骤 4：创建 Systemd 服务

```
# 复制服务文件模板
sudo cp assppweb.service.example /etc/systemd/system/assppweb.service

# 编辑服务文件（确认 WorkingDirectory 路径正确）
sudo nano /etc/systemd/system/assppweb.service

# 重新加载 systemd 配置
sudo systemctl daemon-reload

# 启动服务
sudo systemctl enable --now assppweb

# 检查服务状态
sudo systemctl status assppweb

# 查看日志
sudo journalctl -u assppweb -f
```

#### 步骤 5：配置 Nginx 反代

参考上方的 [Nginx 反向代理](#nginx-反向代理) 章节，使用项目提供的优化配置模板 [`nginx.conf.example`](nginx.conf.example)。

**关键配置项检查清单：**
- [ ] 修改 `server_name` 为您的域名
- [ ] 配置 SSL 证书路径（推荐使用 Certbot 自动申请）
- [ ] 确认 `proxy_pass` 指向正确的后端地址（默认 `127.0.0.1:8080`）
- [ ] 确保 WebSocket 支持配置正确（`Upgrade` 和 `Connection` 头）

#### 步骤 6：防火墙配置

```
# 如果使用 UFW (Ubuntu)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload

# 如果使用 firewalld (CentOS)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

#### 步骤 7：访问应用

打开浏览器访问 `https://your-domain.com`，输入 `ACCESS_PASSWORD` 即可开始使用。

#### 维护命令

```
# 重启服务
sudo systemctl restart assppweb

# 停止服务
sudo systemctl stop assppweb

# 查看实时日志
sudo journalctl -u assppweb -f

# 查看资源占用
sudo systemctl status assppweb

# 更新项目
cd /opt/AssppWeb
sudo git pull
./scripts/build.sh
sudo systemctl restart assppweb
```

⚠️ **注意事项**：
- 确保 `.env` 文件权限设置为 `600`，仅 root 或 www-data 用户可读。
- 定期备份 `/opt/AssppWeb/data` 目录（如果使用本地数据存储）。
- 监控日志文件大小，配置 logrotate 防止磁盘占满。
- 建议启用 fail2ban 防止暴力破解 `ACCESS_PASSWORD`。

### 日志管理

```
# 查看实时日志
docker compose logs -f

# 或本地部署时
tail -f logs/latest.log

# 查看特定日期日志
tail -f logs/app-$(date +%Y-%m-%d).log
```

### 日志轮转 (Logrotate)

为了防止日志文件无限增长占用磁盘空间，建议配置系统级的日志轮转。项目根目录提供了配置模板 `logrotate.conf.example`。

1. **复制配置文件**：
   ```bash
   sudo cp logrotate.conf.example /etc/logrotate.d/asspp-web
   ```

2. **编辑配置路径**：
   使用编辑器打开 `/etc/logrotate.d/asspp-web`，将日志路径修改为你实际的部署路径（例如 `/opt/AssppWeb/logs/*.log`）。

3. **测试配置**：
   ```bash
   sudo logrotate -d /etc/logrotate.d/asspp-web
   ```

---

## 🔐 安全模型

### 为什么它是安全的？

1. **凭证隔离**：Apple 密码、Token、Cookies 仅存储在浏览器 IndexedDB 中，受同源策略保护
2. **TLS 1.3 端到端**：通过 libcurl.js WASM 在浏览器内完成 TLS 握手，服务器无法中间人攻击
3. **盲目代理**：Wisp 协议仅提供 TCP 隧道，服务器无法解析或记录 Apple 协议内容
4. **无状态设计**：服务器不维护会话状态，使用简单的 Token 验证机制（SHA256 哈希对比）
5. **加盐哈希**：可选的 Salt 防止账户标识符被彩虹表破解

### 威胁模型

- ✅ **防御**：网络窃听、服务器入侵、数据库泄露
- ⚠️ **假设可信**：浏览器环境（XSS 可泄露凭证，但这是 Web 应用的固有限制）
- ❌ **不防御**：恶意浏览器扩展、键盘记录器、物理访问

详见 [AGENTS.md - Security Model](AGENTS.md#security-model)

---

### 开发前必读

- 📖 [AGENTS.md](AGENTS.md) - 完整的技术规范和开发指南（英文）
- 📖 [AGENTS-CN.md](AGENTS-CN.md) - 中文版开发指南
- 🧪 运行测试确保没有破坏现有功能
- 📝 遵循现有的代码风格和架构模式

---

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE)。

---

## ⚠️ 免责声明

本项目仅供学习和研究使用。使用者应遵守当地法律法规及 Apple 服务条款。开发者不对因使用本软件而产生的任何后果负责。

---

## 🙏 致谢

- **[Lakr233/AssppWeb](https://github.com/Lakr233/AssppWeb)** - 本项目的原始基础版本，感谢原作者 [@Lakr233](https://github.com/Lakr233) 的优秀工作。
- [@mercuryworkshop/wisp-js](https://github.com/mercuryworkshop/wisp-js) - Wisp 协议实现
- [libcurl.js](https://github.com/curl/libcurl.js) - 浏览器端 cURL WASM 移植
- [ApplePackage](references/ApplePackage/) - Swift 参考实现（事实标准）
- React、Vite、Tailwind CSS 等开源社区

---

**⭐ 如果这个项目对您有帮助，请给个 Star！**
