# AssppWeb 智能体开发指令

## TypeScript 代码风格

- **缩进**：2 个空格
- **分号**：必须使用
- **引号**：字符串使用单引号
- **命名**：类型/接口使用 PascalCase，变量/函数使用 camelCase

## 项目结构

- `src/backend/` — Node.js/Express 服务器（TypeScript, ESM）
- `src/frontend/` — React 单页应用（TypeScript, Vite, Tailwind CSS）
- `scripts/` — 构建和部署脚本（`build.sh`, `start.sh`）
- `app/` — 构建产物输出目录（由 `scripts/build.sh` 生成）
- `e2e/` — Playwright 端到端测试（pnpm）
- `references/ApplePackage/` — Swift 参考实现（事实标准）
- 多阶段 Docker 构建（单个容器同时提供前后端服务）

## 架构 — 零信任

服务器是一个盲目的 TCP 代理。它**永远无法看到** Apple 凭证。

```
┌─ 浏览器（客户端）─────────────────────────────────┐
│  凭证（IndexedDB）：email, password, cookies,      │
│    passwordToken, DSID, deviceIdentifier, pod     │
│                                                    │
│  Apple 协议（libcurl.js WASM + Mbed TLS 1.3）：   │
│    1. Bag 获取 → 后端代理 → 解析认证 URL            │
│       （如果缺失则回退到默认认证端点）               │
│    2. 认证 → 获取 token, cookies, pod              │
│    3. 购买 → 获取许可证                             │
│    4. 下载信息 → 获取 CDN URL + SINFs + 元数据     │
│    5. 版本列表/查询                                 │
│                                                    │
│  通过 WebSocket 上的 Wisp 协议进行 TLS 1.3 加密    │
└──────────────────────┬─────────────────────────────┘
                       │ Wisp 多路复用 TCP（服务器无法读取）
┌─ 服务器（Wisp 代理） ┴─────────────────────────────┐
│  Wisp 服务器（@mercuryworkshop/wisp-js）在 /wisp/  │
│  → 多路复用 TCP 中继（盲目隧道，不解密）             │
│                                                    │
│  Bag 代理：GET /api/bag?guid=<id>                  │
│    - 通过 HTTPS 获取 init.itunes.apple.com/bag.xml │
│    - 返回公开的 Apple 服务 URL（无凭证）            │
│                                                    │
│  客户端获取下载信息后：                              │
│    客户端 POST：{ downloadURL, sinfs, metadata }   │
│    - downloadURL = Apple CDN（公开，无需认证）      │
│    - sinfs = DRM 签名（base64）                    │
│    - iTunesMetadata = 应用元数据 plist（base64）   │
│                                                    │
│  服务器从 CDN 下载 IPA，注入 SINFs +               │
│  iTunesMetadata，存储编译后的 IPA，通过             │
│  公开安装 URL（itms-services manifest）提供服务    │
└────────────────────────────────────────────────────┘
```

**关键不变量**：服务器**永远无法看到** Apple 凭证。所有 Apple TLS 在浏览器端通过 libcurl.js WASM（Mbed TLS 1.3）终止。服务器仅接收公开的 CDN URL 和非秘密元数据用于 IPA 编译。Bag 代理（`/api/bag`）仅返回公开的 Apple 服务 URL — 没有任何凭证通过它。

## 参考实现

位于 `references/ApplePackage/` 的 Swift 参考是 Apple 协议行为的事实标准：

- 字段映射（iTunes API → Software 类型）使用 Swift `CodingKeys`
- 认证流程、bag 端点、pod 路由、错误代码
- 进行协议更改时务必查阅参考实现

### iTunes API 字段映射

后端（`backend/src/routes/search.ts`）将原始 iTunes API 字段映射到我们的 `Software` 类型，与 `references/ApplePackage/Sources/ApplePackage/Models/Software.swift` 中的 Swift CodingKeys 匹配：

