module.exports = {
  apps: [{
    name: "carshub-frontend",
    script: "node_modules/.bin/next",
    args: "start -p 3000",
    cwd: "/home/ubuntu/nodeapp",
    watch: false,
    instances: 1,
    autorestart: true,
    max_restarts: 5,
    restart_delay: 3000,
    env: {
      NODE_ENV: "production",
      PORT: "3000",
      HOSTNAME: "0.0.0.0"
    }
  }]
};