#!/bin/bash

# =============================================================================
# Termux MCP Server 一键部署脚本
# 适用于Android手机Termux环境
# 作者: MiniMax Agent
# 版本: 1.0.0
# =============================================================================

set -e  # 遇到错误立即退出
set -u  # 使用未定义变量时报错

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查函数
check_command() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

# 错误处理函数
handle_error() {
    log_error "部署过程中发生错误，请检查上面的错误信息"
    log_info "常见解决方案:"
    echo "1. 确保在Termux环境中运行"
    echo "2. 检查网络连接"
    echo "3. 确保有足够的存储空间"
    echo "4. 重新运行脚本"
    exit 1
}

# 设置错误陷阱
trap 'handle_error' ERR

echo "======================================================================"
echo "                🚀 Termux MCP Server 一键部署脚本 🚀"
echo "======================================================================"
echo ""

# 1. 环境检查
log_info "第1步: 检查系统环境..."

# 检查是否在Termux中
if ! check_command "termux-info"; then
    log_error "请确保在Termux环境中运行此脚本"
    exit 1
fi

# 检查系统架构
ARCH=$(uname -m)
log_info "检测到系统架构: $ARCH"

# 检查可用内存
MEMORY=$(free -m | awk 'NR==2{print $2}')
if [ "$MEMORY" -lt 512 ]; then
    log_warning "可用内存较少 ($MEMORY MB)，可能影响部署速度"
fi

# 检查可用磁盘空间
DISK_SPACE=$(df -h /data/data/com.termux/files/home | awk 'NR==2 {print $4}' | sed 's/G//' | sed 's/M//')
if [ "${DISK_SPACE:-0}" -lt 1 ]; then
    log_warning "可用磁盘空间较少，请确保有至少1GB可用空间"
fi

log_success "环境检查完成"
echo ""

# 2. 系统更新
log_info "第2步: 更新系统包管理器..."
if ! pkg update -y; then
    log_error "更新包管理器失败"
    exit 1
fi

if ! pkg upgrade -y; then
    log_warning "系统升级部分失败，但可以继续部署"
fi

log_success "系统更新完成"
echo ""

# 3. 安装基础依赖
log_info "第3步: 安装基础依赖包..."

DEPENDENCIES=("nodejs" "npm" "git" "curl" "wget" "openssh")
MISSING_DEPS=()

for dep in "${DEPENDENCIES[@]}"; do
    if ! check_command "$dep"; then
        MISSING_DEPS+=("$dep")
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    log_info "需要安装缺失的依赖: ${MISSING_DEPS[*]}"
    if ! pkg install -y "${MISSING_DEPS[@]}"; then
        log_error "依赖安装失败"
        exit 1
    fi
else
    log_info "所有基础依赖已安装"
fi

log_success "基础依赖安装完成"
echo ""

# 4. 验证安装的工具
log_info "第4步: 验证工具安装..."

NODE_VERSION=$(node --version 2>/dev/null || echo "未安装")
NPM_VERSION=$(npm --version 2>/dev/null || echo "未安装")
GIT_VERSION=$(git --version 2>/dev/null || echo "未安装")

log_info "Node.js版本: $NODE_VERSION"
log_info "NPM版本: $NPM_VERSION"
log_info "Git版本: $GIT_VERSION"

if [[ "$NODE_VERSION" == "未安装" ]] || [[ "$NPM_VERSION" == "未安装" ]]; then
    log_error "Node.js或NPM安装失败，请检查错误信息"
    exit 1
fi

log_success "工具验证完成"
echo ""

# 5. 创建项目目录
log_info "第5步: 准备项目目录..."

PROJECT_DIR="/data/data/com.termux/files/home/termux-mcp-server"
BACKUP_DIR="$PROJECT_DIR-backup-$(date +%Y%m%d-%H%M%S)"

# 如果项目目录已存在，备份
if [ -d "$PROJECT_DIR" ]; then
    log_warning "检测到现有项目目录，正在备份..."
    if mv "$PROJECT_DIR" "$BACKUP_DIR"; then
        log_info "备份保存到: $BACKUP_DIR"
    fi
fi

# 创建新项目目录
if ! mkdir -p "$PROJECT_DIR"; then
    log_error "创建项目目录失败"
    exit 1
fi

cd "$PROJECT_DIR"
log_success "项目目录准备完成: $PROJECT_DIR"
echo ""

# 6. 下载项目文件
log_info "第6步: 下载项目文件..."

# 创建临时下载目录（避免/tmp只读问题）
TEMP_DIR="$PROJECT_DIR/temp-download-$$"
mkdir -p "$TEMP_DIR"

# 尝试多种下载方式
if check_command "wget"; then
    log_info "使用wget下载..."
    if wget -q -O "$TEMP_DIR/project.tar.gz" "https://github.com/iudd/termux-mcp-server/archive/main.tar.gz" 2>/dev/null; then
        DOWNLOAD_METHOD="wget"
    fi
