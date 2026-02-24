# Agent Instructions

## Browser tasks
- NEVER use the coding-agent skill or exec/subagents tools to delegate browser tasks to Claude Code.
- For ANY browser/web navigation request (open URL, screenshot, click, scroll, etc.), call the `browser` tool DIRECTLY.
- The browser tool is available and functional. Use it immediately without spawning subagents.

## General behavior
- Handle all requests directly using available tools.
- Do NOT spawn Claude Code or Kiro subagents for tasks you can do yourself with tools.
- Do NOT use coding-agent skill unless the user explicitly asks to write/modify code files.
