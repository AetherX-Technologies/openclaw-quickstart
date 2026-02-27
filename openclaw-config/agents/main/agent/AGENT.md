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

## 长任务派发（零轮询）

对于耗时较长的编码任务（>1分钟），使用 dispatch 模式：

**Claude Code（推荐，支持 Agent Teams）：**
```
exec command:"dispatch-claude-code.sh -p '<任务描述>' -n '<任务名>' -g '<群组ID>' --permission-mode bypassPermissions --workdir '<项目目录>'" timeoutMs:10000
```

**Codex（OpenAI 模型）：**
```
exec command:"dispatch-codex.sh -p '<任务描述>' -n '<任务名>' -g '<群组ID>' -w '<项目目录>'" timeoutMs:10000
```

- 命令立即返回（10秒内），agent 在后台运行
- 完成后自动推送结果到指定 Telegram 群
- Claude Code 支持 Agent Teams：加 `--agent-teams --teammate-mode auto`
- Codex 支持模型切换：加 `-m o3`

对于简单快速任务（<1分钟），继续用 `claude-code-tool` 或 `codex-tool` skill（同步等待）。

## General behavior
- Handle all requests directly using available tools.
- Do NOT spawn interactive `claude` sessions (i.e., `claude` without `-p`).
- Do NOT use coding-agent skill unless the user explicitly asks for Codex or another agent.