| iTunes 字段                   | Software 字段 |
| ----------------------------- | ------------- |
| `trackId`                     | `id`          |
| `bundleId`                    | `bundleID`    |
| `trackName`                   | `name`        |
| `artworkUrl512`               | `artworkUrl`  |
| `currentVersionReleaseDate`   | `releaseDate` |

其他所有字段（`version`, `price`, `artistName`, `sellerName`, `description`, `averageUserRating`, `userRatingCount`, `screenshotUrls`, `minimumOsVersion`, `fileSizeBytes`, `releaseNotes`, `formattedPrice`, `primaryGenreName`）保持原名。

后端在发送到前端之前还会从 iTunes 包装器 `{ resultCount, results }` 中提取 `results` 数组。

## 每账户设备标识符

设备标识符是**每账户**的，而非全局的：

- 在创建账户时通过 `generateDeviceId()` 生成为 12 个随机十六进制字符（6 字节）
- 登录时可编辑，认证后不可变
- 作为 `deviceIdentifier` 存储在 IndexedDB 的 `Account` 对象上
- 传递给所有 Apple 协议调用（认证、购买、下载、版本列表）

## 基于 Pod 的主机路由

认证后，Apple 返回一个 `pod` 头部：

- Store API：`p{pod}-buy.itunes.apple.com`（默认：`p25-buy.itunes.apple.com`）
- Purchase API：`p{pod}-buy.itunes.apple.com`（默认：`buy.itunes.apple.com`）
- Pod 存储在 Account 对象上并用于所有后续 API 调用
- 函数：`frontend/src/apple/config.ts` 中的 `storeAPIHost(pod?)` 和 `purchaseAPIHost(pod?)`

## 动态主机验证（后端）

Wisp 服务器通过 `backend/src/services/wsProxy.ts` 中的 `hostname_whitelist` 验证目标主机：

- `auth.itunes.apple.com` — bag 解析的认证端点
- `buy.itunes.apple.com` — 购买端点
- `init.itunes.apple.com` — bag 端点
- `/^p\d+-buy\.itunes\.apple\.com$/` — 基于 pod 的主机
- 端口仅限 `443`
- 直接 IP 目标被阻止（`allow_direct_ip = false`）
- 环回 IP 目标被阻止（`allow_loopback_ips = false`）
- 允许私有/保留的已解析 IP（`allow_private_ips = true`）用于 Docker/OrbStack DNS 转换，同时主机名白名单仍是主要控制手段

## Bag 代理（后端）

后端通过 Node.js 原生 HTTPS 使用 `GET /api/bag?guid=<deviceId>` 代理 bag 端点。它发送与 Configurator 兼容的请求头（`User-Agent`, `Accept: application/xml`）。Bag 响应是公开数据（Apple 服务 URL）— 不涉及任何凭证。详见 `backend/src/routes/bag.ts`。

## 后端

- Express + `@mercuryworkshop/wisp-js` 用于 HTTP 和 Wisp 代理
- ESM 模块（package.json 中的 `"type": "module"`）
- 开发使用 `tsx`，生产构建使用 `tsc`
- SINF 注入器还处理 IPA 根目录的可选 `iTunesMetadata.plist` 注入
- `init.itunes.apple.com` 的 Bag 代理

### 后端共享工具

- `backend/src/utils/route.ts` — 共享 Express 路由助手（`getIdParam`, `requireAccountHash`, `verifyTaskOwnership`）
- `backend/src/config.ts` — 集中常量（`MAX_DOWNLOAD_SIZE`, `DOWNLOAD_TIMEOUT_MS`, `BAG_TIMEOUT_MS`, `BAG_MAX_BYTES`, `MIN_ACCOUNT_HASH_LENGTH`）和环境变量配置（通过 `UNSAFE_DANGEROUSLY_DISABLE_HTTPS_REDIRECT` 的 `disableHttpsRedirect`）

## 前端

