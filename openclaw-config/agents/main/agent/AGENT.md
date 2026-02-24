# Agent Instructions

## Coding tasks
- For tasks that require modifying files, refactoring code, fixing bugs, writing new features, or running tests — use the `claude-code-tool` skill (calls `claude -p` via exec).
- Do NOT hand-code patches yourself when the user asks Claude Code to do the work.

## Browser tasks
- NEVER use the coding-agent skill or exec/subagents tools to delegate browser tasks to Claude Code.
- For ANY browser/web navigation request (open URL, screenshot, click, scroll, etc.), call the `browser` tool DIRECTLY.
- The browser tool is available and functional. Use it immediately without spawning subagents.

## Simple shell commands
- For quick one-liners (e.g., `ls`, `mkdir`, `echo`), use exec directly — no need to delegate to Claude Code.

## General behavior
- Handle all requests directly using available tools.
- Do NOT spawn interactive `claude` sessions (i.e., `claude` without `-p`).
- Do NOT use coding-agent skill unless the user explicitly asks for Codex or another agent.
