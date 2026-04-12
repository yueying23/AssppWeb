# 快速启动指南

## 🚀 5 分钟开始调试

### 步骤 1: 验证环境（首次使用）

按 `Ctrl+Shift+P` → 输入 `Tasks: Run Task` → 选择 **🔍 诊断开发环境**

预期输出：
```
=== Node.js 版本 ===
v22.x.x

=== npm 版本 ===
11.x.x

=== 后端依赖检查 ===
✅ tsx 已安装

=== 前端依赖检查 ===
✅ vite 已安装
```

如果看到 ❌，请先运行对应的安装任务。

---

### 步骤 2: 安装依赖（如未安装）

**方法一：使用任务（推荐）**
- `Ctrl+Shift+P` → `Tasks: Run Task` → **📥 安装所有依赖**

**方法二：手动安装**
```bash
# 后端
cd src/backend
npm install

# 前端
cd src/frontend
npm install
```

---

### 步骤 3: 启动调试

#### 选项 A: 全栈调试（推荐）

1. 按 `F5`
2. 在下拉菜单中选择 **🔥 全栈调试 (Full Stack)**
3. 等待终端显示：
   - 后端: `Server listening on port 8368`
   - 前端: `Local: http://localhost:5173/`
4. 浏览器自动打开，即可开始调试！

#### 选项 B: 单独调试后端

1. 按 `F5`
2. 选择 **🚀 后端调试 (Backend)**
3. 在 `src/backend/src/routes/*.ts` 中设置断点
4. 使用 Postman 或浏览器访问 API 触发断点

#### 选项 C: 单独调试前端

1. **先启动前端开发服务器**（必须）:
   ```bash
   cd src/frontend
   npm run dev
   ```
2. 按 `F5`
3. 选择 **🌐 前端调试 (Frontend - Chrome)**
4. 在 `src/frontend/src/components/**/*.tsx` 中设置断点
5. 在浏览器中操作触发断点

---

## 🎯 常用快捷键

| 操作 | Windows/Linux | Mac |
|------|--------------|-----|
| 启动调试 | `F5` | `F5` |
| 停止调试 | `Shift+F5` | `Shift+F5` |
| 重启调试 | `Ctrl+Shift+F5` | `Cmd+Shift+F5` |
| 切换断点 | `F9` | `F9` |
| 单步执行 | `F10` | `F10` |
| 进入函数 | `F11` | `F11` |
| 运行任务 | `Ctrl+Shift+P` | `Cmd+Shift+P` |

---

## 📝 调试示例

### 示例 1: 调试后端 API

1. 打开 `src/backend/src/routes/search.ts`
2. 在第 20 行点击行号左侧，设置红色断点
3. 按 `F5` 启动后端调试
4. 在浏览器中搜索应用
5. VS Code 会在断点处暂停，可查看变量、调用栈等

### 示例 2: 调试前端组件

1. 确保前端开发服务器正在运行
2. 打开 `src/frontend/src/components/Search/SearchPage.tsx`
3. 在 `handleSearch` 函数内设置断点
4. 按 `F5` 启动前端调试
5. 在浏览器中输入搜索关键词
6. VS Code 会暂停并显示当前状态

### 示例 3: 追踪完整请求链路

1. 按 `F5`，选择 **🔥 全栈调试 (Full Stack)**
2. 在后端 `search.ts` 和前端 `SearchPage.tsx` 都设置断点
3. 在浏览器中执行搜索
4. 先命中前端断点，继续执行后命中后端断点
5. 完整追踪数据流！

---

## ❓ 遇到问题？

查看 [README.md](README.md) 中的"常见问题与解决方案"部分。

主要问题速查：
- [后端调试无法启动](README.md#-问题-1-后端调试无法启动)
- [前端调试无法命中断点](README.md#-问题-2-前端调试无法命中断点)
- [端口冲突](README.md#-问题-3-端口冲突)
- [Docker 调试附加失败](README.md#-问题-4-docker-调试附加失败)

---

**💡 提示**: 将本文件加入书签，方便快速查阅！
