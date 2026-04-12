# VS Code 调试配置指南

本文档说明如何使用 `.vscode/` 目录中的配置文件进行高效开发调试。

## 🚨 常见问题与解决方案

### ❌ 问题 1: 后端调试无法启动

**症状**: 点击"🚀 后端调试 (Backend)"后没有任何反应，或提示找不到 `tsx` 命令。

**原因**: 后端依赖未安装。

**解决方案**:

1. **安装后端依赖**:
   ```bash
   cd src/backend
   npm install
   ```
   
   或在 VS Code 中：
   - 按 `Ctrl+Shift+P`
   - 输入 `Tasks: Run Task`
   - 选择 `📥 安装后端依赖`

2. **验证安装**:
   ```bash
   cd src/backend
   ls node_modules/.bin/tsx*  # Linux/Mac
   dir node_modules\.bin\tsx*  # Windows PowerShell
   ```

3. **重新启动调试**: 按 `F5` 再次尝试。

---

### ❌ 问题 2: 前端调试无法命中断点

**症状**: 浏览器已打开，但在 TypeScript 文件中设置的断点没有被命中。

**原因**: 前端开发服务器未启动，或源映射配置不正确。

**解决方案**:

1. **确保前端开发服务器正在运行**:
   ```bash
   cd src/frontend
   npm run dev
   ```
   
   看到类似输出表示成功：
   ```
   VITE v5.x.x  ready in xxx ms
   
   ➜  Local:   http://localhost:5173/
   ```

2. **检查浏览器 URL**: 确保访问的是 `http://localhost:5173`

3. **清除浏览器缓存**: 
   - Chrome: `Ctrl+Shift+R` 强制刷新
   - 或在 DevTools 中勾选 "Disable cache"

4. **重新启动调试会话**: 停止当前调试，重新按 `F5`。

---

### ❌ 问题 3: 端口冲突

**症状**: 后端启动失败，提示 `EADDRINUSE: address already in use :::8368`。

**解决方案**:

1. **查找占用端口的进程**:
   ```bash
   # Linux/Mac
   lsof -i :8368
   
   # Windows PowerShell
   netstat -ano | findstr :8368
   ```

2. **终止进程**:
   ```bash
   # Linux/Mac (替换 PID)
   kill -9 <PID>
   
   # Windows PowerShell (替换 PID)
   taskkill /F /PID <PID>
   ```

3. **或修改端口**: 在 `launch.json` 中更改 `"PORT": "8368"` 为其他端口。

---

### ❌ 问题 4: Docker 调试附加失败

**症状**: "🐳 附加到 Docker 容器" 配置无法连接。

**解决方案**:

1. **确保容器正在运行**:
   ```bash
   docker ps | grep asspp-web
   ```

2. **启用 Node.js 调试端口**: 在 `docker-compose.yml` 中添加：
   ```yaml
   environment:
     - NODE_OPTIONS=--inspect=0.0.0.0:9229
   ports:
     - "9229:9229"
   ```

3. **重启容器**:
   ```bash
   docker compose restart asspp-web
   ```

---

## 📁 配置文件说明

| 文件 | 用途 |
|------|------|
| `launch.json` | 调试启动配置（F5） |
| `tasks.json` | 开发任务快捷方式（Ctrl+Shift+P → Tasks: Run Task） |
| `extensions.json` | 推荐的 VS Code 扩展 |
| `settings.json` | 工作区编辑器设置 |

---

## 🚀 调试配置 (launch.json)

### 后端调试

**配置名称**: `🚀 后端调试 (Backend)`

- **功能**: 使用 `tsx` 直接运行 TypeScript 源码，支持热重载
- **断点**: 可在 `src/backend/src/**/*.ts` 文件中设置断点
- **环境变量**: 已预配置开发环境所需的 `JWT_SECRET`、`ACCESS_PASSWORD` 等
- **启动方式**: 
  1. 打开任意后端 TypeScript 文件
  2. 按 `F5` 或点击调试侧边栏的"运行和调试"
  3. 选择"🚀 后端调试 (Backend)"

