#!/usr/bin/env bash
# openclaw-fix.sh — Called by watchdog when Gateway repeatedly fails.
# Purpose:
#   - Collect recent gateway error context
#   - Call Claude Code to propose a fix (config/files)
#   - Restart the gateway via launchctl and verify it becomes active
#
# IMPORTANT:
#   - Do NOT hardcode API keys/tokens here.
#   - Designed for macOS LaunchAgent: ai.openclaw.gateway

set -euo pipefail

LAUNCH_LABEL="ai.openclaw.gateway"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

# Optional: Telegram notify (set to your own chat_id). Leave empty to disable.
TELEGRAM_TARGET="${OPENCLAW_FIX_TELEGRAM_TARGET:-}"

# Paths
OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-$HOME/.openclaw/openclaw.json}"
LOG_DIR="${OPENCLAW_LOG_DIR:-$HOME/.openclaw/logs}"
ERR_LOG="${LOG_DIR}/gateway.err.log"
GW_LOG="${LOG_DIR}/gateway.log"

MAX_RETRIES="${OPENCLAW_FIX_MAX_RETRIES:-2}"
CLAUDE_TIMEOUT_SECS="${OPENCLAW_FIX_CLAUDE_TIMEOUT_SECS:-300}"

# Single-instance lock via atomic mkdir (macOS-safe, no flock dependency)
LOCK_DIR="/tmp/openclaw-fix.lock.d"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Another openclaw-fix is already running, exiting."
  exit 0
fi
trap "rmdir '$LOCK_DIR' 2>/dev/null || true" EXIT

notify() {
  local msg="$1"
  [[ -z "$TELEGRAM_TARGET" ]] && return 0
  local openclaw_bin
  openclaw_bin="${HOME}/.nvm/versions/node/v24.12.0/bin/openclaw"
  [[ -x "$openclaw_bin" ]] || openclaw_bin="$(command -v openclaw 2>/dev/null || true)"
  [[ -x "$openclaw_bin" ]] || return 0
  "$openclaw_bin" message send --channel telegram --target "$TELEGRAM_TARGET" --message "$msg" 2>/dev/null || true
}

write_result() {
  local status="$1" message="$2"
  local out="/tmp/openclaw-fix-result.json"
  cat > "$out" <<EOF
{"status":"$status","message":"$message","timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
  echo "[openclaw-fix] result written: $out"
}

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

collect_errors() {
  local errors=""

  # Read error log (last 80 lines, filter key error terms)
  if [[ -f "$ERR_LOG" ]]; then
    errors+=$(tail -80 "$ERR_LOG" 2>/dev/null | grep -i "error\|fatal\|invalid\|failed\|EADDRINUSE" | tail -20 || true)
  fi

  echo "=== gateway.err.log (recent errors) ==="
  echo "$errors"
  echo ""

  # Also pull error lines from main gateway log
  if [[ -f "$GW_LOG" ]]; then
    echo "=== gateway.log (recent errors) ==="
    tail -80 "$GW_LOG" 2>/dev/null | grep -i "error\|fatal\|invalid\|failed" | tail -20 || true
    echo ""
  fi

  echo "=== launchctl state ==="
  launchctl print "gui/$(id -u)/${LAUNCH_LABEL}" 2>/dev/null | grep -E "state|pid|last exit" || echo "(not loaded)"
}

validate_config_json() {
  if [[ -f "$OPENCLAW_CONFIG_PATH" ]]; then
    python3 -m json.tool "$OPENCLAW_CONFIG_PATH" > /dev/null 2>&1
  fi
}

restart_and_check() {
  echo "[openclaw-fix] Kicking gateway via launchctl…"
  launchctl kickstart -k "gui/$(id -u)/${LAUNCH_LABEL}" 2>/dev/null || true
  sleep 8
  # Check state = running
  launchctl print "gui/$(id -u)/${LAUNCH_LABEL}" 2>/dev/null | grep -q "state = running"
}

# ---- Main ----
echo "[openclaw-fix] Started at $(date -u +%Y-%m-%dT%H:%M:%SZ)"

ERROR_CONTEXT="$(collect_errors)"

# If config JSON is invalid, surface it early
if [[ -f "$OPENCLAW_CONFIG_PATH" ]]; then
  if ! validate_config_json; then
    notify "🔴 Gateway config JSON invalid: $OPENCLAW_CONFIG_PATH (fix required)."
    write_result "invalid-config" "Invalid JSON: $OPENCLAW_CONFIG_PATH"
    exit 1
  fi
fi

CLAUDE_CODE="$(find_claude)"
if [[ -z "$CLAUDE_CODE" ]]; then
  notify "🔴 Gateway failed. Claude Code not found; cannot auto-fix."
  write_result "no-claude" "Claude Code not found"
  exit 1
fi

notify "🔧 Gateway failed. Attempting auto-fix via Claude Code…"

for attempt in $(seq 1 "$MAX_RETRIES"); do
  FIX_PROMPT="OpenClaw Gateway repeatedly failed on macOS. Fix the issue and verify.

Launch label: ${LAUNCH_LABEL}
Gateway port: ${GATEWAY_PORT}
Config: ${OPENCLAW_CONFIG_PATH}

Error context:
${ERROR_CONTEXT}

Rules:
- Prefer minimal changes.
- Do NOT remove known-good baseline plugins unless clearly broken.
- After changes, verify JSON (if present): python3 -m json.tool ${OPENCLAW_CONFIG_PATH} > /dev/null
- Then restart via launchctl: launchctl kickstart -k gui/\$(id -u)/${LAUNCH_LABEL}

Show what you changed."

  fix_output=$(timeout "$CLAUDE_TIMEOUT_SECS" "$CLAUDE_CODE" -p "$FIX_PROMPT" \
    --allowedTools "Read,Write,Edit" \
    --max-turns 10 \
    2>&1 || echo "Claude Code failed or timed out")

  echo "[openclaw-fix] Attempt $attempt Claude output (tail):"
  echo "$fix_output" | tail -40

  # Validate config before restart
  if [[ -f "$OPENCLAW_CONFIG_PATH" ]]; then
    if ! validate_config_json; then
      notify "🔴 Auto-fix attempt $attempt produced invalid JSON. Not restarting."
      continue
    fi
  fi

  if restart_and_check; then
    notify "✅ Gateway auto-fixed and restarted successfully (attempt $attempt)."
    write_result "ok" "Fixed on attempt $attempt"
    exit 0
  fi

  # Refresh error context for next loop
  ERROR_CONTEXT="$(collect_errors)"
done

notify "🔴 Gateway auto-fix failed after $MAX_RETRIES attempts. Manual intervention needed."
write_result "failed" "Failed after $MAX_RETRIES attempts"
exit 1
