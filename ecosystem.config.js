module.exports = {
  apps: [
    {
      name: 'apex-storefront',
      cwd: '/home/kyanfash/printexpress.com.eg',
      script: '.next/standalone/server.js',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '350M',
      node_args: '--max-old-space-size=256',
      env: {
        NODE_ENV: 'production',
        PORT: 2000,
        HOSTNAME: '127.0.0.1'
      },
      restart_delay: 3000,
      max_restarts: 10,
      min_uptime: '15s',
      kill_timeout: 4000
    },
    {
      name: 'apex-dashboard',
      cwd: '/home/kyanfash/admin.printexpress.com.eg',
      script: '.next/standalone/server.js',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '350M',
      node_args: '--max-old-space-size=256',
      env: {
        NODE_ENV: 'production',
        PORT: 2050,
        HOSTNAME: '127.0.0.1'
      },
      restart_delay: 3000,
      max_restarts: 10,
      min_uptime: '15s',
      kill_timeout: 4000
    }
  ]
};
