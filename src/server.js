const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

// Configuration
const config = require('./config');
const app = express();
const PORT = config.port || 3000;

// Middleware
app.use(helmet({
  contentSecurityPolicy: false,
  crossOriginEmbedderPolicy: false
}));
app.use(cors({
  origin: config.allowedOrigins || ['http://localhost:3000', 'http://127.0.0.1:3000'],
  credentials: true
}));
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(morgan('combined'));

// MCP Protocol Types and Handlers
class MCPProtocol {
  constructor() {
    this.tools = new Map();
    this.resources = new Map();
    this.prompts = new Map();
    this.initializeTools();
  }

  initializeTools() {
    // System Information Tool
    this.tools.set('get_system_info', {
      name: 'get_system_info',
      description: '获取系统信息',
      inputSchema: {
        type: 'object',
        properties: {
          detail_level: {
            type: 'string',
            enum: ['basic', 'detailed', 'full'],
            default: 'basic'
          }
        }
      }
    });

    // File Operations Tool
    this.tools.set('file_operations', {
      name: 'file_operations',
      description: '文件操作工具',
      inputSchema: {
        type: 'object',
        properties: {
          operation: {
            type: 'string',
            enum: ['read', 'write', 'list', 'delete', 'mkdir'],
            required: true
          },
          path: {
            type: 'string',
            required: true
          },
          content: {
            type: 'string'
          },
          recursive: {
            type: 'boolean',
            default: false
          }
        }
      }
    });

    // Process Management Tool
    this.tools.set('process_management', {
      name: 'process_management',
      description: '进程管理工具',
      inputSchema: {
        type: 'object',
        properties: {
          action: {
            type: 'string',
            enum: ['list', 'kill', 'start', 'status'],
            required: true
          },
          pid: {
            type: 'integer'
          },
          command: {
            type: 'string'
          },
          args: {
            type: 'array',
            items: { type: 'string' }
          }
        }
      }
    });

    // Network Information Tool
    this.tools.set('network_info', {
      name: 'network_info',
      description: '网络信息工具',
      inputSchema: {
        type: 'object',
        properties: {
          action: {
            type: 'string',
            enum: ['ping', 'ports', 'connections', 'interfaces'],
            required: true
          },
          target: {
            type: 'string'
          },
          port: {
            type: 'integer'
          }
        }
      }
    });
  }

  async handleToolCall(toolName, arguments_) {
    if (!this.tools.has(toolName)) {
      throw new Error(`Tool not found: ${toolName}`);
    }

    try {
      switch (toolName) {
        case 'get_system_info':
          return await this.getSystemInfo(arguments_);
        case 'file_operations':
          return await this.fileOperations(arguments_);
        case 'process_management':
          return await this.processManagement(arguments_);
        case 'network_info':
          return await this.networkInfo(arguments_);
        default:
          throw new Error(`Tool handler not implemented: ${toolName}`);
      }
    } catch (error) {
      return {
        success: false,
        error: error.message,
        tool: toolName
      };
    }
  }

  async getSystemInfo(options = {}) {
    const info = {
      platform: process.platform,
      nodeVersion: process.version,
      pid: process.pid,
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      cpuUsage: process.cpuUsage()
    };

    if (options.detail_level === 'detailed' || options.detail_level === 'full') {
      const os = require('os');
      info.os = {
        type: os.type(),
        release: os.release(),
        hostname: os.hostname(),
        cpus: os.cpus(),
        totalMemory: os.totalmem(),
        freeMemory: os.freemem()
      };
    }

    if (options.detail_level === 'full') {
      // Add Termux-specific information
      try {
        const { execSync } = require('child_process');
        info.termux = {
          version: '1.0.0',
          packages: execSync('pkg list-installed 2>/dev/null | wc -l').toString().trim()
        };
      } catch (error) {
        info.termux = { error: 'Unable to get Termux info' };
      }
    }

    return { success: true, data: info };
  }

