#!/usr/bin/env bash
# safe-gateway-restart.sh — Restart OpenClaw gateway with optional Claude Code auto-fix.
# Usage:
#   ./safe-gateway-restart.sh [reason]
#
# macOS version: uses launchctl instead of systemctl.

set -euo pipefail

REASON="${1:-manual restart}"
MAX_RETRIES="${SAFE_RESTART_MAX_RETRIES:-2}"
LAUNCH_LABEL="${OPENCLAW_GATEWAY_UNIT:-ai.openclaw.gateway}"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

LOG_DIR="${OPENCLAW_LOG_DIR:-$HOME/.openclaw/logs}"
ERR_LOG="${LOG_DIR}/gateway.err.log"

# Optional: Telegram notify
TELEGRAM_TARGET="${SAFE_RESTART_TELEGRAM_TARGET:-}"

find_claude() {
  local c
  c="$(command -v claude 2>/dev/null || true)"
  if [[ -n "$c" && -x "$c" ]]; then
    echo "$c"; return 0
  fi
  for candidate in "$HOME/.local/bin/claude" "$HOME/.claude/local/claude" /usr/local/bin/claude; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"; return 0
    fi
  done
  echo ""
}

notify() {
  local msg="$1"
  [[ -z "$TELEGRAM_TARGET" ]] && return 0
  local openclaw_bin
  openclaw_bin="${HOME}/.nvm/versions/node/v24.12.0/bin/openclaw"
  [[ -x "$openclaw_bin" ]] || openclaw_bin="$(command -v openclaw 2>/dev/null || true)"
  [[ -x "$openclaw_bin" ]] || return 0
  "$openclaw_bin" message send --channel telegram --target "$TELEGRAM_TARGET" --message "$msg" 2>/dev/null || true
}

check_gateway_errors() {
  local errors=""

  # Check error log for config/plugin errors
  if [[ -f "$ERR_LOG" ]]; then
    errors=$(tail -60 "$ERR_LOG" 2>/dev/null | grep -i "invalid config\|Config validation failed\|plugin.*not found\|ERROR.*plugin" | tail -10 || true)
  fi

  # Check if gateway is actually responding on its port
  local http_resp
  http_resp=$(curl -s --max-time 3 "http://127.0.0.1:${GATEWAY_PORT}/" 2>/dev/null | head -1 || true)
  if [[ -z "$http_resp" ]]; then
    errors="${errors}
[health-check] Gateway not responding on port ${GATEWAY_PORT}"
  fi

  echo "$errors"
}

do_restart() {
  echo "[$(date -u +%H:%M:%S)] Restarting gateway (reason: $REASON)…"
  launchctl kickstart -k "gui/$(id -u)/${LAUNCH_LABEL}" 2>/dev/null || true
  echo "[$(date -u +%H:%M:%S)] Waiting 6s for gateway to stabilize…"
  sleep 6
}

CLAUDE_CODE="$(find_claude)"
CLAUDE_TIMEOUT="${SAFE_RESTART_CLAUDE_TIMEOUT_SECS:-300}"

echo "=== Safe Gateway Restart (macOS) ==="
echo "Label:   $LAUNCH_LABEL"
echo "Reason:  $REASON"
echo "Claude:  ${CLAUDE_CODE:-NOT FOUND}"
echo

for attempt in $(seq 1 $((MAX_RETRIES + 1))); do
  echo "--- Attempt $attempt ---"
  do_restart

  errors="$(check_gateway_errors)"

  if [[ -z "$errors" || "$errors" =~ ^[[:space:]]*$ ]]; then
    echo "[$(date -u +%H:%M:%S)] Gateway restarted successfully (attempt $attempt)"
    exit 0
  fi

  echo "[$(date -u +%H:%M:%S)] Errors detected:"
  echo "$errors"

  if [[ $attempt -gt $MAX_RETRIES ]]; then
    notify "🔴 Gateway restart failed after $MAX_RETRIES fix attempts. Errors: $(echo "$errors" | head -3)"
    exit 1
  fi

  if [[ -z "$CLAUDE_CODE" ]]; then
    notify "🔴 Gateway restart failed and Claude Code not available. Errors: $(echo "$errors" | head -3)"
    exit 1
  fi

  FIX_PROMPT="OpenClaw gateway restart failed on macOS with these errors:

$errors

Fix the issue. Common causes:
- Invalid JSON in ~/.openclaw/openclaw.json
- Broken plugin references in plugins.load.paths

Rules:
- Prefer minimal changes.
- After fixing, verify JSON: cat ~/.openclaw/openclaw.json | python3 -m json.tool > /dev/null

Show what you changed."

  fix_output=$(timeout "$CLAUDE_TIMEOUT" "$CLAUDE_CODE" -p "$FIX_PROMPT" \
    --allowedTools "Read,Write,Edit,Bash" \
    --max-turns 10 \
    2>&1 || echo "Claude Code failed or timed out")

  echo "[safe-restart] Claude fix output (tail):"
  echo "$fix_output" | tail -40
  echo

done
