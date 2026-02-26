---
name: codex-tool
description: >
  Execute coding tasks via OpenAI Codex CLI. Use when: user needs to modify files,
  refactor code, fix bugs, write new features, analyze a codebase, or run tests.
  NOT for: browser tasks, web navigation, answering questions, simple one-liners.
metadata: { "openclaw": { "emoji": "⚡", "requires": { "bins": ["codex"] } } }
---

# Codex Tool

Delegate coding tasks to Codex CLI using the `exec` tool.

## Core pattern

```
exec command:"codex exec --full-auto -C '<project_dir>' '<instruction>'" timeoutMs:300000
```

- `--full-auto` — auto-approves, sandbox workspace-write (recommended default)
- `-C <project_dir>` — sets working directory for the agent
- `timeoutMs:300000` — 5 min default; use 120000 for quick tasks

## Sandbox modes

| Flag | Mode | When to use |
|------|------|-------------|
| `--full-auto` | workspace-write sandbox | Default — safe auto-approve |
| `--dangerously-bypass-approvals-and-sandbox` | no sandbox | Full access, use carefully |
| `-s read-only` | read-only | Analysis/planning only |

## Useful flags

```
-m o3                                  # specify model
--skip-git-repo-check                  # allow running outside git repo
--json                                 # structured JSONL output
-o /tmp/result.txt                     # write last message to file
```

## Examples

**Refactor:**
```
exec command:"codex exec --full-auto -C '/Users/blueice/myproject' 'Refactor login.js: extract validation into validateUser()'" timeoutMs:300000
```

**Read-only analysis:**
```
exec command:"codex exec -s read-only -C '/Users/blueice/myproject' 'Analyze this repo and summarize the architecture'" timeoutMs:120000
```

**Outside git repo:**
```
exec command:"codex exec --full-auto --skip-git-repo-check -C '/tmp/scratch' 'Create a hello.py that prints Hello World'" timeoutMs:120000
```

## Tips for better results

- **Give Codex a way to verify**: end prompts with "Done when `npm test` passes"
- **Plan first for complex tasks**: use `-s read-only` to explore, then re-run with `--full-auto`
- **Pass instructions in English** for best results
- Codex requires a git repo by default — add `--skip-git-repo-check` for non-git dirs

## Rules

- Always set `timeoutMs` (min 120000 for non-trivial tasks)
- After exec returns, summarize the result to the user
- Do NOT use for browser/web tasks — use `browser` tool directly
- Do NOT run `codex` without `exec` subcommand (no interactive sessions)