  async fileOperations(options) {
    const { operation, path: filePath, content, recursive = false } = options;
    
    try {
      switch (operation) {
        case 'read':
          if (!fs.existsSync(filePath)) {
            throw new Error('File not found');
          }
          const readContent = fs.readFileSync(filePath, 'utf8');
          return { success: true, data: { content: readContent, size: readContent.length } };

        case 'write':
          if (!content) {
            throw new Error('Content is required for write operation');
          }
          const dir = path.dirname(filePath);
          if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
          }
          fs.writeFileSync(filePath, content);
          return { success: true, data: { message: 'File written successfully', path: filePath } };

        case 'list':
          if (!fs.existsSync(filePath)) {
            throw new Error('Directory not found');
          }
          const stats = fs.statSync(filePath);
          if (!stats.isDirectory()) {
            throw new Error('Path is not a directory');
          }
          const files = fs.readdirSync(filePath, { withFileTypes: true });
          const fileList = files.map(file => ({
            name: file.name,
            type: file.isDirectory() ? 'directory' : 'file',
            size: file.isFile() ? fs.statSync(path.join(filePath, file.name)).size : null
          }));
          return { success: true, data: { files: fileList } };

        case 'delete':
          if (fs.existsSync(filePath)) {
            if (fs.statSync(filePath).isDirectory()) {
              if (recursive) {
                fs.rmSync(filePath, { recursive: true, force: true });
              } else {
                throw new Error('Use recursive: true to delete directories');
              }
            } else {
              fs.unlinkSync(filePath);
            }
          }
          return { success: true, data: { message: 'File/directory deleted successfully' } };

        case 'mkdir':
          fs.mkdirSync(filePath, { recursive });
          return { success: true, data: { message: 'Directory created successfully', path: filePath } };

        default:
          throw new Error(`Unknown operation: ${operation}`);
      }
    } catch (error) {
      throw new Error(`File operation failed: ${error.message}`);
    }
  }

  async processManagement(options) {
    const { action, pid, command, args = [] } = options;
    
    try {
      switch (action) {
        case 'list':
          const { execSync } = require('child_process');
          const processList = execSync('ps aux').toString();
          return { success: true, data: { processes: processList } };

        case 'kill':
          if (!pid) {
            throw new Error('PID is required for kill operation');
          }
          const killResult = spawn('kill', [pid.toString()]);
          return { success: true, data: { message: `Process ${pid} terminated` } };

        case 'start':
          if (!command) {
            throw new Error('Command is required for start operation');
          }
          const process = spawn(command, args, {
            detached: true,
            stdio: 'ignore'
          });
          process.unref();
          return { success: true, data: { message: `Process started: ${command}`, pid: process.pid } };

        case 'status':
          if (!pid) {
            throw new Error('PID is required for status operation');
          }
          try {
            const { execSync } = require('child_process');
            const status = execSync(`ps -p ${pid} -o pid,ppid,cmd,etime,pcpu,pmem --no-headers`).toString();
            return { success: true, data: { status: status } };
          } catch (error) {
            return { success: true, data: { status: 'Process not found' } };
          }

        default:
          throw new Error(`Unknown action: ${action}`);
      }
    } catch (error) {
      throw new Error(`Process management failed: ${error.message}`);
    }
  }

  async networkInfo(options) {
    const { action, target, port } = options;
    
    try {
      const { execSync } = require('child_process');
      
      switch (action) {
        case 'ping':
          if (!target) {
            throw new Error('Target is required for ping operation');
          }
          const pingResult = execSync(`ping -c 4 ${target}`).toString();
          return { success: true, data: { ping_result: pingResult } };

        case 'ports':
          const portsResult = execSync('netstat -tulpn 2>/dev/null || ss -tulpn').toString();
          return { success: true, data: { ports: portsResult } };

        case 'connections':
          const connectionsResult = execSync('netstat -an 2>/dev/null || ss -an').toString();
          return { success: true, data: { connections: connectionsResult } };

        case 'interfaces':
          const interfacesResult = execSync('ip addr show 2>/dev/null || ifconfig -a').toString();
          return { success: true, data: { interfaces: interfacesResult } };

        default:
          throw new Error(`Unknown action: ${action}`);
      }
    } catch (error) {
      throw new Error(`Network info failed: ${error.message}`);
    }
  }

  getTools() {
    return Array.from(this.tools.values());
  }

  getToolSchema(toolName) {
    return this.tools.get(toolName);
  }
}

// Initialize MCP
const mcp = new MCPProtocol();

// Root endpoint for MCP clients
app.get('/', (req, res) => {
  res.json({
    name: 'Termux MCP Server',
    version: config.version || '1.0.0',
    description: 'MCP (Model Context Protocol) server running on Termux Android environment',
    endpoints: {
      health: '/health',
      tools: '/api/mcp/tools',
      call: '/api/mcp/call',
      status: '/api/status'
    },
    tools: mcp.getTools().length,
    timestamp: new Date().toISOString()
  });
});

// API Routes

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: config.version || '1.0.0'
  });
});

// MCP Protocol endpoints

// Get available tools
app.get('/api/mcp/tools', (req, res) => {
  res.json({
    tools: mcp.getTools(),
    count: mcp.getTools().length
  });
});

// Get tool schema
app.get('/api/mcp/tools/:toolName', (req, res) => {
  const { toolName } = req.params;
  const schema = mcp.getToolSchema(toolName);
  
  if (!schema) {
    return res.status(404).json({ error: `Tool not found: ${toolName}` });
  }
  
  res.json(schema);
});

// Call tool
app.post('/api/mcp/call', async (req, res) => {
  try {
    const { tool, arguments: args } = req.body;
    
    if (!tool) {
      return res.status(400).json({ error: 'Tool name is required' });
    }
    
    if (!args) {
      return res.status(400).json({ error: 'Arguments object is required' });
    }
    
    const result = await mcp.handleToolCall(tool, args);
    res.json(result);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Get server status
app.get('/api/status', (req, res) => {
  const status = {
    server: {
      status: 'running',
      uptime: process.uptime(),
      pid: process.pid,
      port: PORT
    },
    tools: {
      count: mcp.getTools().length,
      available: mcp.getTools().map(t => t.name)
    },
    system: {
      platform: process.platform,
      nodeVersion: process.version
    }
  };
  
  res.json(status);
});

// Serve static files if available
const publicDir = path.join(__dirname, '../public');
if (fs.existsSync(publicDir)) {
  app.use(express.static(publicDir));
}

// Error handling
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error',
    message: config.nodeEnv === 'development' ? err.message : undefined
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found',
    path: req.originalUrl
  });
});

// Start server
if (require.main === module) {
  const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`MCP Server running on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
    console.log(`API endpoints: http://localhost:${PORT}/api/`);
    console.log(`Available tools: ${mcp.getTools().length}`);
  });
  
  // Graceful shutdown
  process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    server.close(() => {
      console.log('Process terminated');
    });
  });
  
  process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down gracefully');
    server.close(() => {
      console.log('Process terminated');
    });
  });
}

module.exports = app;