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

## Core pattern

```
exec command:"env -u CLAUDECODE claude -p '<instruction>' --permission-mode bypassPermissions" cwd:"<project_dir>" timeoutMs:300000
```

- `env -u CLAUDECODE` — required, prevents nested session errors
- `--permission-mode bypassPermissions` — auto-approves all tool use
- `timeoutMs:300000` — 5 min default; use 120000 for quick tasks

## Permission modes

| Mode | When to use |
|------|-------------|
| `bypassPermissions` | Default — auto-approves everything |
| `acceptEdits` | Auto-approves file edits, asks for Bash |
| `plan` | Read-only analysis, no writes |

## Useful flags

```
--allowedTools "Bash,Read,Edit,Write"   # least-privilege (skip bypassPermissions)
--output-format json                    # structured output
--append-system-prompt "Be strict."     # extra instructions
```

## Examples

**Refactor:**
```
exec command:"env -u CLAUDECODE claude -p 'Refactor login.js: extract validation into validateUser()' --permission-mode bypassPermissions" cwd:"/Users/blueice/myproject" timeoutMs:300000
```

**Read-only analysis:**
```
exec command:"env -u CLAUDECODE claude -p 'Analyze this repo and summarize the architecture' --permission-mode plan" cwd:"/Users/blueice/myproject" timeoutMs:120000
```

**Least-privilege (safer for untrusted code):**
```
exec command:"env -u CLAUDECODE claude -p 'Run tests and fix failures' --allowedTools 'Bash,Read,Edit'" cwd:"/Users/blueice/myproject" timeoutMs:300000
```

## Tips for better results

- **Give Claude a way to verify**: end prompts with "Done when `npm test` passes" or "take a screenshot to confirm"
- **Plan first for complex tasks**: use `--permission-mode plan` to explore, then re-run with `bypassPermissions` to implement
- **After fixing Claude's mistakes**: append "Update CLAUDE.md so you don't repeat this mistake" to the prompt
- **Pass instructions in English** for best results

## Rules

- Always use `env -u CLAUDECODE` prefix
- Always set `timeoutMs` (min 120000 for non-trivial tasks)
- After exec returns, summarize the result to the user
- Do NOT use for browser/web tasks — use `browser` tool directly
- Do NOT run `claude` without `-p` (no interactive sessions)
