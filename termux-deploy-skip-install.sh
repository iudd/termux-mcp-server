#!/data/data/com.termux/files/usr/bin/bash

# Termux MCP Server 快速启动脚本
# 跳过依赖安装，适用于依赖已经安装的情况

set -e

PROJECT_DIR="$HOME/termux-mcp-server"
REPO_URL="https://github.com/iudd/termux-mcp-server.git"
TEMP_DIR="$PROJECT_DIR/temp-download-$$"

echo "=== Termux MCP Server 快速启动脚本 ==="

# 第1步：停止现有进程
echo "[INFO] 第1步: 停止现有进程..."
pm2 delete termux-mcp-server 2>/dev/null || echo "未找到现有PM2进程"
killall node 2>/dev/null || echo "未找到运行的node进程"

# 第2步：下载最新代码
echo "[INFO] 第2步: 下载最新代码..."
cd "$TEMP_DIR"
wget -q --no-check-certificate -O server.zip "$REPO_URL/archive/main.zip" || {
    echo "[ERROR] 下载失败"
    exit 1
}

# 第3步：解压并更新
echo "[INFO] 第3步: 更新项目文件..."
unzip -q server.zip 2>/dev/null || tar -xzf server.zip 2>/dev/null || {
    echo "[ERROR] 解压失败"
    exit 1
}

# 备份旧的node_modules
if [ -d "$PROJECT_DIR/node_modules" ]; then
    echo "[INFO] 备份现有依赖..."
    mv "$PROJECT_DIR/node_modules" "$PROJECT_DIR/node_modules.backup"
fi

# 复制新文件
cp -r termux-mcp-server-main/* "$PROJECT_DIR/" 2>/dev/null || {
    echo "[ERROR] 文件复制失败"
    exit 1
}

# 恢复依赖
if [ -d "$PROJECT_DIR/node_modules.backup" ]; then
    echo "[INFO] 恢复依赖..."
    mv "$PROJECT_DIR/node_modules.backup" "$PROJECT_DIR/node_modules"
fi

# 清理临时文件
cd "$HOME"
rm -rf "$TEMP_DIR"

echo "[SUCCESS] 项目文件更新完成"

# 第4步：启动服务器（跳过安装）
echo "[INFO] 第4步: 启动服务器..."
cd "$PROJECT_DIR"

# 检查依赖
if [ ! -d "node_modules" ]; then
    echo "[WARNING] 未检测到依赖，正在安装..."
    npm install
else
    echo "[SUCCESS] 依赖已存在，跳过安装"
fi

# 使用PM2启动
pm2 start ecosystem.config.js --name termux-mcp-server

# 检查启动状态
sleep 3
if pm2 list | grep -q "termux-mcp-server.*online"; then
    echo "[SUCCESS] ✅ 服务器启动成功！"
    echo ""
    echo "📋 当前状态:"
    pm2 list
    echo ""
    echo "🌐 访问地址: http://localhost:3000"
    echo "🔧 可用工具: 4个"
    echo ""
    echo "📝 测试命令:"
    echo "curl http://localhost:3000/"
    echo "curl http://localhost:3000/api/mcp/tools"
else
    echo "[ERROR] ❌ 服务器启动失败"
    echo "日志:"
    pm2 logs termux-mcp-server --lines 10
fi