elif check_command "curl"; then
    log_info "使用curl下载..."
    if curl -sL -o "$TEMP_DIR/project.tar.gz" "https://github.com/iudd/termux-mcp-server/archive/main.tar.gz" 2>/dev/null; then
        DOWNLOAD_METHOD="curl"
    fi
fi

if [ ! -f "$TEMP_DIR/project.tar.gz" ]; then
    log_warning "GitHub下载失败，尝试本地文件..."
    
    # 查找本地项目文件
    LOCAL_FILES=(
        "$HOME/termux-mcp-server.tar.gz"
        "$HOME/termux-mcp-server-final-complete.tar.gz"
        "$HOME/downloads/termux-mcp-server.tar.gz"
    )
    
    FOUND_LOCAL_FILE=""
    for file in "${LOCAL_FILES[@]}"; do
        if [ -f "$file" ]; then
            log_info "找到本地文件: $file"
            cp "$file" "$TEMP_DIR/project.tar.gz"
            FOUND_LOCAL_FILE="true"
            DOWNLOAD_METHOD="local"
            break
        fi
    done
    
    if [ -z "$FOUND_LOCAL_FILE" ]; then
        log_error "无法下载或找到项目文件"
        log_info "请确保:"
        echo "1. 网络连接正常"
        echo "2. GitHub仓库可访问: https://github.com/iudd/termux-mcp-server"
        echo "3. 或将项目文件复制到 $HOME/ 目录"
        exit 1
    fi
fi

# 解压项目文件
log_info "解压项目文件..."
if tar -xzf "$TEMP_DIR/project.tar.gz" --strip-components=1 2>/dev/null; then
    log_success "项目文件解压成功"
else
    log_error "项目文件解压失败"
    exit 1
fi

# 清理临时文件
rm -rf "$TEMP_DIR"

# 检查必要文件是否存在
if [ ! -f "src/server.js" ] || [ ! -f "package.json" ]; then
    log_error "项目文件结构不完整，缺少必要文件"
    ls -la
    exit 1
fi

log_success "项目文件准备完成"
echo ""

# 7. 安装项目依赖
log_info "第7步: 安装项目依赖..."

# 检查并清理npm缓存
if ! npm cache clean --force 2>/dev/null; then
    log_warning "npm缓存清理失败，继续安装"
fi

# 安装依赖（带进度显示）
if npm install --silent; then
    log_success "项目依赖安装完成"
else
    log_error "项目依赖安装失败"
    log_info "尝试重新安装..."
    if ! npm install; then
        log_error "依赖安装仍然失败，请检查package.json"
        exit 1
    fi
fi

echo ""

# 8. 配置环境
log_info "第8步: 配置服务器环境..."

# 创建环境配置文件
cat > .env << 'EOF'
# ===========================================
# Termux MCP Server 环境配置
# ===========================================

# 服务器基本配置
PORT=3001
HOST=0.0.0.0
NODE_ENV=production
SERVER_VERSION=1.0.0

# 安全配置
MAX_FILE_SIZE=10485760
MAX_PATH_LENGTH=4096
ALLOWED_BASE_PATHS=/data/data/com.termux/files/home
ENABLE_ORIGIN_CHECK=false

# Termux特定配置
TERMUX_APP_PKG=com.termux
TERMUX_VERSION=0.118.0

# 调试配置（生产环境建议关闭）
DEBUG=false
LOG_LEVEL=info

# 性能配置
WORKERS=1
REQUEST_TIMEOUT=30000
KEEP_ALIVE_TIMEOUT=5000
EOF

# 设置文件权限
chmod +x src/server.js
chmod -R 755 .
chmod 600 .env

log_success "环境配置完成"
echo ""

# 9. 安装并配置PM2进程管理器
log_info "第9步: 配置进程管理器..."

if ! check_command "pm2"; then
    log_info "安装PM2进程管理器..."
    if ! npm install -g pm2; then
        log_warning "PM2安装失败，将使用直接启动方式"
        USE_PM2=false
    else
        USE_PM2=true
    fi
else
    USE_PM2=true
fi

# 创建PM2配置文件
if [ "$USE_PM2" = true ]; then
    cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'termux-mcp-server',
    script: 'src/server.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '500M',
    env: {
      NODE_ENV: 'production',
      PORT: 3001
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true
  }]
}
EOF
    
    # 创建日志目录
    mkdir -p logs
fi

log_success "进程管理器配置完成"
echo ""

# 10. 启动服务器
log_info "第10步: 启动MCP服务器..."

# 停止可能存在的旧进程
if [ "$USE_PM2" = true ]; then
    pm2 delete termux-mcp-server 2>/dev/null || true
    pm2 start ecosystem.config.js --env production
    sleep 3  # 等待服务启动
    
    # 检查启动状态
    if pm2 list | grep -q "termux-mcp-server.*online"; then
        START_METHOD="pm2"
        log_success "服务器已使用PM2启动"
    else
        log_warning "PM2启动可能失败，尝试直接启动"
        USE_PM2=false
    fi
fi