### 前端调试

**配置名称**: `🌐 前端调试 (Frontend - Chrome)` 或 `🌐 前端调试 (Frontend - Edge)`

- **功能**: 附加到 Vite 开发服务器运行的浏览器实例
- **前提**: 需先手动启动前端开发服务器 (`cd src/frontend && npm run dev`)
- **断点**: 可在 `src/frontend/src/**/*.tsx` 文件中设置断点
- **启动方式**:
  1. 确保前端开发服务器正在运行
  2. 选择对应浏览器的调试配置
  3. 按 `F5` 启动调试会话

### 全栈联合调试

**配置名称**: `🔥 全栈调试 (Full Stack)`

- **功能**: 同时启动后端和前端调试器
- **优势**: 可以在前后端代码中同时设置断点，追踪完整请求链路
- **启动方式**: 在调试下拉菜单中选择"🔥 全栈调试 (Full Stack)"

### 测试调试

**配置名称**: 
- `🧪 后端测试 (Backend Tests)`
- `🧪 前端测试 (Frontend Tests)`

- **功能**: 以调试模式运行 Vitest 测试套件
- **断点**: 可在测试文件或源码中设置断点
- **启动方式**: 选择对应的测试配置并按 `F5`

### 构建与启动

**配置名称**:
- `📦 构建应用 (Build App)`
- `▶️ 启动应用 (Start App)`

- **功能**: 运行 `scripts/build.sh` 或 `scripts/start.sh`
- **用途**: 快速执行构建或启动脚本，无需切换到终端

---

## ⚡ 开发任务 (tasks.json)

通过 `Ctrl+Shift+P` → `Tasks: Run Task` 可以快速执行以下任务：

### 依赖管理

- **📥 安装所有依赖**: 依次安装前后端依赖（首次克隆项目后必做）
- **📥 安装后端依赖**: 仅安装后端依赖
- **📥 安装前端依赖**: 仅安装前端依赖

### 开发相关

- **🔥 启动全栈开发环境**: 并行启动前后端开发服务器
- **🚀 启动后端开发服务器**: 单独启动后端（端口 8080）
- **🌐 启动前端开发服务器**: 单独启动前端（端口 5173）

### 构建与部署

- **📦 构建应用**: 执行 `scripts/build.sh`，输出到 `app/` 目录
- **▶️ 启动应用（生产模式）**: 执行 `scripts/start.sh`，启动构建后的应用
- **🐳 Docker Compose 启动**: 构建并启动 Docker 容器
- **🐳 Docker Compose 停止**: 停止并移除 Docker 容器

### 测试

- **🧪 运行后端测试**: 执行后端单元测试
- **🧪 运行前端测试**: 执行前端单元测试
- **🧪 运行所有测试**: 依次执行前后端测试

### 维护

- **🧹 清理构建产物**: 删除 `app/dist`, `app/public`, `app/node_modules`

---

## 📦 推荐扩展 (extensions.json)

首次打开项目时，VS Code 会提示安装以下扩展：

### 核心扩展

- **ESLint** (`dbaeumer.vscode-eslint`): JavaScript/TypeScript 代码检查
- **Prettier** (`esbenp.prettier-vscode`): 代码格式化
- **Tailwind CSS IntelliSense** (`bradlc.vscode-tailwindcss`): Tailwind 类名自动补全

### React 开发

- **ES7+ React/Redux/React-Native snippets** (`dsznajder.es7-react-js-snippets`): React 代码片段

### 工具增强

- **Docker** (`ms-azuretools.vscode-docker`): Docker 容器管理
- **GitLens** (`eamodio.gitlens`): Git 历史和责任追踪
- **REST Client** (`humao.rest-client`): 直接在 VS Code 中测试 API

### 其他

- **Code Spell Checker** (`streetsidesoftware.code-spell-checker`): 拼写检查
- **Markdown All in One** (`yzhang.markdown-all-in-one`): Markdown 编辑增强

