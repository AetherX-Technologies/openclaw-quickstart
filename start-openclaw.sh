#!/bin/zsh
# Start OpenClaw + claude-max-api proxy

# 1. Start claude-max-api proxy (unset CLAUDECODE to allow subprocess spawning)
echo "Starting claude-max-api proxy on :3456..."
pkill -f claude-max-api 2>/dev/null
sleep 1
nohup env -u CLAUDECODE claude-max-api > ~/claude-proxy.log 2>&1 &
echo "  PID $! — logs: ~/claude-proxy.log"

# Wait for proxy to be ready
sleep 3

# 2. Start OpenClaw gateway (if not already running as LaunchAgent)
echo "Starting OpenClaw gateway..."
openclaw gateway install --force > /dev/null 2>&1
echo "  logs: ~/.openclaw/logs/gateway.log"

# 3. Start browser relay (CDP relay for Chrome extension)
echo "Starting browser relay on :18792..."
openclaw browser start 2>/dev/null || true

echo ""
echo "Done. Dashboard: http://127.0.0.1:18789/"
echo "      Token:     $(openclaw config get gateway.auth.token 2>/dev/null)"
echo ""
echo "Chrome: click OpenClaw Browser Relay extension icon on any tab to attach."