- React 19, React Router 7, Zustand 状态管理
- Tailwind CSS 4 样式
- Vite 构建工具
- IndexedDB 凭证存储（通过 `idb`）
- `libcurl.js`（WASM）用于浏览器端通过 Mbed TLS 的 TLS 1.3 — 通过 Wisp 协议连接
- `frontend/src/apple/request.ts` 中的 `appleRequest()` 包装 `libcurl.fetch` 用于所有 Apple API 调用并强制使用 HTTP/1.1（`_libcurl_http_version: 1.1`）
- Bag 端点（`frontend/src/apple/bag.ts`）使用后端代理（`/api/bag`），当 `authenticateAccount` 缺失或 bag 获取失败时回退到 `https://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/authenticate`
- 认证（`frontend/src/apple/authenticate.ts`）解析 bag 端点，然后通过 URL 查询参数操作设置 `guid` 以避免重复/格式错误的查询参数
- Plist 构建/解析（`frontend/src/apple/plist.ts`）使用原生 XML 构建器和浏览器原生 `DOMParser`
- Cookie 助手（`frontend/src/apple/cookies.ts`）— `extractAndMergeCookies(rawHeaders, existingCookies)` 替代了所有 Apple 协议文件中重复的提取和合并模式

### 前端共享组件（`components/common/`）

- **Alert** — `<Alert type="error|success|warning">` 用于状态消息（替代内联 alert div）
- **Modal** — `<Modal open={bool} onClose={fn} title={string}>` 用于对话框覆盖层
- **Spinner** — 按钮的内联 SVG 加载旋转器
- **CountrySelect** — 基于 optgroup 的国家下拉菜单，包含"可用地区" + "所有地区"
- **AppIcon** — 3 种尺寸（40/56/80px），圆角，字母回退
- **Badge** — 颜色编码的状态药丸
- **ProgressBar** — 灰色轨道，蓝色填充，百分比标签
- **GlobalDownloadNotifier** — 下载状态变化的浮动通知
- **ToastContainer** — Toast 消息容器
- **icons** — Sidebar、MobileNav 和 MobileHeader 使用的共享 SVG 图标组件：
  - `HomeIcon`, `AccountsIcon`, `SearchIcon`, `DownloadsIcon`, `SettingsIcon`（导航）
  - `SunIcon`, `MoonIcon`, `SystemIcon`（主题切换）

### 前端共享工具（`utils/`）

- `utils/error.ts` — `getErrorMessage(e, fallback)` 用于标准化的 catch 块错误提取
- `utils/crypto.ts` — AES-GCM 加密/解密用于账户导出/导入
- `utils/account.ts` — `accountHash()`, `accountStoreCountry()`, `firstAccountCountry()`

### 导入顺序约定

1. React / 库导入（`useState`, `useNavigate`, `useTranslation`）
2. 布局组件（`PageContainer`）
3. 通用组件（`AppIcon`, `Alert`, `Spinner`, `Modal`, `CountrySelect`）
4. 同一功能文件夹内的兄弟组件（例如 `Download/` 内的 `DownloadItem`）
5. Hooks / stores（`useAccounts`, `useSettingsStore`）
6. Apple 协议 / API 模块（`authenticate`, `purchaseApp`, `apiPost`）
7. 工具（`accountHash`, `getErrorMessage`）
8. 配置（`countryCodeMap`, `storeIdToCountry`）
9. 类型（`type Software`）

**强制执行**：每个 PR 必须验证导入顺序。常见错误：

- 将 hooks/stores 放在布局/通用组件之前
- 将配置放在工具之前
- 将类型导入放在中间而不是最后

## 安全模型

### 账户哈希是公开的

`accountHash` 是账户标识符（DSID、Apple ID 或 email）的 SHA-256 哈希。它被视为**公开、非秘密数据** — 它标识哪个账户拥有下载但不授予任何特权访问权限。没有身份验证与之绑定。这是设计使然：服务器是一个盲目代理，不管理用户会话。

**Salt 支持**：前端支持通过 `VITE_ACCOUNT_HASH_SALT` 环境变量进行可选加盐。设置时，哈希计算为 `SHA-256(identifier + ":" + salt)` 以防止彩虹表攻击和跨实例枚举。如果未设置，则回退到纯哈希以保持向后兼容性。

### 可信来源

