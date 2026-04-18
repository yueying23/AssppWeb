#!/bin/bash

# ==========================================
# ASSPP Web - 构建脚本
# 将前端和后端构建产物输出到 app/ 目录
# ==========================================

set -e  # 遇到错误立即退出

# 获取脚本所在目录 (scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 获取项目根目录 (scripts/ 的上一级)
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
# 源码目录
SRC_DIR="$PROJECT_ROOT/src"
# 输出目录 (项目根目录下的 app/)
APP_DIR="$PROJECT_ROOT/app"

echo "🔨 开始构建 ASSPP Web..."
echo "📂 项目根目录: $PROJECT_ROOT"
echo "📂 源码目录: $SRC_DIR"
echo "📂 输出目录: $APP_DIR"
echo ""

# ==========================================
# 环境检查
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 环境检查..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 检查 Node.js 版本
if ! command -v node &> /dev/null; then
    echo "❌ 错误: 未找到 Node.js，请先安装 Node.js 20+"
    exit 1
fi

NODE_VERSION=$(node --version)
echo "📌 Node.js 版本: $NODE_VERSION"

# 检查 npm 版本
NPM_VERSION=$(npm --version)
echo "📌 npm 版本: $NPM_VERSION"

# 验证最低版本要求 (Node.js 20+)
NODE_MAJOR=$(echo $NODE_VERSION | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_MAJOR" -lt 20 ]; then
    echo "❌ 错误: 需要 Node.js 20 或更高版本，当前版本: $NODE_VERSION"
    exit 1
fi

echo "✅ 环境检查通过"
echo ""

# ==========================================
# 1. 构建前端
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 步骤 1/3: 构建前端..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$SRC_DIR/frontend"

if [ ! -d "node_modules" ]; then
    echo "📥 安装前端依赖..."
    npm ci --frozen-lockfile
fi

# --- 新增：交互式获取 Salt ---
# 如果环境变量中未设置，则提示用户输入
if [ -z "$VITE_ACCOUNT_HASH_SALT" ]; then
    echo "🔒 安全配置: VITE_ACCOUNT_HASH_SALT (用于账户哈希加盐)"
    echo "   💡 建议设置一个随机字符串以增强安全性（防止彩虹表攻击）"
    echo "   ⚠️  留空将使用无盐哈希（仅用于开发或兼容旧数据）"
    read -p "   请输入 Salt (直接回车跳过): " INPUT_SALT
    
    if [ -n "$INPUT_SALT" ]; then
        export VITE_ACCOUNT_HASH_SALT="$INPUT_SALT"
        echo "   ✅ Salt 已设置"
    else
        echo "   ⚠️  未设置 Salt，将使用默认无盐模式"
    fi
else
    echo "   ✅ 检测到环境变量 VITE_ACCOUNT_HASH_SALT 已设置"
fi
# ---------------------------

echo "🏗️  构建前端..."
echo "   💡 当前 Salt 状态: ${VITE_ACCOUNT_HASH_SALT:-未设置 (无盐)}"
npm run build

echo "✅ 前端构建完成"
echo ""

# ==========================================
# 2. 构建后端
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 步骤 2/3: 构建后端..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$SRC_DIR/backend"

if [ ! -d "node_modules" ]; then
    echo "📥 安装后端依赖..."
    npm ci --frozen-lockfile
fi

echo "🏗️  构建后端..."
npm run build

echo "✅ 后端构建完成"
echo ""

# ==========================================
# 3. 组装应用
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 步骤 3/3: 组装应用到 app/ 目录..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 确保输出目录存在
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# 创建目录结构
mkdir -p dist
mkdir -p public
mkdir -p node_modules

# 复制后端构建产物
echo "📋 复制后端文件..."
cp -r "$SRC_DIR/backend/dist/"* dist/
cp "$SRC_DIR/backend/package.json" .

# 复制前端构建产物
echo "📋 复制前端文件..."
cp -r "$SRC_DIR/frontend/dist/"* public/

# 复制后端依赖（生产环境）
echo "📋 复制后端依赖..."
if [ -d "$SRC_DIR/backend/node_modules" ]; then
    cp -r "$SRC_DIR/backend/node_modules/"* node_modules/
fi

echo ""
echo "✅ 应用组装完成"
echo ""

# ==========================================
# 显示结果
# ==========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 构建成功！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📂 应用目录结构:"
echo "  app/"
echo "  ├── dist/           # 后端编译后的代码"
echo "  ├── public/         # 前端静态文件"
echo "  ├── node_modules/   # 后端依赖"
echo "  ├── package.json    # 项目配置"
echo "  └── logs/           # 日志目录（运行时创建）"
echo ""
echo "🚀 启动应用:"
echo "  cd $PROJECT_ROOT"
echo "  ./scripts/start.sh"
echo ""
echo "⚙️  配置应用:"
echo "  编辑 .env 文件或设置环境变量"
echo "  或使用交互式配置: ./scripts/start.sh -i"
echo ""