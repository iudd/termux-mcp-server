// Configuration for Termux MCP Server

module.exports = {
  // Server Configuration
  port: process.env.PORT || 3000,
  host: process.env.HOST || '0.0.0.0',
  nodeEnv: process.env.NODE_ENV || 'production',
  version: '1.0.0',
  
  // Security Configuration
  allowedOrigins: process.env.ALLOWED_ORIGINS ? 
    process.env.ALLOWED_ORIGINS.split(',') : 
    [
      'http://localhost:3000',
      'http://127.0.0.1:3000',
      'http://localhost:8080',
      'http://127.0.0.1:8080'
    ],
  
  // Logging Configuration
  logLevel: process.env.LOG_LEVEL || 'info',
  logToFile: process.env.LOG_TO_FILE === 'true',
  logFile: process.env.LOG_FILE || 'logs/mcp-server.log',
  
  // MCP Protocol Configuration
  mcp: {
    maxRequestSize: '10mb',
    timeout: 30000, // 30 seconds
    maxTools: 100,
    toolTimeout: 15000, // 15 seconds per tool execution
  },
  
  // File System Configuration
  fs: {
    maxFileSize: '50mb',
    allowedPaths: process.env.ALLOWED_PATHS ? 
      process.env.ALLOWED_PATHS.split(',') : 
      [
        process.env.HOME || '/data/data/com.termux/files/home',
        '/storage/emulated/0',
        '/sdcard'
      ],
    restrictedPaths: [
      '/system',
      '/vendor',
      '/etc',
      '/proc',
      '/dev',
      '/sys'
    ]
  },
  
  // Process Management Configuration
  processes: {
    maxConcurrent: 10,
    killTimeout: 5000,
    maxOutput: 8192 // 8KB max output per process
  },
  
  // Network Configuration
  network: {
    pingTimeout: 5000,
    maxConnections: 50,
    timeout: 10000
  },
  
  // Termux-specific Configuration
  termux: {
    homePath: process.env.HOME || '/data/data/com.termux/files/home',
    storagePath: '/storage/emulated/0',
    packages: {
      maxOutput: 1024 * 1024 // 1MB max package list output
    }
  },
  
  // Development Configuration
  development: {
    corsEnabled: true,
    debugLogging: true,
    allowFileSystemAccess: true,
    allowProcessExecution: true
  },
  
  // Production Configuration
  production: {
    corsEnabled: true,
    debugLogging: false,
    allowFileSystemAccess: process.env.ALLOW_FS_ACCESS === 'true',
    allowProcessExecution: process.env.ALLOW_PROCESS_EXECUTION === 'true'
  }
};

// Environment-specific overrides
if (module.exports.nodeEnv === 'development') {
  module.exports = {
    ...module.exports,
    ...module.exports.development
  };
} else if (module.exports.nodeEnv === 'production') {
  module.exports = {
    ...module.exports,
    ...module.exports.production
  };
}