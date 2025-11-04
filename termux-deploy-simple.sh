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

# 5. 下载项目文件（修复tmp目录问题）
echo "📦 下载项目文件..."

# 使用项目目录内的临时目录，而不是/tmp
TEMP_DIR="$PROJECT_DIR/temp_download_$$"
mkdir -p "$TEMP_DIR"

# 下载GitHub项目
if command -v wget &> /dev/null; then
    wget -q -O "$TEMP_DIR/project.tar.gz" "https://github.com/iudd/termux-mcp-server/archive/main.tar.gz"
elif command -v curl &> /dev/null; then
    curl -sL -o "$TEMP_DIR/project.tar.gz" "https://github.com/iudd/termux-mcp-server/archive/main.tar.gz"
else
    echo "❌ 无法找到wget或curl命令，请检查网络连接"
    exit 1
fi

# 解压项目文件
if tar -xzf "$TEMP_DIR/project.tar.gz" --strip-components=1; then
    echo "✅ 项目文件下载解压成功"
else
    echo "❌ 项目文件解压失败"
    exit 1
fi

# 清理临时文件
rm -rf "$TEMP_DIR"

# 检查必要文件
if [ ! -f "src/server.js" ] || [ ! -f "package.json" ]; then
    echo "❌ 项目文件结构不完整，缺少必要文件"
    echo "当前目录内容："
    ls -la
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
pm2 delete termux-mcp-server 2>/dev/null || true
pm2 start src/server.js --name "termux-mcp-server" --env production

# 11. 保存PM2配置
pm2 save

# 12. 等待服务启动
echo "⏳ 等待服务启动..."
sleep 5

# 13. 获取IP地址
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

# 14. 健康检查
echo "🔍 正在检查服务状态..."
if curl -s http://localhost:3001/health >/dev/null 2>&1; then
    echo "✅ 服务运行正常"
else
    echo "⚠️ 服务正在启动中，请稍等片刻"
fi

echo ""
echo "🔧 管理命令:"
echo "├─ 查看状态: pm2 status"
echo "├─ 查看日志: pm2 logs termux-mcp-server"
echo "├─ 重启服务: pm2 restart termux-mcp-server"
echo "└─ 停止服务: pm2 stop termux-mcp-server"
echo ""
echo "💡 小贴士:"
echo "• 首次启动可能需要几分钟，请耐心等待"
echo "• 可以通过WiFi IP从同一网络下的其他设备访问"
echo ""