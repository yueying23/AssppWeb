#!/bin/bash

# ==========================================
# 启动脚本 for ASSPP Web
# 支持多种配置方式：
# 1. 命令行参数: ./scripts/start.sh --port 3000
# 2. 环境变量: PORT=3000 ./scripts/start.sh
# 3. 加载 .env 文件: ./scripts/start.sh --load-env
# 4. 交互式配置: ./scripts/start.sh --interactive
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
  --cleanup-days <天数>      自动清理旧数据的天数 (默认: 0/禁用)
  --cleanup-max-mb <大小>    触发清理的最大目录大小 MB (默认: 0/禁用)
  --max-download-mb <大小>   最大允许下载文件大小 MB (默认: 0/禁用)
  --download-threads <数量>  并发下载线程数 (默认: 8)
  --disable-https-redirect   禁用 HTTPS 重定向 (默认: false)
  --load-env, -l             【推荐】从 .env 文件加载配置 (自动处理格式问题)
  --interactive, -i          交互式配置向导
  --save-env, -s             将当前配置保存到 .env 文件
  --help, -h                 显示此帮助信息

示例:
  ./scripts/start.sh --load-env                     # 从 .env 加载并启动
  ./scripts/start.sh --load-env --port 9000         # 从 .env 加载，但覆盖端口为 9000
  ./scripts/start.sh -i                             # 交互式配置

环境变量:
  PORT, DATA_DIR, ACCESS_PASSWORD, PUBLIC_BASE_URL
  AUTO_CLEANUP_DAYS, AUTO_CLEANUP_MAX_MB, MAX_DOWNLOAD_MB, DOWNLOAD_THREADS
  UNSAFE_DANGEROUSLY_DISABLE_HTTPS_REDIRECT
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
    
    # 公共URL
    read -p "🌐 公共基础URL (留空表示无): " input_url
    if [ -n "$input_url" ]; then
        export PUBLIC_BASE_URL="$input_url"
    fi

    # 自动清理天数
    read -p "🗑️  自动清理旧数据天数 (0=禁用) [${AUTO_CLEANUP_DAYS:-0}]: " input_cleanup_days
    if [ -n "$input_cleanup_days" ]; then
        export AUTO_CLEANUP_DAYS="$input_cleanup_days"
    fi

    # 最大下载大小
    read -p "📥 最大下载文件大小 MB (0=禁用) [${MAX_DOWNLOAD_MB:-0}]: " input_max_dl
    if [ -n "$input_max_dl" ]; then
        export MAX_DOWNLOAD_MB="$input_max_dl"
    fi
    
    # HTTPS 重定向
    read -p "🔓 禁用 HTTPS 重定向? (true/false) [${UNSAFE_DANGEROUSLY_DISABLE_HTTPS_REDIRECT:-false}]: " input_https
    if [ -n "$input_https" ]; then
        export UNSAFE_DANGEROUSLY_DISABLE_HTTPS_REDIRECT="$input_https"
    fi
    
    # 安全盐值提示
    echo ""
    echo "💡 提示: VITE_ACCOUNT_HASH_SALT 通常在前端构建时设置"
    echo "   建议设置 VITE_ACCOUNT_HASH_SALT 以防止彩虹表攻击"
    echo "   如需修改，请重新运行 ./scripts/build.sh"
    
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
PUBLIC_BASE_URL=${PUBLIC_BASE_URL}
AUTO_CLEANUP_DAYS=${AUTO_CLEANUP_DAYS}
AUTO_CLEANUP_MAX_MB=${AUTO_CLEANUP_MAX_MB}
MAX_DOWNLOAD_MB=${MAX_DOWNLOAD_MB}
DOWNLOAD_THREADS=${DOWNLOAD_THREADS}
UNSAFE_DANGEROUSLY_DISABLE_HTTPS_REDIRECT=${UNSAFE_DANGEROUSLY_DISABLE_HTTPS_REDIRECT}
EOF
    
    echo "✅ 配置已保存到 .env 文件"
}

# ==========================================
# 函数：从 .env 文件加载配置 (鲁棒性增强版)
# ==========================================
load_env_file() {
    local env_file=".env"
    if [ ! -f "$env_file" ]; then
        echo "❌ 错误: 未找到 $env_file 文件"
        exit 1
    fi

    echo "📄 正在从 $env_file 加载配置..."
    
    # 核心逻辑：
    # 1. sed '1s/^\xEF\xBB\xBF//': 去除 Windows BOM 头
    # 2. sed 's/\r$//': 去除 Windows 换行符 \r
    # 3. grep -v '^#': 过滤注释行
    # 4. grep -v '^$': 过滤空行
    # 5. while read: 逐行读取并 export
    set -a
    while IFS= read -r line; do
        # 跳过注释和空行
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        
        # 导出变量
        export "$line"
    done < <(sed '1s/^\xEF\xBB\xBF//' "$env_file" | sed 's/\r$//' | grep -v '^#' | grep -v '^$')
    set +a
    
    echo "✅ 配置加载成功"
}

# ==========================================
# 解析命令行参数
# ==========================================
SAVE_ENV=false
INTERACTIVE=false
LOAD_ENV=false

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
        --cleanup-days)
            export AUTO_CLEANUP_DAYS="$2"
            shift 2
            ;;
        --cleanup-max-mb)
            export AUTO_CLEANUP_MAX_MB="$2"
            shift 2
            ;;
        --max-download-mb)
            export MAX_DOWNLOAD_MB="$2"
            shift 2
            ;;
        --download-threads)
            export DOWNLOAD_THREADS="$2"
            shift 2
            ;;
        --disable-https-redirect)
            export UNSAFE_DANGEROUSLY_DISABLE_HTTPS_REDIRECT="true"
            shift
            ;;
        --load-env|-l)
            LOAD_ENV=true
            shift
            ;;
        --interactive|-i)
            INTERACTIVE=true
            shift
            ;;
        --save-env|-s)
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
# 执行加载 .env (如果请求)
# ==========================================
if [ "$LOAD_ENV" = true ]; then
    load_env_file
fi

# ==========================================
# 执行交互式配置（如果请求）
# ==========================================
if [ "$INTERACTIVE" = true ]; then
    interactive_setup
fi

# ==========================================
# 配置环境变量（支持默认值，可被外部覆盖）
# 优先级: 命令行 > .env/交互 > 默认值
# ==========================================
export DATA_DIR="${DATA_DIR:-$HOME/asspp-data}"
export PORT="${PORT:-8080}"
export PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-}"
export ACCESS_PASSWORD="${ACCESS_PASSWORD:-}"

# 后端特定配置默认值
export AUTO_CLEANUP_DAYS="${AUTO_CLEANUP_DAYS:-0}"
export AUTO_CLEANUP_MAX_MB="${AUTO_CLEANUP_MAX_MB:-0}"
export MAX_DOWNLOAD_MB="${MAX_DOWNLOAD_MB:-0}"
export DOWNLOAD_THREADS="${DOWNLOAD_THREADS:-8}"
export UNSAFE_DANGEROUSLY_DISABLE_HTTPS_REDIRECT="${UNSAFE_DANGEROUSLY_DISABLE_HTTPS_REDIRECT:-false}"

# 构建信息
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
echo "🗑️ Cleanup  : Days=${AUTO_CLEANUP_DAYS}, MaxMB=${AUTO_CLEANUP_MAX_MB}"
echo "📥 Max DL   : ${MAX_DOWNLOAD_MB:-0} MB"
echo "🔓 HTTPS Redirect Disabled: ${UNSAFE_DANGEROUSLY_DISABLE_HTTPS_REDIRECT}"
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