# OpenClaw + Claude Max API Proxy

本仓库备份了 OpenClaw 配置和对 `claude-max-api-proxy` 的所有改动。

## 结构

```
├── claude-max-api-proxy/     # 完整 proxy 项目（含改动）
├── openclaw-config/          # OpenClaw 配置文件
│   ├── openclaw.json         # 主配置
│   └── agents/main/agent/
│       └── AGENT.md          # Agent 指令
└── start-openclaw.sh         # 一键启动脚本
```

## 主要改动（claude-max-api-proxy）

### `dist/adapter/openai-to-cli.js`
- 修复结构化内容数组 `[object Object]` bug
- 新增 `toolsToSystemPrompt()`：OpenAI tools → XML 注入 Claude CLI
- 过滤 `exec`/`subagents` 等工具，防止 Claude CLI 召唤 Claude Code 子会话

### `dist/adapter/cli-to-openai.js`
- 新增 `parseToolCalls()`：解析 `<tool_call>` XML → OpenAI tool_calls 格式

### `dist/server/routes.js`
- 添加 debug 日志，流式响应累积全文

## 恢复方法

```bash
# 1. 安装依赖
cd claude-max-api-proxy && npm install

# 2. 全局链接（替换 npm 包）
npm link

# 3. 恢复 OpenClaw 配置
cp openclaw-config/openclaw.json ~/.openclaw/
mkdir -p ~/.openclaw/agents/main/agent
cp openclaw-config/agents/main/agent/AGENT.md ~/.openclaw/agents/main/agent/

# 4. 恢复启动脚本
cp start-openclaw.sh ~/start-openclaw.sh
chmod +x ~/start-openclaw.sh
```