- **Apple API 响应**（bag XML、iTunes 搜索结果、`customerMessage` 字段）被视为可信内容。除了 React 文本渲染提供的之外，不应用额外的清理（不使用 `dangerouslySetInnerHTML`）。
- IPA 下载期间的 **Apple CDN 重定向**是可信的。初始 URL 针对 `*.apple.com` 进行验证，并遵循来自 Apple CDN 基础设施（例如 Akamai）的重定向目标。响应正文保存到磁盘 — 永远不会反射回请求者。

### 浏览器作为安全边界

存储在 IndexedDB 中的凭证（密码、`passwordToken`、cookies）受浏览器的同源策略保护。对它们进行静态加密将是安全剧场 — 解密密钥也会存在于 JS 中。威胁模型假设浏览器环境是可信的；如果攻击者拥有 XSS，无论静态加密如何，他们都可以泄露凭证。

### 后端不反射请求头

设置端点（`/api/settings`）绝不能在其响应正文中反射请求头（`x-forwarded-host`、`host` 等）。仅使用服务器端值（`config.*`、`process.uptime()`）。

## 错误处理

- 早期返回以减少嵌套
- 异步操作的 `try/catch`
- Express 错误中间件用于集中处理
- 类型安全的错误响应

### Apple 协议错误代码

- `2034` / `2042`：Token 过期 — 需要重新认证
- `customerMessage === 'Your password has changed.'`：密码 token 无效
- `action.url` 以 `termsPage` 结尾：需要接受条款（抛出带 URL 的错误）

## 测试

### 单元测试

```bash
cd backend && npx vitest run    # Node 环境
cd frontend && npx vitest run   # jsdom 环境配合 fake-indexeddb
```

### E2E 测试（Playwright）

```bash
cd e2e && pnpm test                            # 本地（需要端口 8080 上的 Docker）
docker compose --profile test run --rm playwright  # 基于 Docker
bash e2e/docker-test.sh                        # 完整流程：构建 + 测试 + 零信任验证
```

E2E 测试从 `./fixtures` 导入而不是 `@playwright/test`。

WebSocket 代理测试使用 `location.host` 动态派生 URL，因此它们在本地（`localhost:8080`）和 Docker（`asspp:8080`）中都能工作。

真实账户 Docker 验证（2026-02-22）：通过 Wisp 认证成功，后端日志仅包含连接/流元数据（无 Apple 凭证、密码 tokens 或 cookies）。

E2E 测试涵盖：

- Wisp 代理（接受 /wisp/ WebSocket，拒绝非 wisp 路径）
- 添加账户流程（设备 ID 字段、随机化按钮、认证）
- 账户详情（设备 ID、pod 显示）
- 设置页面（无全局设备 ID 部分）
- 按 bundle ID 搜索/查询（验证 iTunes 字段映射）
- 下载 API（iTunesMetadata 支持、向后兼容性）

### 测试账户

测试凭证存储在环境变量（`TEST_EMAIL`、`TEST_PASSWORD`、`TEST_DEVICE_ID`、`TEST_BUNDLE_ID`）中，绝不能提交到仓库。

## 部署

```bash
docker compose up --build -d   # 构建并在端口 8080 上运行
```

单个容器同时提供 Express 后端和 Vite 构建的 React SPA。SPA 路由通过为非 API 路径提供 `index.html` 来处理。

### Docker E2E 测试

`compose.yml` 在 `test` profile 下包含一个 `playwright` 服务：

```bash
docker compose --profile test run --rm playwright
```

这在官方的 `mcr.microsoft.com/playwright` 镜像内运行 Playwright，通过 Docker 内部 DNS（`http://asspp:8080`）连接到应用容器。`asspp` 服务有一个健康检查，因此测试容器会等待应用就绪。

`e2e/docker-test.sh` 脚本自动化完整流程：构建、测试，并通过扫描后端日志查找凭证泄露来验证零信任。

## 界面设计系统

### 意图

**谁**：在 App Store 之外管理 Apple 应用下载的开发者和高级用户 — 侧载 IPA、管理多个 Apple ID、跟踪许可证。技术受众，可能与终端或 Xcode 一起运行此工具。

