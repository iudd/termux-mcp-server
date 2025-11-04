# Termux MCP Server 一键部署

专为Android手机Termux环境设计的MCP (Model Context Protocol) 服务器

## 快速部署

```bash
# 完整功能部署（推荐）
curl -sL https://raw.githubusercontent.com/iudd/termux-mcp-server/main/deploy-and-start.sh | bash

# 快速部署（简化版）
curl -sL https://raw.githubusercontent.com/iudd/termux-mcp-server/main/termux-deploy-simple.sh | bash
```

## 部署后访问

- 本地访问: http://127.0.0.1:3001
- WiFi访问: http://您的WiFi-IP:3001

## 管理命令

```bash
pm2 status     # 查看状态
pm2 logs termux-mcp-server  # 查看日志
pm2 restart termux-mcp-server  # 重启服务
```