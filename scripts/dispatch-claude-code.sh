#!/bin/bash
# dispatch-claude-code.sh — Dispatch a task to Claude Code with auto-callback
# macOS adapted version
#
# Usage:
#   dispatch-claude-code.sh [OPTIONS] -p "your prompt here"
#
# Options:
#   -p, --prompt TEXT        Task prompt (required)
#   -n, --name NAME          Task name (for tracking)
#   -g, --group ID           Telegram group ID for result delivery
#   -s, --session KEY        Callback session key
#   -w, --workdir DIR        Working directory for Claude Code
#   --agent-teams            Enable Agent Teams
#   --teammate-mode MODE     Agent Teams display mode (auto/in-process/tmux)
#   --permission-mode MODE   Claude Code permission mode
#   --allowed-tools TOOLS    Allowed tools string
#   --model MODEL            Model override
#   --continue               Continue the most recent Claude Code session
#   --resume ID              Resume a specific session by ID

set -euo pipefail

RESULT_DIR="$HOME/.openclaw/claude-code-results"
META_FILE="${RESULT_DIR}/task-meta.json"
OUTPUT_FILE="/tmp/claude-code-output.txt"
TASK_OUTPUT="${RESULT_DIR}/task-output.txt"
RUNNER="$HOME/.local/bin/claude_code_run.py"

# Defaults
PROMPT=""
TASK_NAME="adhoc-$(date +%s)"
TELEGRAM_GROUP=""
CALLBACK_SESSION=""
WORKDIR="$HOME"
AGENT_TEAMS=""
TEAMMATE_MODE=""
PERMISSION_MODE=""
ALLOWED_TOOLS=""
MODEL=""
CONTINUE_SESSION=""
RESUME_ID=""

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--prompt) PROMPT="$2"; shift 2;;
        -n|--name) TASK_NAME="$2"; shift 2;;
        -g|--group) TELEGRAM_GROUP="$2"; shift 2;;
        -s|--session) CALLBACK_SESSION="$2"; shift 2;;
        -w|--workdir) WORKDIR="$2"; shift 2;;
        --agent-teams) AGENT_TEAMS="1"; shift;;
        --teammate-mode) TEAMMATE_MODE="$2"; shift 2;;
        --permission-mode) PERMISSION_MODE="$2"; shift 2;;
        --allowed-tools) ALLOWED_TOOLS="$2"; shift 2;;
        --model) MODEL="$2"; shift 2;;
        --continue) CONTINUE_SESSION="1"; shift;;
        --resume) RESUME_ID="$2"; shift 2;;
        *) echo "Unknown option: $1" >&2; exit 1;;
    esac
done

if [ -z "$PROMPT" ] && [ -z "$CONTINUE_SESSION" ] && [ -z "$RESUME_ID" ]; then
    echo "Error: --prompt is required (or use --continue/--resume to iterate)" >&2
    exit 1
fi

# ---- 1. Write task metadata ----
mkdir -p "$RESULT_DIR"

jq -n \
    --arg name "$TASK_NAME" \
    --arg group "$TELEGRAM_GROUP" \
    --arg session "$CALLBACK_SESSION" \
    --arg prompt "$PROMPT" \
    --arg workdir "$WORKDIR" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg agent_teams "${AGENT_TEAMS:-0}" \
    '{task_name:$name,telegram_group:$group,callback_session:$session,prompt:$prompt,workdir:$workdir,started_at:$ts,agent_teams:($agent_teams=="1"),status:"running"}' \
    > "$META_FILE"

echo "📋 Task metadata written: $META_FILE"
echo "   Task: $TASK_NAME"
echo "   Group: ${TELEGRAM_GROUP:-none}"
echo "   Agent Teams: ${AGENT_TEAMS:-no}"

# ---- 2. Clear previous output ----
> "$OUTPUT_FILE"
> "$TASK_OUTPUT"

# ---- 3. Build runner command ----
CMD=(python3 "$RUNNER" --cwd "$WORKDIR")

[ -n "$PROMPT" ]        && CMD+=(-p "$PROMPT")
[ -n "$CONTINUE_SESSION" ] && CMD+=(--continue)
[ -n "$RESUME_ID" ]     && CMD+=(--resume "$RESUME_ID")
[ -n "$AGENT_TEAMS" ]   && CMD+=(--agent-teams)
[ -n "$TEAMMATE_MODE" ] && CMD+=(--teammate-mode "$TEAMMATE_MODE")
[ -n "$PERMISSION_MODE" ] && CMD+=(--permission-mode "$PERMISSION_MODE")
[ -n "$ALLOWED_TOOLS" ] && CMD+=(--allowedTools "$ALLOWED_TOOLS")

# ---- 4. Set environment ----
export OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-477d47934e5f6b02bfb823ba681bb743eae55479b7d260e8}"
export OPENCLAW_GATEWAY="${OPENCLAW_GATEWAY:-http://127.0.0.1:18789}"

[ -n "$MODEL" ] && export ANTHROPIC_MODEL="$MODEL"

# ---- 5. Run Claude Code (output tee'd for hook) ----
echo "🚀 Launching Claude Code..."
echo "   Command: ${CMD[*]}"
echo ""

"${CMD[@]}" 2>&1 | tee "$TASK_OUTPUT"
EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "✅ Claude Code exited with code: $EXIT_CODE"
echo "   Hook should have fired automatically."
echo "   Results: ${RESULT_DIR}/latest.json"

# Update meta with completion
if [ -f "$META_FILE" ]; then
    jq --arg code "$EXIT_CODE" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '. + {exit_code:($code|tonumber),completed_at:$ts,status:"done"}' \
        "$META_FILE" > "${META_FILE}.tmp" && mv "${META_FILE}.tmp" "$META_FILE"
fi

exit $EXIT_CODE
