module.exports = {
  apps: [{
    name: 'termux-mcp-server',
    script: 'src/server.js',

    // Instance management
    instances: 1,
    exec_mode: 'fork',

    // Environment
    env_production: {
      NODE_ENV: 'production',
      PORT: 3001
    },
    env_development: {
      NODE_ENV: 'development',
      PORT: 3000
    },

    // Restart policy
    watch: false,
    ignore_watch: ['node_modules', 'logs', '*.log'],
    max_restarts: 10,
    min_uptime: '10s',
    max_memory_restart: '500M',

    // Logging
    log_file: 'logs/combined.log',
    out_file: 'logs/out.log',
    error_file: 'logs/error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    merge_logs: true,

    // Advanced
    autorestart: true,
    kill_timeout: 5000,
    listen_timeout: 3000,
    shutdown_with_message: true,

    // Health checks
    health_check_grace_period: 3000,
    health_check_fatal_exceptions: true,

    // Termux-specific settings
    cwd: process.cwd(),

    // Process management
    windowsHide: true,
    kill_signal: 'SIGTERM',
    restart_delay: 4000
  }]
};