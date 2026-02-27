#!/bin/bash
# dispatch-codex.sh — Dispatch a task to Codex with auto-callback
# No hook system needed — notifies directly after codex exec exits
#
# Usage:
#   dispatch-codex.sh -p "your prompt" -n "task-name" -g "-5117536289" -w /path/to/project
#
# Options:
#   -p, --prompt TEXT     Task prompt (required)
#   -n, --name NAME       Task name (for tracking)
#   -g, --group ID        Telegram group ID for result delivery
#   -w, --workdir DIR     Working directory (default: $HOME)
#   -m, --model MODEL     Model override
#   --sandbox MODE        Sandbox mode: workspace-write|read-only|danger-full-access
#   --skip-git            Add --skip-git-repo-check
#   --resume-last         Resume the most recent Codex session (for iteration)

set -euo pipefail

RESULT_DIR="$HOME/.openclaw/codex-results"
META_FILE="${RESULT_DIR}/task-meta.json"
OUTPUT_FILE="${RESULT_DIR}/task-output.txt"
STDOUT_FILE="${RESULT_DIR}/task-stdout.txt"
OPENCLAW_GATEWAY="${OPENCLAW_GATEWAY:-http://127.0.0.1:18789}"
OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-477d47934e5f6b02bfb823ba681bb743eae55479b7d260e8}"
OPENCLAW_BIN="$(which openclaw 2>/dev/null || echo "$HOME/.nvm/versions/node/v24.12.0/bin/openclaw")"

PROMPT=""
TASK_NAME="adhoc-$(date +%s)"
TELEGRAM_GROUP=""
WORKDIR="$HOME"
MODEL=""
SANDBOX=""
SKIP_GIT=""
RESUME_LAST=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--prompt)      PROMPT="$2"; shift 2;;
        -n|--name)        TASK_NAME="$2"; shift 2;;
        -g|--group)       TELEGRAM_GROUP="$2"; shift 2;;
        -w|--workdir)     WORKDIR="$2"; shift 2;;
        -m|--model)       MODEL="$2"; shift 2;;
        --sandbox)        SANDBOX="$2"; shift 2;;
        --full-auto)      SANDBOX="workspace-write"; shift;;
        --skip-git)       SKIP_GIT="1"; shift;;
        --resume-last)    RESUME_LAST="1"; shift;;
        *) echo "Unknown option: $1" >&2; exit 1;;
    esac
done

if [ -z "$PROMPT" ] && [ -z "$RESUME_LAST" ]; then
    echo "Error: --prompt is required (or use --resume-last to continue last session)" >&2
    exit 1
fi

mkdir -p "$RESULT_DIR"

# ---- 1. Write task metadata ----
jq -n \
    --arg name "$TASK_NAME" \
    --arg group "$TELEGRAM_GROUP" \
    --arg prompt "$PROMPT" \
    --arg workdir "$WORKDIR" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{task_name:$name,telegram_group:$group,prompt:$prompt,workdir:$workdir,started_at:$ts,agent:"codex",status:"running"}' \
    > "$META_FILE"

echo "📋 Task: $TASK_NAME | Group: ${TELEGRAM_GROUP:-none}"

# ---- 2. Build codex command ----
# -o writes the agent's last message to file (clean output, no ANSI)
if [ -n "$RESUME_LAST" ]; then
    # resume doesn't support -C or -o; cd into workdir manually
    CMD=(bash -c "cd $(printf '%q' "$WORKDIR") && codex exec resume --last --full-auto${SKIP_GIT:+ --skip-git-repo-check}${MODEL:+ -m $(printf '%q' "$MODEL")}${PROMPT:+ $(printf '%q' "$PROMPT")}")
else
    CMD=(codex exec --full-auto -C "$WORKDIR" -o "$OUTPUT_FILE")
    [ -n "$MODEL" ]    && CMD+=(-m "$MODEL")
    [ -n "$SANDBOX" ]  && CMD+=(-s "$SANDBOX")
    [ -n "$SKIP_GIT" ] && CMD+=(--skip-git-repo-check)
    CMD+=("$PROMPT")
fi

# ---- 3. Run codex (tee stdout for full log) ----
echo "🚀 Launching Codex..."
> "$OUTPUT_FILE"
> "$STDOUT_FILE"

"${CMD[@]}" 2>&1 | tee "$STDOUT_FILE" || true
EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "✅ Codex exited: $EXIT_CODE"

# ---- 4. Parse session ID from stdout ----
SESSION_ID=$(grep "^session id:" "$STDOUT_FILE" 2>/dev/null | awk '{print $3}' | head -1 || echo "")
[ -n "$SESSION_ID" ] && echo "   Session: $SESSION_ID"

# ---- 4. Read output (-o file preferred, fallback to stdout tail) ----
OUTPUT=""
if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
    OUTPUT=$(cat "$OUTPUT_FILE")
elif [ -f "$STDOUT_FILE" ] && [ -s "$STDOUT_FILE" ]; then
    OUTPUT=$(tail -c 4000 "$STDOUT_FILE")
fi

# ---- 5. Write latest.json (same schema as claude-code results) ----
jq -n \
    --arg task "$TASK_NAME" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg cwd "$WORKDIR" \
    --arg output "$OUTPUT" \
    --arg group "$TELEGRAM_GROUP" \
    --arg code "$EXIT_CODE" \
    --arg sid "${SESSION_ID:-}" \
    '{task_name:$task,timestamp:$ts,cwd:$cwd,output:$output,telegram_group:$group,exit_code:($code|tonumber),session_id:$sid,agent:"codex",status:"done"}' \
    > "${RESULT_DIR}/latest.json"

echo "   Results: ${RESULT_DIR}/latest.json"

# ---- 6. Telegram notify ----
if [ -n "$TELEGRAM_GROUP" ] && [ -x "$OPENCLAW_BIN" ]; then
    SUMMARY=$(echo "$OUTPUT" | tail -c 1000 | tr '\n' ' ')
    "$OPENCLAW_BIN" message send \
        --channel telegram --target "$TELEGRAM_GROUP" \
        --message "⚡ *Codex 任务完成*
📋 任务: ${TASK_NAME}
\`\`\`
${SUMMARY:0:800}
\`\`\`" 2>/dev/null \
        && echo "   Telegram sent" || echo "   Telegram failed"
fi

# ---- 7. Wake OpenClaw Gateway ----
curl -s -X POST "${OPENCLAW_GATEWAY}/api/cron/wake" \
    -H "Authorization: Bearer ${OPENCLAW_GATEWAY_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"text\":\"Codex任务完成: ${TASK_NAME}，读取 latest.json\",\"mode\":\"now\"}" \
    > /dev/null 2>&1 || true
echo "   Wake event sent"

exit $EXIT_CODE
