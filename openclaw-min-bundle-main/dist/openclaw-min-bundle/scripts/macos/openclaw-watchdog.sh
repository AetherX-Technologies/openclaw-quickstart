#!/usr/bin/env bash
# openclaw-watchdog.sh — Periodic health check for openclaw gateway.
# Runs every 60s via LaunchAgent (ai.openclaw.gateway.watchdog).
# If gateway fails 2 consecutive checks, invokes openclaw-fix.sh.

set -euo pipefail

GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
FAIL_COUNT_FILE="/tmp/openclaw-watchdog-fail.count"
FIX_SCRIPT="${HOME}/.local/bin/openclaw-fix.sh"
MAX_FAILS=2
CHECK_INTERVAL=10  # seconds between the two health checks

check_gateway() {
  local http_resp
  http_resp=$(curl -s --max-time 5 "http://127.0.0.1:${GATEWAY_PORT}/" 2>/dev/null | head -1 || true)
  if [[ -n "$http_resp" ]]; then
    return 0  # gateway is up
  fi
  return 1  # gateway not responding
}

echo "[watchdog] $(date -u +%Y-%m-%dT%H:%M:%SZ) — health check start"

if check_gateway; then
  echo "[watchdog] Gateway OK — resetting fail counter"
  echo "0" > "$FAIL_COUNT_FILE"
  exit 0
fi

# First check failed — wait and check again
echo "[watchdog] First check failed, retrying in ${CHECK_INTERVAL}s…"
sleep "$CHECK_INTERVAL"

if check_gateway; then
  echo "[watchdog] Gateway OK on retry — resetting fail counter"
  echo "0" > "$FAIL_COUNT_FILE"
  exit 0
fi

# Both checks failed — increment counter
current_fails=0
if [[ -f "$FAIL_COUNT_FILE" ]]; then
  current_fails=$(cat "$FAIL_COUNT_FILE" 2>/dev/null || echo 0)
fi
current_fails=$(( current_fails + 1 ))
echo "$current_fails" > "$FAIL_COUNT_FILE"

echo "[watchdog] Consecutive fail rounds: ${current_fails}/${MAX_FAILS}"

if [[ "$current_fails" -ge "$MAX_FAILS" ]]; then
  echo "[watchdog] Threshold reached — invoking openclaw-fix.sh"
  echo "0" > "$FAIL_COUNT_FILE"  # reset so we don't loop-invoke
  if [[ -x "$FIX_SCRIPT" ]]; then
    bash "$FIX_SCRIPT" 2>&1 || echo "[watchdog] openclaw-fix.sh exited non-zero"
  else
    echo "[watchdog] ERROR: fix script not found or not executable: $FIX_SCRIPT"
    exit 1
  fi
else
  echo "[watchdog] Not yet at threshold, waiting for next run"
fi
