#!/data/data/com.termux/files/usr/bin/bash

# Termux MCP Server 优化一键部署脚本
# 智能检测依赖状态，跳过已安装的依赖，只在必要时安装

set -e

PROJECT_DIR="$HOME/termux-mcp-server"
REPO_URL="https://github.com/iudd/termux-mcp-server.git"
TEMP_DIR="$PROJECT_DIR/temp-download-$$"

echo "=== Termux MCP Server 优化一键部署脚本 ==="
echo "📦 智能检测，跳过已安装依赖"
echo ""

# 第1步：停止现有进程
echo "[INFO] 第1步: 停止现有进程..."
pm2 delete termux-mcp-server 2>/dev/null || echo "ℹ️  未找到现有PM2进程"
killall node 2>/dev/null || echo "ℹ️  未找到运行的node进程"

# 第2步：确保目录存在并初始化Git
echo "[INFO] 第2步: 初始化项目目录..."
if [ ! -d "$PROJECT_DIR" ]; then
    echo "📁 创建项目目录..."
    git clone "$REPO_URL" "$PROJECT_DIR"
else
    echo "📁 项目目录已存在，更新代码..."
    cd "$PROJECT_DIR"
    git pull origin main 2>/dev/null || echo "⚠️  Git拉取失败，尝试重新克隆..."
fi

# 第3步：下载更新代码（如果Git拉取失败）
if [ ! -d "$PROJECT_DIR/src" ] || [ ! -f "$PROJECT_DIR/package.json" ]; then
    echo "[INFO] 第3步: 下载最新项目文件..."
    cd "$TEMP_DIR"
    wget -q --no-check-certificate -O server.zip "$REPO_URL/archive/main.zip" || {
        echo "[ERROR] 下载失败"
        exit 1
    }
    
    unzip -q server.zip 2>/dev/null || tar -xzf server.zip 2>/dev/null || {
        echo "[ERROR] 解压失败"
        exit 1
    }
    
    # 备份现有的node_modules
    if [ -d "$PROJECT_DIR/node_modules" ]; then
        echo "💾 备份现有依赖..."
        mv "$PROJECT_DIR/node_modules" "$PROJECT_DIR/node_modules.backup"
    fi
    
    # 复制新文件
    cp -r termux-mcp-server-main/* "$PROJECT_DIR/" 2>/dev/null || {
        echo "[ERROR] 文件复制失败"
        exit 1
    }
    
    # 恢复依赖
    if [ -d "$PROJECT_DIR/node_modules.backup" ]; then
        echo "📥 恢复依赖..."
        mv "$PROJECT_DIR/node_modules.backup" "$PROJECT_DIR/node_modules"
    fi
    
    # 清理临时文件
    cd "$HOME"
    rm -rf "$TEMP_DIR"
    echo "[SUCCESS] 项目文件更新完成"
else
    echo "[SUCCESS] 项目文件检查通过"
fi

# 第4步：智能依赖检查和安装
echo "[INFO] 第4步: 智能依赖检查..."
cd "$PROJECT_DIR"

# 检查依赖是否存在且完整
if [ -d "node_modules" ] && [ -f "package-lock.json" ] && [ -s "package-lock.json" ]; then
    echo "✅ 检测到依赖已安装且完整"
    echo "📦 已安装包数量: $(ls node_modules | wc -l)"
    echo "🚀 跳过依赖安装，直接启动"
else
    echo "⚠️  依赖不完整或缺失，开始安装..."
    npm install --verbose
    echo "[SUCCESS] 依赖安装完成"
fi

# 第5步：启动服务器
echo "[INFO] 第5步: 启动MCP服务器..."
echo "🚀 使用PM2启动服务..."

# 确保PM2配置存在
if [ ! -f "ecosystem.config.js" ]; then
    echo "📄 创建PM2配置文件..."
    cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'termux-mcp-server',
    script: './src/server.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
};
EOF
fi

# 启动服务
pm2 start ecosystem.config.js --name termux-mcp-server

# 第6步：状态检查
echo "[INFO] 第6步: 服务状态检查..."
sleep 3

if pm2 list | grep -q "termux-mcp-server.*online"; then
    echo ""
    echo "🎉 === 部署成功！ ==="
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ 服务器状态: 运行中"
    echo "🌐 访问地址: http://localhost:3000"
    echo "🔧 可用工具: 4个"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📊 当前状态:"
    pm2 list
    echo ""
    echo "🧪 测试命令:"
    echo "curl http://localhost:3000/"
    echo "curl http://localhost:3000/api/mcp/tools"
    echo ""
    echo "📋 PM2管理命令:"
    echo "pm2 logs termux-mcp-server    # 查看日志"
    echo "pm2 restart termux-mcp-server # 重启服务"
    echo "pm2 delete termux-mcp-server  # 停止服务"
else
    echo ""
    echo "❌ === 启动失败 ==="
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔍 检查错误日志:"
    pm2 logs termux-mcp-server --lines 10
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

echo ""
echo "=== 脚本执行完成 ==="