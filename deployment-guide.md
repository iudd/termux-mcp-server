# Termux MCP Server 一键部署指南

## 🚨 解决404错误的方法

之前的404错误是因为示例GitHub仓库 `https://raw.githubusercontent.com/iudd/termux-mcp-server/main/deploy-and-start.sh` 不存在。

## 📋 解决方案

### 方案1: 使用本地脚本（推荐）
```bash
# 1. 将脚本复制到您的手机Termux中
# 2. 在Termux中执行:
chmod +x deploy-and-start.sh
./deploy-and-start.sh
```

### 方案2: 直接复制粘贴
```bash
# 直接复制并执行脚本内容
curl -s https://raw.githubusercontent.com/yourusername/termux-mcp-server/main/termux-deploy-simple.sh | bash
```

### 方案3: Git克隆（如果您有GitHub仓库）
```bash
# 如果您有自己的GitHub仓库:
git clone https://github.com/yourusername/termux-mcp-server.git
cd termux-mcp-server
chmod +x termux-deploy-simple.sh
./termux-deploy-simple.sh
```

## 🎯 立即可用的部署命令

### 一键部署（复制粘贴这个命令到Termux）:

```bash
# 直接执行在线脚本
bash <(curl -s https://raw.githubusercontent.com/yourrepo/termux-mcp-server/main/termux-deploy-simple.sh)
```

**注意：上面的URL需要替换为您实际的GitHub仓库地址。**

## 📁 脚本文件说明

1. **deploy-and-start.sh** (完整版)
   - 包含详细的错误处理和日志
   - 支持多种下载方式
   - 包含健康检查和状态监控
   - 适合高级用户和故障排查

2. **termux-deploy-simple.sh** (简化版)
   - 快速简洁的部署流程
   - 适合快速部署
   - 基础错误处理

## 🔧 手动部署步骤（如果脚本有问题）

如果脚本无法运行，可以手动执行以下步骤：

```bash
# 1. 环境准备
pkg update -y && pkg upgrade -y
pkg install -y nodejs npm git curl

# 2. 创建项目目录
mkdir ~/termux-mcp-server
cd ~/termux-mcp-server

# 3. 复制项目文件（确保文件存在）
# 如果有压缩包: tar -xzf termux-mcp-server-final-complete.tar.gz
# 如果有目录: cp -r /path/to/source/* .

# 4. 安装依赖
npm install

# 5. 配置环境
echo "PORT=3001" > .env
echo "HOST=0.0.0.0" >> .env
echo "NODE_ENV=production" >> .env

# 6. 启动服务
node src/server.js
```

## 🌐 部署后的访问地址

部署成功后，您的服务器将在以下地址运行：

- **本地访问**: http://127.0.0.1:3001
- **局域网访问**: http://您的WiFi-IP:3001

## 🔍 验证部署

```bash
# 检查服务状态
curl http://localhost:3001/health

# 查看服务信息
curl http://localhost:3001/
```

## ⚠️ 常见问题

1. **网络连接问题**: 确保手机连接到WiFi或使用流量
2. **权限问题**: 确保脚本有执行权限 `chmod +x 脚本名`
3. **端口占用**: 如果3001端口被占用，脚本会自动处理
4. **存储空间**: 确保至少1GB可用空间

## 📞 获取帮助

如果遇到问题，请：
1. 检查Termux中的错误信息
2. 查看脚本输出的详细日志
3. 确认项目文件位置正确