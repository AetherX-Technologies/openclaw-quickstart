#!/bin/bash
# Claude Code Stop Hook: notify OpenClaw AGI on task completion
# Triggers: Stop (generation stopped) + SessionEnd (session ended)
# macOS adapted version

set -uo pipefail

RESULT_DIR="$HOME/.openclaw/claude-code-results"
LOG="${RESULT_DIR}/hook.log"
META_FILE="${RESULT_DIR}/task-meta.json"
OPENCLAW_BIN="$(which openclaw 2>/dev/null || echo "$HOME/.nvm/versions/node/v24.12.0/bin/openclaw")"
OPENCLAW_GATEWAY="${OPENCLAW_GATEWAY:-http://127.0.0.1:18789}"
OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-477d47934e5f6b02bfb823ba681bb743eae55479b7d260e8}"

mkdir -p "$RESULT_DIR"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LOG"; }
log "=== Hook fired ==="

# Read stdin
INPUT=""
if [ ! -t 0 ] && [ -e /dev/stdin ]; then
    INPUT=$(timeout 2 cat /dev/stdin 2>/dev/null || true)
fi

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // "unknown"' 2>/dev/null || echo "unknown")
log "session=$SESSION_ID cwd=$CWD event=$EVENT"

# Dedup: skip if same task fired within 30s (macOS stat syntax)
LOCK_FILE="${RESULT_DIR}/.hook-lock"
if [ -f "$LOCK_FILE" ]; then
    LOCK_TIME=$(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    AGE=$(( NOW - LOCK_TIME ))
    if [ "$AGE" -lt 30 ]; then
        log "Duplicate hook within ${AGE}s, skipping"
        exit 0
    fi
fi
touch "$LOCK_FILE"

# Read Claude Code output
OUTPUT=""
sleep 1

TASK_OUTPUT="${RESULT_DIR}/task-output.txt"
if [ -f "$TASK_OUTPUT" ] && [ -s "$TASK_OUTPUT" ]; then
    OUTPUT=$(tail -c 4000 "$TASK_OUTPUT")
    log "Output from task-output.txt (${#OUTPUT} chars)"
fi

if [ -z "$OUTPUT" ] && [ -f "/tmp/claude-code-output.txt" ] && [ -s "/tmp/claude-code-output.txt" ]; then
    OUTPUT=$(tail -c 4000 /tmp/claude-code-output.txt)
    log "Output from /tmp fallback (${#OUTPUT} chars)"
fi

if [ -z "$OUTPUT" ] && [ -n "$CWD" ] && [ -d "$CWD" ]; then
    FILES=$(ls -1t "$CWD" 2>/dev/null | head -20 | tr '\n' ', ')
    OUTPUT="Working dir: ${CWD}\nFiles: ${FILES}"
    log "Output from dir listing"
fi

# Read task metadata
TASK_NAME="unknown"
TELEGRAM_GROUP=""
if [ -f "$META_FILE" ]; then
    TASK_NAME=$(jq -r '.task_name // "unknown"' "$META_FILE" 2>/dev/null || echo "unknown")
    TELEGRAM_GROUP=$(jq -r '.telegram_group // ""' "$META_FILE" 2>/dev/null || echo "")
    log "Meta: task=$TASK_NAME group=$TELEGRAM_GROUP"
fi

# Write latest.json
jq -n \
    --arg sid "$SESSION_ID" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg cwd "$CWD" \
    --arg event "$EVENT" \
    --arg output "$OUTPUT" \
    --arg task "$TASK_NAME" \
    --arg group "$TELEGRAM_GROUP" \
    '{session_id:$sid,timestamp:$ts,cwd:$cwd,event:$event,output:$output,task_name:$task,telegram_group:$group,status:"done"}' \
    > "${RESULT_DIR}/latest.json" 2>/dev/null
log "Wrote latest.json"

# Method 1: openclaw message send → Telegram group
if [ -n "$TELEGRAM_GROUP" ] && [ -x "$OPENCLAW_BIN" ]; then
    SUMMARY=$(echo "$OUTPUT" | tail -c 1000 | tr '\n' ' ')
    MSG="🤖 *Claude Code 任务完成*
📋 任务: ${TASK_NAME}
\`\`\`
${SUMMARY:0:800}
\`\`\`"
    "$OPENCLAW_BIN" message send \
        --channel telegram --target "$TELEGRAM_GROUP" \
        --message "$MSG" 2>/dev/null \
        && log "Sent Telegram message to $TELEGRAM_GROUP" \
        || log "Telegram send failed"
fi

# Method 2: curl wake OpenClaw Gateway (real-time, no heartbeat needed)
curl -s -X POST "${OPENCLAW_GATEWAY}/api/cron/wake" \
    -H "Authorization: Bearer ${OPENCLAW_GATEWAY_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"text\":\"Claude Code任务完成: ${TASK_NAME}，读取 latest.json\",\"mode\":\"now\"}" \
    >> "$LOG" 2>&1 || true
log "Wake event sent"

log "=== Hook completed ==="
exit 0
