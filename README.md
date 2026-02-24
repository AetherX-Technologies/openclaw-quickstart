# OpenClaw 快速上手指南

> 用 Claude Max 订阅驱动 OpenClaw，通过 Telegram 控制你的电脑、浏览器和文件。

---

## 这是什么？

- **OpenClaw**：一个 AI 网关，让你通过 Telegram 等聊天工具和 AI agent 对话，agent 可以帮你操作电脑
- **claude-max-api-proxy**：把 Claude CLI（命令行工具）包装成标准 API，让 OpenClaw 能调用它
- **本仓库**：记录了让两者配合工作所需的所有配置和代码改动

---

## 前置条件

开始之前，确认你有：

- [ ] macOS 电脑
- [ ] [Claude Max 订阅](https://claude.ai)（需要能在终端用 `claude` 命令）
- [ ] Node.js 18+（推荐用 [nvm](https://github.com/nvm-sh/nvm) 安装）
- [ ] Telegram 账号 + 一个 Bot Token（从 [@BotFather](https://t.me/BotFather) 获取）
- [ ] Google Chrome 浏览器（浏览器控制功能需要）

---

## 第一步：安装 Claude CLI

如果还没安装，先安装 Claude Code CLI：

```bash
npm install -g @anthropic-ai/claude-code
```

安装完后验证：

```bash
claude --version
```

然后登录你的 Claude Max 账号：

```bash
claude
```

按提示完成授权，退出后继续。

---

## 第二步：安装 claude-max-api-proxy

这个工具把 Claude CLI 变成一个本地 API 服务（监听 3456 端口）。

```bash
npm install -g claude-max-api-proxy
```

---

## 第三步：安装 OpenClaw

```bash
npm install -g openclaw
```

验证安装：

```bash
openclaw --version
```

---

## 第四步：应用本仓库的配置

克隆本仓库：

```bash
git clone https://github.com/AetherX-Technologies/openclaw-quickstart.git
cd openclaw-quickstart
```

### 4.1 替换 proxy 的核心文件

本仓库对 `claude-max-api-proxy` 做了三处关键修复，需要覆盖原始文件：

```bash
# 找到 proxy 的安装路径
PROXY=$(npm root -g)/claude-max-api-proxy

# 覆盖改动的文件
cp claude-max-api-proxy/dist/adapter/openai-to-cli.js $PROXY/dist/adapter/
cp claude-max-api-proxy/dist/adapter/cli-to-openai.js $PROXY/dist/adapter/
cp claude-max-api-proxy/dist/server/routes.js $PROXY/dist/server/
```

> **为什么要改这些文件？**
> 原版 proxy 有几个 bug：消息内容显示 `[object Object]`、无法处理工具调用、会错误地启动 Claude Code 子进程来处理浏览器任务。这些改动修复了上述问题。

### 4.2 配置 OpenClaw

```bash
# 创建配置目录
mkdir -p ~/.openclaw/agents/main/agent

# 复制主配置（包含模型、Telegram、网关设置）
cp openclaw-config/openclaw.json ~/.openclaw/

# 复制 agent 指令（告诉 agent 直接用浏览器工具，不要启动子进程）
cp openclaw-config/agents/main/agent/AGENT.md ~/.openclaw/agents/main/agent/
```

### 4.3 配置 Telegram Bot Token

编辑 `~/.openclaw/openclaw.json`，找到这一行，替换成你自己的 Bot Token：

```json
"botToken": "在这里填入你的 Bot Token"
```

> Bot Token 格式类似：`1234567890:ABCdefGHIjklMNOpqrSTUvwxYZ`
> 从 Telegram 的 [@BotFather](https://t.me/BotFather) 发送 `/newbot` 获取。

### 4.4 复制启动脚本

```bash
cp start-openclaw.sh ~/start-openclaw.sh
chmod +x ~/start-openclaw.sh
```

---

## 第五步：启动所有服务

```bash
~/start-openclaw.sh
```

脚本会依次启动：
1. `claude-max-api-proxy`（端口 3456，后台运行）
2. OpenClaw 网关（端口 18789，注册为系统服务，开机自启）
3. 浏览器中继服务（端口 18792，供 Chrome 扩展连接）

启动成功后会显示：

```
Starting claude-max-api proxy on :3456...
  PID 12345 — logs: ~/claude-proxy.log
Starting OpenClaw gateway...
  logs: ~/.openclaw/logs/gateway.log
Starting browser relay on :18792...

Done. Dashboard: http://127.0.0.1:18789/
      Token:     xxxxxxxxxxxxxxxx

Chrome: click OpenClaw Browser Relay extension icon on any tab to attach.
```

---

## 第六步：连接 Telegram

1. 打开 Telegram，找到你的 Bot（就是你在 BotFather 创建的那个）
2. 发送 `/start`
3. 发送 `/pair`，Bot 会回复一个配对码，例如 `233TR3Z4`
4. 在终端运行：

```bash
openclaw pairing approve 233TR3Z4
```

配对成功后，直接在 Telegram 给 Bot 发消息就能和 agent 对话了。

---

## 第七步：安装 Chrome 扩展（可选，浏览器控制需要）

让 agent 能控制你的 Chrome 浏览器（截图、点击、导航等）。

### 7.1 安装扩展

```bash
openclaw browser extension install
```

然后在 Chrome 中：
1. 地址栏输入 `chrome://extensions`
2. 右上角开启**开发者模式**
3. 点击**加载已解压的扩展程序**
4. 按 `Cmd+Shift+G`，粘贴路径：`/Users/你的用户名/.openclaw/browser/chrome-extension`
5. 点击打开

### 7.2 配置扩展

1. 右键扩展图标 → **选项**
2. 填入 Gateway Token（从启动脚本输出中复制，或运行 `openclaw config get gateway.auth.token`）
3. 点 **Save**

### 7.3 连接标签页

在 Chrome 里打开任意网页，点击工具栏中的 **OpenClaw Browser Relay** 图标，图标变色即表示连接成功。

---

## 日常使用

### 启动服务

每次重启电脑后，OpenClaw 网关会**自动启动**（系统服务）。
但 `claude-max-api-proxy` 需要手动启动：

```bash
~/start-openclaw.sh
```

### 查看日志

```bash
# proxy 日志
tail -f ~/claude-proxy.log

# OpenClaw 网关日志
tail -f ~/.openclaw/logs/gateway.log
```

### 检查服务状态

```bash
openclaw health
```

---

## 常见问题

**Q：Telegram 收到的回复显示 `[object Object]`**
A：proxy 文件没有正确替换，重新执行第 4.1 步。

**Q：agent 说"没有 browser 工具"**
A：Chrome 扩展没有连接到标签页，点击扩展图标 attach 到当前标签页。

**Q：发消息没有回复**
A：运行 `openclaw health` 检查状态，或查看 `~/claude-proxy.log` 排查错误。

**Q：proxy 启动失败，提示 CLAUDECODE 错误**
A：不要在 Claude Code 终端里直接运行 proxy，用 `~/start-openclaw.sh` 启动（脚本会自动处理这个问题）。

---

## 仓库结构

```
├── claude-max-api-proxy/          # proxy 完整项目（含改动）
│   └── dist/
│       ├── adapter/
│       │   ├── openai-to-cli.js   # 修复内容序列化 + 工具注入 + 过滤子进程工具
│       │   └── cli-to-openai.js   # 解析 XML tool_call → OpenAI 格式
│       └── server/
│           └── routes.js          # debug 日志 + 流式响应修复
├── openclaw-config/
│   ├── openclaw.json              # OpenClaw 主配置
│   └── agents/main/agent/
│       └── AGENT.md               # Agent 行为指令
├── start-openclaw.sh              # 一键启动脚本
└── README.md                      # 本文档
```