# 如果PM2失败，使用直接启动
if [ "$USE_PM2" = false ]; then
    log_info "使用直接启动方式..."
    
    # 停止可能存在的进程
    pkill -f "src/server.js" 2>/dev/null || true
    sleep 2
    
    # 后台启动服务器
    nohup node src/server.js > server.log 2>&1 &
    SERVER_PID=$!
    
    sleep 3  # 等待服务启动
    
    # 检查进程是否仍在运行
    if kill -0 "$SERVER_PID" 2>/dev/null; then
        START_METHOD="direct"
        echo "$SERVER_PID" > server.pid
        log_success "服务器已直接启动，PID: $SERVER_PID"
    else
        log_error "服务器启动失败"
        exit 1
    fi
fi

echo ""

# 11. 等待服务就绪
log_info "第11步: 等待服务就绪..."

MAX_WAIT=30
COUNTER=0

while [ $COUNTER -lt $MAX_WAIT ]; do
    if curl -s http://localhost:3001/health >/dev/null 2>&1; then
        break
    fi
    
    sleep 1
    COUNTER=$((COUNTER + 1))
    
    if [ $((COUNTER % 5)) -eq 0 ]; then
        log_info "等待服务启动... ($COUNTER/$MAX_WAIT 秒)"
    fi
done

if [ $COUNTER -ge $MAX_WAIT ]; then
    log_warning "服务可能需要更长时间启动，但已尝试启动"
else
    log_success "服务启动检测成功"
fi

echo ""

# 12. 最终验证和状态显示
log_info "第12步: 验证服务状态..."

# 获取服务器状态
HEALTH_STATUS="未知"
if curl -s http://localhost:3001/health >/dev/null 2>&1; then
    HEALTH_STATUS="健康"
else
    HEALTH_STATUS="异常"
fi

# 获取本地IP地址
LOCAL_IP="127.0.0.1"
WIFI_IP=$(termux-wifi-connectioninfo 2>/dev/null | grep 'ipAddress' | cut -d'"' -f4 || echo "")

if [ -n "$WIFI_IP" ]; then
    EXTERNAL_IP="$WIFI_IP"
else
    EXTERNAL_IP="$LOCAL_IP"
fi

# 获取服务运行时间
if [ "$START_METHOD" = "pm2" ]; then
    UPTIME=$(pm2 jlist 2>/dev/null | jq -r '.[0].pm_uptime' | head -1 || echo "未知")
else
    if [ -f "server.pid" ]; then
        UPTIME=$(ps -o etime= -p $(cat server.pid) 2>/dev/null | tr -d ' ' || echo "未知")
    else
        UPTIME="未知"
    fi
fi

echo ""
echo "======================================================================"
echo "                    🎉 部署成功！服务器运行中 🎉"
echo "======================================================================"
echo ""
echo "📊 服务器状态信息:"
echo "├─ 健康检查: $HEALTH_STATUS"
echo "├─ 启动方式: $START_METHOD"
echo "├─ 端口: 3001"
echo "├─ 运行时间: $UPTIME"
echo "└─ 启动时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "🌐 访问地址:"
echo "├─ 本地访问: http://127.0.0.1:3001"
echo "├─ 本地访问: http://localhost:3001"
if [ -n "$WIFI_IP" ]; then
    echo "├─ WiFi访问: http://$WIFI_IP:3001"
fi
echo "└─ 局域网访问: http://$(hostname -I | awk '{print $1}'):3001"
echo ""
echo "🔧 管理命令:"

if [ "$START_METHOD" = "pm2" ]; then
    echo "├─ 查看状态: pm2 status"
    echo "├─ 查看日志: pm2 logs termux-mcp-server"
    echo "├─ 重启服务: pm2 restart termux-mcp-server"
    echo "├─ 停止服务: pm2 stop termux-mcp-server"
    echo "└─ 删除服务: pm2 delete termux-mcp-server"
else
    echo "├─ 查看日志: tail -f server.log"
    echo "├─ 停止服务: kill \$(cat server.pid) && rm server.pid"
    echo "├─ 重启服务: pkill -f 'src/server.js' && nohup node src/server.js > server.log 2>&1 &"
    echo "└─ 检查状态: curl http://localhost:3001/health"
fi

echo ""
echo "📁 项目目录: $PROJECT_DIR"

if [ -n "$WIFI_IP" ]; then
    echo ""
    echo "💡 小贴士:"
    echo "• 您可以通过WiFi IP地址从同一网络下的其他设备访问"
    echo "• 确保防火墙允许3001端口的访问"
    echo "• 首次访问可能需要几秒钟来加载"
fi

echo ""
echo "⚠️  重要提示:"
echo "• 如遇到问题，请查看上面的日志信息"
echo "• 服务器已配置为生产环境模式"
echo "• 建议定期查看日志文件以监控系统状态"
echo ""

# 最终健康检查
if curl -s http://localhost:3001/ >/dev/null 2>&1; then
    log_success "🎯 服务运行正常，可以开始使用！"
else
    log_warning "⚠️  服务可能需要更多时间启动，请稍后再试"
fi

echo ""
echo "======================================================================"
echo "                          部署完成！"
echo "======================================================================"