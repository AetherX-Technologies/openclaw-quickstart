---
name: claude-code-tool
description: >
  Execute coding tasks via Claude Code CLI. Use when: user needs to modify files,
  refactor code, fix bugs, write new features, analyze a codebase, or run tests.
  NOT for: browser tasks, web navigation, answering questions, simple one-liners.
metadata: { "openclaw": { "emoji": "🤖", "requires": { "bins": ["claude"] } } }
---

# Claude Code Tool

All tasks go through `dispatch-claude-code.sh`. It runs Claude Code in the background,
captures output, and auto-notifies via Telegram + OpenClaw wake event on completion.

## Core pattern

```
exec command:"dispatch-claude-code.sh -p '<instruction>' -n '<task-name>' -w '<project_dir>' --permission-mode bypassPermissions" timeoutMs:10000
```

- `-p` — task instruction (required)
- `-n` — short task name for tracking (e.g. `fix-login`, `refactor-auth`)
- `-w` — project working directory
- `-g` — Telegram group ID to push result to (optional)
- `timeoutMs:10000` — dispatch returns in <10s; Claude Code runs in background

## Permission modes

| Flag | When to use |
|------|-------------|
| `--permission-mode bypassPermissions` | Default — auto-approves everything |
| `--permission-mode acceptEdits` | Auto-approves file edits, asks for Bash |
| `--permission-mode plan` | Read-only analysis, no writes |

## Iteration (second call)

```
exec command:"dispatch-claude-code.sh -p '<follow-up>' -n '<task-name-v2>' -w '<project_dir>' --continue --permission-mode bypassPermissions" timeoutMs:10000
```

Or resume a specific session (ID from `~/.openclaw/claude-code-results/latest.json`):

```
exec command:"dispatch-claude-code.sh -p '<follow-up>' -n '<task-name-v2>' -w '<project_dir>' --resume '<session-id>' --permission-mode bypassPermissions" timeoutMs:10000
```

## Agent Teams (multi-agent)

```
exec command:"dispatch-claude-code.sh -p '<instruction>' -n '<task-name>' -w '<project_dir>' --permission-mode bypassPermissions --agent-teams --teammate-mode auto" timeoutMs:10000
```

## Examples

**Refactor:**
```
exec command:"dispatch-claude-code.sh -p 'Refactor login.js: extract validation into validateUser()' -n 'refactor-login' -w '/Users/blueice/myproject' --permission-mode bypassPermissions" timeoutMs:10000
```

**With Telegram notify:**
```
exec command:"dispatch-claude-code.sh -p 'Fix all TypeScript errors in src/' -n 'fix-ts' -g '-5117536289' -w '/Users/blueice/myproject' --permission-mode bypassPermissions" timeoutMs:10000
```

**Read-only analysis:**
```
exec command:"dispatch-claude-code.sh -p 'Analyze this repo and summarize the architecture' -n 'analyze' -w '/Users/blueice/myproject' --permission-mode plan" timeoutMs:10000
```

**Resume last session:**
```
exec command:"dispatch-claude-code.sh -p 'The validateUser function still needs error handling' -n 'refactor-login-v2' -w '/Users/blueice/myproject' --continue --permission-mode bypassPermissions" timeoutMs:10000
```

## Results

After dispatch returns, results are written to `~/.openclaw/claude-code-results/latest.json`.
Tell the user the task is running in background and they'll be notified on completion.

## Rules

- Always use `dispatch-claude-code.sh`, never call `claude` directly
- Always set `timeoutMs:10000` (dispatch is non-blocking)
- Always set `-n` with a meaningful task name
- Do NOT use for browser/web tasks — use `browser` tool directly
- Do NOT pass `--continue` and `-p` together without a follow-up prompt
