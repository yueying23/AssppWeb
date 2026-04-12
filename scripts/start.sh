#!/bin/bash

# ==========================================
# 启动脚本 for ASSPP Web
# 支持三种配置方式：
# 1. 命令行参数: ./scripts/start.sh --port 3000 --data-dir /data
# 2. 环境变量: PORT=3000 ./scripts/start.sh
# 3. 交互式配置: ./scripts/start.sh --interactive
# ==========================================

# 获取脚本所在目录 (scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 获取项目根目录
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
# 切换到项目根目录，确保相对路径正确
cd "$PROJECT_ROOT"

# 应用目录 (构建产物所在地)
APP_DIR="$PROJECT_ROOT/app"

# ==========================================
# 函数：显示帮助信息
# ==========================================
show_help() {
    cat << EOF
📖 ASSPP Web 启动脚本使用说明

用法:
  ./scripts/start.sh [选项]

选项:
  --port <端口>              设置服务端口 (默认: 8080)
  --data-dir <目录>          设置数据目录 (默认: ~/asspp-data)
  --password <密码>          设置访问密码
  --public-url <URL>         设置公共基础 URL
  --interactive, -i          交互式配置向导
  --save-env                 将配置保存到 .env 文件
  --help, -h                 显示此帮助信息

示例:
  ./scripts/start.sh                              # 使用默认配置
  ./scripts/start.sh --port 3000                  # 自定义端口
  ./scripts/start.sh -i                           # 交互式配置
  PORT=3000 ./scripts/start.sh                    # 环境变量方式

环境变量:
  PORT, DATA_DIR, ACCESS_PASSWORD, VITE_ACCOUNT_HASH_SALT, PUBLIC_BASE_URL

EOF
}

# ==========================================
# 函数：交互式配置向导
# ==========================================
interactive_setup() {
    echo "🔧 交互式配置向导"
    echo "================================"
    echo ""
    
    # 数据目录
    read -p "📂 数据存放目录 [${DATA_DIR:-$HOME/asspp-data}]: " input_dir
    if [ -n "$input_dir" ]; then
        export DATA_DIR="$input_dir"
    fi
    
    # 端口
    read -p "🔌 服务端口 [${PORT:-8080}]: " input_port
    if [ -n "$input_port" ]; then
        export PORT="$input_port"
    fi
    
    # 访问密码
    read -p "🔒 访问密码 (留空表示无密码): " input_password
    if [ -n "$input_password" ]; then
        export ACCESS_PASSWORD="$input_password"
    fi
    
    # 安全盐值提示
    echo "💡 提示: VITE_ACCOUNT_HASH_SALT 通常在前端构建时设置"
    echo "   如需修改，请重新运行 ./scripts/build.sh 或设置环境变量后重启"
    
    # 公共URL
    read -p "🌐 公共基础URL (留空表示无): " input_url
    if [ -n "$input_url" ]; then
        export PUBLIC_BASE_URL="$input_url"
    fi
    
    echo ""
    echo "✅ 配置完成！"
}

# ==========================================
# 函数：保存配置到 .env 文件
# ==========================================
save_env_file() {
    cat > .env << EOF
# ASSPP Web Configuration
# Generated on $(date +"%Y-%m-%d %H:%M:%S")

DATA_DIR=${DATA_DIR}
PORT=${PORT}
ACCESS_PASSWORD=${ACCESS_PASSWORD}
VITE_ACCOUNT_HASH_SALT=${VITE_ACCOUNT_HASH_SALT}
PUBLIC_BASE_URL=${PUBLIC_BASE_URL}
EOF
    
    echo "✅ 配置已保存到 .env 文件"
    echo "💡 下次启动时可运行: source .env && ./scripts/start.sh"
}

# ==========================================
# 解析命令行参数
# ==========================================
SAVE_ENV=false
INTERACTIVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            export PORT="$2"
            shift 2
            ;;
        --data-dir)
            export DATA_DIR="$2"
            shift 2
            ;;
        --password)
            export ACCESS_PASSWORD="$2"
            shift 2
            ;;
        --public-url)
            export PUBLIC_BASE_URL="$2"
            shift 2
            ;;
        --interactive|-i)
            INTERACTIVE=true
            shift
            ;;
        --save-env)
            SAVE_ENV=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "❌ 未知参数: $1"
            echo "运行 './scripts/start.sh --help' 查看帮助"
            exit 1
            ;;
    esac
done