**任务**：认证 Apple 账户 → 搜索应用 → 获取许可证 → 下载/编译 IPA → 安装。

**感觉**：一个锋利的实用工具。像包管理器一样精确，像 Apple 开发者工具一样清晰。自信、安静、功能性强。不俏皮，不企业化。

### 设计令牌

- **主强调色**：`blue-600` / `blue-700`（悬停）— 信任 + 系统权威，呼应 Apple 开发者工具
- **背景**：`gray-50`（应用），`white`（卡片/表面）
- **文本**：`gray-900`（主要），`gray-600`（次要），`gray-400`（第三级）
- **边框**：`gray-200`（默认），`gray-300`（悬停）— 谨慎使用，优先使用背景着色进行包含
- **状态徽章**：柔和色调 — `green`（已完成），`blue`（下载中），`yellow`（已暂停），`purple`（注入中），`red`（失败），`gray`（待处理）
- **警报**：`red-50`/`red-700`（错误），`amber-50`/`amber-700`（警告），`green-50`/`green-700`（成功）

### 排版

- 系统字体栈（Inter / SF Pro 回退）
- 字重比例：`500`（中等，主力），`600`（半粗，仅用于页面标题和关键标签）。避免在正文中使用 `700`。
- 尺寸比例：`xs`（12px），`sm`（14px），`base`（16px），`lg`（18px），`xl`（20px），`2xl`（24px）

### 间距

- 基本单位：`4px`
- 一致的垂直节奏：章节内 `space-y-4`，章节间 `space-y-6`
- 页面内边距：`px-4 sm:px-6`，`py-6`
- 容器：`max-w-5xl`（1024px）

### 深度与表面

- 单一海拔：`gray-50` 背景上的白色卡片
- 无阴影。仅在服务于功能的地方使用边框（表单输入、分隔线、交互边界）
- 圆角：卡片 `rounded-lg`（8px），输入/按钮 `rounded-md`（6px），徽章 `rounded-full`
- 优先使用背景着色（`gray-50` → `gray-100`）而非边框进行视觉包含

### 布局

- 桌面：固定侧边栏（240px / `w-60`）+ 可滚动主要内容
- 移动：底部标签栏带安全区域内边距
- 断点：`md:`（768px）用于侧边栏 ↔ 底部导航切换
- 页面结构：`PageContainer` 带标题 + 可选操作按钮，然后是内容

### 组件模式

- **按钮**：主要（`bg-blue-600 text-white`），次要（`border border-gray-300 text-gray-700`），危险（`text-red-600 border-red-300`）
- **输入**：`rounded-md border-gray-300 focus:border-blue-500 focus:ring-1 focus:ring-blue-500`
- **卡片**：白色背景，`border border-gray-200 rounded-lg`，无阴影
- **徽章**：颜色编码药丸（`rounded-full px-2 py-0.5 text-xs font-medium`）
- **ProgressBar**：灰色轨道，蓝色填充，百分比标签
- **AppIcon**：3 种尺寸（40/56/80px），圆角，字母回退
- **导航激活状态**：`bg-blue-50 text-blue-700`（侧边栏），`text-blue-600`（移动）

## 前端清理规则

这些规则防止合并 PR 后代码库变得混乱。在每次更改时强制执行它们。

### `transition-colors` 使用策略

**问题**：静态容器（卡片、章节、警报、徽章）上的 `transition-colors` 会导致在暗黑模式下加载页面时出现明显的颜色闪烁 — 元素短暂以浅色渲染然后过渡到深色。

**规则**：仅在用户交互时改变颜色的**交互元素**上使用 `transition-colors`：

- 按钮（悬停状态）
- 链接（悬停状态）
- 表单输入和选择框（焦点状态）
- 导航项（悬停/激活状态）

**永远不要在以下元素上使用 `transition-colors`**：

- 卡片容器（`bg-white dark:bg-gray-900 rounded-lg border ...`）
- 章节包装器（带背景的 `<section>`）
- 警报/警告横幅（使用 `<Alert>` 组件）
- 徽章药丸
- ProgressBar 轨道
- Modal 容器
- AppIcon 回退容器
- 空状态占位符容器

