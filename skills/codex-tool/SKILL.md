---
name: codex-tool
description: >
  Execute coding tasks via OpenAI Codex CLI. Use when: user needs to modify files,
  refactor code, fix bugs, write new features, analyze a codebase, or run tests.
  NOT for: browser tasks, web navigation, answering questions, simple one-liners.
metadata: { "openclaw": { "emoji": "⚡", "requires": { "bins": ["codex"] } } }
---

# Codex Tool

All tasks go through `dispatch-codex.sh`. It runs Codex in the background,
captures output, and auto-notifies via Telegram + OpenClaw wake event on completion.

## Core pattern

```
exec command:"dispatch-codex.sh -p '<instruction>' -n '<task-name>' -w '<project_dir>'" timeoutMs:10000
```

- `-p` — task instruction (required)
- `-n` — short task name for tracking (e.g. `fix-login`, `refactor-auth`)
- `-w` — project working directory
- `-g` — Telegram group ID to push result to (optional)
- `timeoutMs:10000` — dispatch returns in <10s; Codex runs in background

## Useful flags

```
-m o3                  # specify model (default: gpt-5.3-codex)
--skip-git             # allow running outside a git repo
--sandbox read-only    # analysis only, no writes
```

## Iteration (second call)

```
exec command:"dispatch-codex.sh -p '<follow-up>' -n '<task-name-v2>' -w '<project_dir>' --resume-last" timeoutMs:10000
```

`--resume-last` continues the most recent Codex session with full conversation context.

## Examples

**Refactor:**
```
exec command:"dispatch-codex.sh -p 'Refactor login.js: extract validation into validateUser()' -n 'refactor-login' -w '/Users/blueice/myproject'" timeoutMs:10000
```

**With Telegram notify:**
```
exec command:"dispatch-codex.sh -p 'Fix all TypeScript errors in src/' -n 'fix-ts' -g '-5117536289' -w '/Users/blueice/myproject'" timeoutMs:10000
```

**Outside git repo:**
```
exec command:"dispatch-codex.sh -p 'Create a hello.py that prints Hello World' -n 'hello' -w '/tmp/scratch' --skip-git" timeoutMs:10000
```

**Resume last session:**
```
exec command:"dispatch-codex.sh -p 'The validateUser function still needs error handling' -n 'refactor-login-v2' -w '/Users/blueice/myproject' --resume-last" timeoutMs:10000
```

**Specific model:**
```
exec command:"dispatch-codex.sh -p 'Solve this algorithm problem' -n 'algo' -w '/Users/blueice/myproject' -m o3" timeoutMs:10000
```

## Results

After dispatch returns, results are written to `~/.openclaw/codex-results/latest.json`.
Tell the user the task is running in background and they'll be notified on completion.

## Rules

- Always use `dispatch-codex.sh`, never call `codex` directly
- Always set `timeoutMs:10000` (dispatch is non-blocking)
- Always set `-n` with a meaningful task name
- Codex requires a git repo by default — add `--skip-git` for non-git dirs
- Do NOT use for browser/web tasks — use `browser` tool directly