# ==========================================
# 执行交互式配置（如果请求）
# ==========================================
if [ "$INTERACTIVE" = true ]; then
    interactive_setup
fi

# ==========================================
# 配置环境变量（支持默认值，可被外部覆盖）
# ==========================================
export DATA_DIR="${DATA_DIR:-$HOME/asspp-data}"
export PORT="${PORT:-8080}"
export PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-}"
export ACCESS_PASSWORD="${ACCESS_PASSWORD:-}"
export VITE_ACCOUNT_HASH_SALT="${VITE_ACCOUNT_HASH_SALT:-}"
export BUILD_COMMIT="${BUILD_COMMIT:-manual-deploy}"
export BUILD_DATE="${BUILD_DATE:-$(date +"%Y-%m-%d %H:%M:%S")}"

# ==========================================
# 保存配置（如果请求）
# ==========================================
if [ "$SAVE_ENV" = true ]; then
    save_env_file
    echo ""
fi

# ==========================================
# 准备工作
# ==========================================
mkdir -p "$DATA_DIR"

# 检查构建产物是否存在
if [ ! -f "$APP_DIR/dist/index.js" ]; then
    echo "❌ 错误: 未找到构建产物 ($APP_DIR/dist/index.js)"
    echo "💡 请先运行: ./scripts/build.sh"
    exit 1
fi

echo "----------------------------------------"
echo "🚀 Starting ASSPP Web..."
echo "📂 Data Dir : $DATA_DIR"
echo "🔌 Port     : $PORT"
echo "🔒 Password : ${ACCESS_PASSWORD:-None}"
if [ -n "$VITE_ACCOUNT_HASH_SALT" ]; then
    echo "🛡️  Hash Salt: ✅ 已配置 (增强安全)"
else
    echo "⚠️  Hash Salt: ❌ 未配置 (使用默认哈希)"
    echo "   💡 建议设置 VITE_ACCOUNT_HASH_SALT 以防止彩虹表攻击"
fi
echo "----------------------------------------"

# ==========================================
# 停止已有进程（如果有）
# ==========================================
if [ -f app.pid ]; then
    OLD_PID=$(cat app.pid)
    if ps -p $OLD_PID > /dev/null 2>&1; then
        echo "🛑 停止旧进程 (PID: $OLD_PID)..."
        kill $OLD_PID
        sleep 2
        
        # 验证进程是否已停止
        if ps -p $OLD_PID > /dev/null 2>&1; then
            echo "⚠️  警告: 旧进程未能正常停止，尝试强制终止..."
            kill -9 $OLD_PID
            sleep 1
        fi
    fi
    rm -f app.pid
fi

# ==========================================
# 日志文件配置（按天分割）
# ==========================================
LOG_DIR="logs"
mkdir -p "$LOG_DIR"
LOG_DATE=$(date +"%Y-%m-%d")
LOG_FILE="$LOG_DIR/app-${LOG_DATE}.log"
LATEST_LOG_LINK="$LOG_DIR/latest.log"

# 创建最新日志的软链接（方便查看）
ln -sf "$LOG_FILE" "$LATEST_LOG_LINK"

echo "📝 日志文件: $LOG_FILE"
echo "🔗 最新日志: $LATEST_LOG_LINK"

# 清理旧日志（保留最近30天）
find "$LOG_DIR" -name "app-*.log" -type f -mtime +30 -delete 2>/dev/null

# ==========================================
# 启动应用 (后台运行)
# ==========================================
cd "$APP_DIR"
nohup node dist/index.js >> "$PROJECT_ROOT/$LOG_FILE" 2>&1 &

PID=$!
echo $PID > "$PROJECT_ROOT/app.pid"

echo "✅ 启动成功!"
echo "📄 日志目录: $PROJECT_ROOT/$LOG_DIR"
echo "🛑 停止命令: kill $(cat $PROJECT_ROOT/app.pid)"
echo ""
echo "等待 3 秒检查进程状态..."
sleep 3

if ps -p $PID > /dev/null; then
    echo "✅ 进程运行中 (PID: $PID)"
    echo "👉 查看今天日志: tail -f $PROJECT_ROOT/$LOG_FILE"
    echo "👉 查看最新日志: tail -f $PROJECT_ROOT/$LATEST_LOG_LINK"
else
    echo "❌ 进程启动失败! 请立即查看日志排查错误:"
    tail -n 20 "$PROJECT_ROOT/$LOG_FILE"
    exit 1
fi