**例外**：布局 chrome（Sidebar、MobileNav、MobileHeader、PageContainer）可以保留 `transition-colors duration-200` 以实现平滑的主题切换动画，因为这些在导航之间持续存在。

### 共享图标

所有导航和主题图标都位于 `components/common/icons.tsx`。当 Sidebar、MobileNav 或 MobileHeader 需要图标时，从那里导入。永远不要内联重复图标 SVG 组件。

### 导入顺序验证

在合并任何前端 PR 之前，验证每个更改文件中的导入是否遵循约定：

```
1. React / 库导入
2. 布局组件
3. 通用组件
4. 兄弟组件（同一功能文件夹）
5. Hooks / stores
6. Apple 协议 / API 模块
7. 工具
8. 配置
9. 类型（始终最后）
```

### 空状态容器

空状态（当列表没有项目时显示）使用一致的模式：

- `border-2 border-dashed`（不是实线边框）
- `bg-gray-50 dark:bg-gray-900/30` 背景
- 无 `transition-colors`（移除以防止暗黑模式闪烁）
- 白色圆圈中的居中图标、标题、描述、可选 CTA 按钮

### 暗黑模式颜色配对

始终一致地配对浅色和深色变体：

- **主要文本**：`text-gray-900 dark:text-white`
- **次要文本**：`text-gray-600 dark:text-gray-400` 或 `text-gray-500 dark:text-gray-400`
- **第三级文本**：`text-gray-400 dark:text-gray-500`
- **卡片背景**：`bg-white dark:bg-gray-900`
- **页面背景**：`bg-gray-50 dark:bg-gray-950`
- **卡片边框**：`border-gray-200 dark:border-gray-800`
- **输入边框**：`border-gray-300 dark:border-gray-700`

### 代码重复预防

当相同的 UI 模式出现在 3+ 组件中时，将其提取到 `components/common/`。当前共享组件：

- `Alert`, `Modal`, `Spinner`, `CountrySelect`, `AppIcon`, `Badge`, `ProgressBar`, `icons`

添加新的通用组件时，相应更新此 AGENTS.md 文件。

**重复模式的样式常量**：对于在单个组件内复用的复杂 className 字符串（例如表单输入），将它们提取为文件顶部的常量。这确保了一致性并使未来更新更容易。示例：

``tsx
const INPUT_CLASS_NAME = "block w-full rounded-md border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-800 px-3 py-2 text-base text-gray-900 dark:text-white focus:border-blue-500 focus:ring-1 focus:ring-blue-500 disabled:bg-gray-50 dark:disabled:bg-gray-800/50 disabled:text-gray-500 transition-colors";

// 用法：
<input className={INPUT_CLASS_NAME} />
```

注意：`transition-colors` 允许在交互元素（输入、按钮）上使用，但绝不能用于静态容器。

### 认证的 API 下载

**问题**：普通的 `<a href="/api/...">` 标签和 `window.open("/api/...")` 进行常规浏览器导航，无法携带自定义 HTTP 头。当设置 `ACCESS_PASSWORD` 时，`accessAuth` 中间件需要 `X-Access-Token` 头，因此这些请求会因 401 失败。

**规则**：永远不要对需要认证的 `/api/` 端点使用 `<a href>` 或 `window.open`。而是使用 `api/client.ts` 中带 `authHeaders()` 的 `fetch()`，然后通过 blob URL 触发下载：

``tsx
const res = await fetch(url, { headers: authHeaders() });
const blob = await res.blob();
const blobUrl = URL.createObjectURL(blob);
const a = document.createElement("a");
a.href = blobUrl;
a.download = filename;
a.click();
URL.revokeObjectURL(blobUrl);
```

**例外**：后端显式跳过认证的路由（`/auth/*`, `/install/*`）可以使用普通链接 — 例如，`itms-services://` 安装 URL 没问题，因为 `/install/*` 是公开的。