---

## ⚙️ 工作区设置 (settings.json)

### 关键配置项

#### 代码格式化

- **保存时自动格式化**: `editor.formatOnSave: true`
- **保存时自动修复 ESLint**: `source.fixAll.eslint`
- **Tab 大小**: 2 空格（符合项目规范）

#### 导入排序

- **自动组织导入**: `source.organizeImports` 在保存时执行
- **模块路径偏好**: 相对路径（`typescript.preferences.importModuleSpecifier`）

#### 文件监视优化

- **排除大型目录**: `node_modules`, `dist`, `logs` 等不会被监视，提升性能
- **搜索排除**: 相同目录在搜索时也会被排除

#### Terminal 配置

- **默认 Shell**: Git Bash（Windows）
- **原因**: 项目脚本使用 Bash 语法，PowerShell 可能不兼容

---

## 🎯 最佳实践

### 1. 首次设置项目

```bash
# 步骤 1: 安装所有依赖
Ctrl+Shift+P → Tasks: Run Task → 📥 安装所有依赖

# 步骤 2: 启动开发环境
Ctrl+Shift+P → Tasks: Run Task → 🔥 启动全栈开发环境

# 步骤 3: 开始调试
F5 → 选择 🔥 全栈调试 (Full Stack)
```

### 2. 日常开发流程

```bash
# 方法一：使用任务快捷方式
Ctrl+Shift+P → Tasks: Run Task → 🔥 启动全栈开发环境

# 方法二：手动启动
# Terminal 1
cd src/backend && npm run dev

# Terminal 2
cd src/frontend && npm run dev
```

### 3. 调试技巧

- **后端断点**: 在 `src/backend/src/routes/*.ts` 中设置断点，调试 API 逻辑
- **前端断点**: 在 `src/frontend/src/components/**/*.tsx` 中设置断点，调试 UI 交互
- **网络请求追踪**: 在浏览器 DevTools 的 Network 面板查看请求，配合后端断点定位问题

### 4. 测试驱动开发

```bash
# 运行单个测试文件（在终端）
cd src/backend
npx vitest run tests/routes.test.ts

# 或在 VS Code 中使用调试配置
选择 "🧪 后端测试 (Backend Tests)" 并按 F5
```

### 5. Docker 调试

```bash
# 启动 Docker 环境
docker compose up -d --build

# 查看日志
docker compose logs -f asspp-web

# 附加到容器
docker exec -it asspp-web sh
```

---

## ❓ 常见问题

### Q: 前端调试无法命中断点？

**A**: 确保：
1. 前端开发服务器正在运行 (`npm run dev`)
2. 浏览器 URL 是 `http://localhost:5173`
3. `launch.json` 中的 `webRoot` 路径正确

### Q: 后端调试启动失败？

**A**: 检查：
1. 是否已安装依赖 (`cd src/backend && npm install`)
2. 端口 8080 是否被占用
3. 环境变量 `JWT_SECRET` 是否已设置

### Q: 如何调试 Docker 容器内的代码？

**A**: 
1. 使用 `🐳 附加到 Docker 容器` 配置
2. 或在 `docker-compose.yml` 中启用 Node.js 调试端口：
   ```yaml
   ports:
     - "8080:8080"
     - "9229:9229"  # Node.js 调试端口
   environment:
     - NODE_OPTIONS=--inspect=0.0.0.0:9229
   ```

### Q: 如何自定义环境变量？

**A**: 
1. 复制 `.env.example` 为 `.env`
2. 修改所需变量
3. 重启开发服务器或 Docker 容器

---

## 🔗 相关文档

- [AGENTS.md](../AGENTS.md) - 项目开发规范（英文）
- [AGENTS-CN.md](../AGENTS-CN.md) - 项目开发规范（中文）
- [README.md](../README.md) - 项目介绍和快速开始

---

**💡 提示**: 如需添加新的调试配置或任务，请同步更新本文档。
