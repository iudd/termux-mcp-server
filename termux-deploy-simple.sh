#!/bin/bash

# Termux MCP Server 快速部署脚本
# 适用于Android手机Termux环境

set -e

echo "🚀 开始部署 Termux MCP Server..."

# 1. 环境检查
if ! command -v termux-info &> /dev/null; then
    echo "❌ 请确保在Termux环境中运行此脚本"
    exit 1
fi

echo "📱 Termux环境确认OK"

# 2. 更新系统
echo "📦 更新系统..."
pkg update -y && pkg upgrade -y

# 3. 安装依赖
echo "🔧 安装依赖..."
pkg install -y nodejs npm git curl wget

# 4. 创建项目目录
PROJECT_DIR="$HOME/termux-mcp-server"
echo "📁 创建项目目录: $PROJECT_DIR"

if [ -d "$PROJECT_DIR" ]; then
    mv "$PROJECT_DIR" "$PROJECT_DIR-backup-$(date +%s)"
fi

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 5. 检查是否有本地项目文件
if [ -f "$HOME/termux-mcp-server-final-complete.tar.gz" ]; then
    echo "📦 发现本地项目文件，正在解压..."
    tar -xzf "$HOME/termux-mcp-server-final-complete.tar.gz"
elif [ -d "$HOME/termux-mcp-server" ]; then
    echo "📂 复制现有项目..."
    cp -r "$HOME/termux-mcp-server"/* .
else
    echo "❌ 请确保项目文件在正确位置: $HOME/termux-mcp-server-final-complete.tar.gz"
    exit 1
fi

# 6. 安装项目依赖
echo "📦 安装项目依赖..."
npm install

# 7. 配置环境
echo "⚙️ 配置环境..."
cat > .env << 'EOF'
PORT=3001
HOST=0.0.0.0
NODE_ENV=production
MAX_FILE_SIZE=10485760
ALLOWED_BASE_PATHS=/data/data/com.termux/files/home
ENABLE_ORIGIN_CHECK=false
EOF

# 8. 设置权限
chmod +x src/server.js

# 9. 安装PM2
echo "🔄 安装进程管理器..."
npm install -g pm2

# 10. 启动服务
echo "🚀 启动服务器..."
pm2 start src/server.js --name "termux-mcp-server" --env production

# 11. 保存PM2配置
pm2 save
pm2 startup

# 12. 获取IP地址
LOCAL_IP="127.0.0.1"
WIFI_IP=$(termux-wifi-connectioninfo 2>/dev/null | grep 'ipAddress' | cut -d'"' -f4 || echo "")

echo ""
echo "🎉 部署完成！"
echo ""
echo "📍 访问地址:"
echo "├─ 本地: http://$LOCAL_IP:3001"
if [ -n "$WIFI_IP" ]; then
    echo "├─ WiFi: http://$WIFI_IP:3001"
fi
echo ""
echo "🔧 管理命令:"
echo "├─ 查看状态: pm2 status"
echo "├─ 查看日志: pm2 logs termux-mcp-server"
echo "└─ 重启服务: pm2 restart termux-mcp-server"
echo ""
echo "⚠️  注意: 首次启动可能需要几分钟，请耐心等待"