---
name: claude-code-tool
description: >
  Execute coding tasks via Claude Code CLI. Use when: user needs to modify files,
  refactor code, fix bugs, write new features, analyze a codebase, or run tests.
  NOT for: browser tasks, web navigation, answering questions, simple one-liners.
metadata: { "openclaw": { "emoji": "🤖", "requires": { "bins": ["claude"] } } }
---

# Claude Code Tool

Delegate coding tasks to Claude Code CLI using the `exec` tool.

## How to use

Call exec with this exact pattern:

```
exec command:"env -u CLAUDECODE claude -p '<instruction>' --dangerously-skip-permissions" cwd:"<project_dir>" timeoutMs:300000
```

- Replace `<instruction>` with a clear natural language task description
- Replace `<project_dir>` with the target project directory (default: /Users/blueice)
- `timeoutMs:300000` = 5 minute timeout for complex tasks

## Example

User: "重构 login.js，把验证逻辑抽离出来"

```
exec command:"env -u CLAUDECODE claude -p 'Refactor login.js: extract validation logic into a separate validateUser() function' --dangerously-skip-permissions" cwd:"/Users/blueice/myproject" timeoutMs:300000
```

## Rules

- Always use `env -u CLAUDECODE` prefix — required to avoid nested session errors
- Always set `timeoutMs` to at least 120000 (2 min) for non-trivial tasks
- Pass the instruction in English for best results
- After exec returns, summarize the result to the user
- Do NOT use this for browser/web tasks — use the `browser` tool directly
- Do NOT run `claude` without `-p` (no interactive sessions)
