# OpenClaw Quickstart Guide

> Control your Mac, browser, and files through Telegram — powered by your Claude Max subscription.

**[中文教程 →](README.zh.md)**

---

## What is this?

- **OpenClaw**: An AI gateway that lets you chat with an AI agent via Telegram. The agent can operate your computer on your behalf.
- **claude-max-api-proxy**: Wraps the Claude CLI into a standard OpenAI-compatible API so OpenClaw can call it.
- **This repo**: Contains all the config files and code patches needed to make the two work together.

---

## Prerequisites

Before you start, make sure you have:

- [ ] A Mac (macOS)
- [ ] A [Claude Max subscription](https://claude.ai) with the `claude` CLI working in your terminal
- [ ] Node.js 18+ (recommended: install via [nvm](https://github.com/nvm-sh/nvm))
- [ ] A Telegram account + a Bot Token (get one from [@BotFather](https://t.me/BotFather))
- [ ] Google Chrome (required for browser control)

---

## Step 1: Install Claude CLI

If you haven't already, install Claude Code CLI:

```bash
npm install -g @anthropic-ai/claude-code
```

Verify it works:

```bash
claude --version
```

Then log in with your Claude Max account:

```bash
claude
```

Follow the prompts to authorize, then exit.

---

## Step 2: Install claude-max-api-proxy

This tool wraps the Claude CLI as a local API server on port 3456.

```bash
npm install -g claude-max-api-proxy
```

---

## Step 3: Install OpenClaw

```bash
npm install -g openclaw
```

Verify:

```bash
openclaw --version
```

---

## Step 4: Apply the patches from this repo

Clone this repo:

```bash
git clone https://github.com/AetherX-Technologies/openclaw-quickstart.git
cd openclaw-quickstart
```

### 4.1 Replace the proxy core files

This repo includes three patched files that fix critical bugs in the original proxy. Copy them over:

```bash
PROXY=$(npm root -g)/claude-max-api-proxy

cp claude-max-api-proxy/dist/adapter/openai-to-cli.js $PROXY/dist/adapter/
cp claude-max-api-proxy/dist/adapter/cli-to-openai.js $PROXY/dist/adapter/
cp claude-max-api-proxy/dist/server/routes.js $PROXY/dist/server/
```

> **Why patch these files?**
> The original proxy has several bugs: message content renders as `[object Object]`, tool calls don't work, and it incorrectly spawns a Claude Code subprocess for browser tasks. These patches fix all of that.

### 4.2 Copy OpenClaw config

```bash
mkdir -p ~/.openclaw/agents/main/agent

cp openclaw-config/openclaw.json ~/.openclaw/
cp openclaw-config/agents/main/agent/AGENT.md ~/.openclaw/agents/main/agent/
```

### 4.3 Set your Telegram Bot Token

Edit `~/.openclaw/openclaw.json` and replace the placeholder with your own Bot Token:

```json
"botToken": "your-bot-token-here"
```

> Your token looks like: `1234567890:ABCdefGHIjklMNOpqrSTUvwxYZ`
> Get one by sending `/newbot` to [@BotFather](https://t.me/BotFather) on Telegram.

### 4.4 Copy the startup script

```bash
cp start-openclaw.sh ~/start-openclaw.sh
chmod +x ~/start-openclaw.sh
```

---

## Step 5: Start all services

```bash
~/start-openclaw.sh
```

This script starts:
1. `claude-max-api-proxy` on port 3456 (background process)
2. OpenClaw gateway on port 18789 (registered as a system LaunchAgent — auto-starts on boot)
3. Browser relay on port 18792 (for the Chrome extension)

On success you'll see:

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

## Step 6: Pair with Telegram

1. Open Telegram and find your bot
2. Send `/start`
3. Send `/pair` — the bot will reply with a pairing code like `233TR3Z4`
4. In your terminal, run:

```bash
openclaw pairing approve 233TR3Z4
```

Once paired, just message your bot and the agent will respond.

---

## Step 7: Install the Chrome extension (optional, for browser control)

This lets the agent control your Chrome browser — take screenshots, click, navigate, etc.

### 7.1 Install the extension files

```bash
openclaw browser extension install
```

Then in Chrome:
1. Go to `chrome://extensions`
2. Enable **Developer mode** (top right toggle)
3. Click **Load unpacked**
4. Press `Cmd+Shift+G` and paste: `/Users/YOUR_USERNAME/.openclaw/browser/chrome-extension`
5. Click Open

### 7.2 Configure the extension

1. Right-click the extension icon → **Options**
2. Enter your Gateway Token (shown in the startup script output, or run `openclaw config get gateway.auth.token`)
3. Click **Save**

### 7.3 Attach to a tab

Open any webpage in Chrome, then click the **OpenClaw Browser Relay** icon in the toolbar. When the icon changes color, it's connected.

---

## Daily usage

### Starting services

After a reboot, the OpenClaw gateway starts **automatically** (it's a system service).
You only need to manually start the proxy:

```bash
~/start-openclaw.sh
```

### Viewing logs

```bash
# Proxy logs
tail -f ~/claude-proxy.log

# Gateway logs
tail -f ~/.openclaw/logs/gateway.log
```

### Health check

```bash
openclaw health
```

---

## Troubleshooting

**Telegram replies show `[object Object]`**
The proxy files weren't patched correctly. Redo step 4.1.

**Agent says "no browser tool available"**
The Chrome extension isn't attached to a tab. Click the extension icon on the tab you want to control.

**No reply from the bot**
Run `openclaw health` to check service status, or check `~/claude-proxy.log` for errors.

**Proxy fails with a CLAUDECODE error**
Don't run the proxy directly inside a Claude Code terminal session. Always use `~/start-openclaw.sh` — it handles this automatically.

---

## Repo structure

```
├── claude-max-api-proxy/          # Full proxy project with patches
│   └── dist/
│       ├── adapter/
│       │   ├── openai-to-cli.js   # Fixes content serialization, tool injection, blocks subprocess tools
│       │   └── cli-to-openai.js   # Parses XML tool_call → OpenAI format
│       └── server/
│           └── routes.js          # Debug logging + streaming fix
├── openclaw-config/
│   ├── openclaw.json              # Main OpenClaw config
│   └── agents/main/agent/
│       └── AGENT.md               # Agent behavior instructions
├── start-openclaw.sh              # One-command startup script
├── README.md                      # This file (English)
└── README.zh.md                   # Chinese guide
```
