# Skynet — Claude Code Plugin

AI orchestrator that coordinates work between user and multiple AI workers.

## Prerequisites

| Dependency | Required | Install |
|---|---|---|
| python3 | Yes | `brew install python3` |
| jq | Yes | `brew install jq` |
| curl | Yes | `brew install curl` |
| claude | Yes | `npm install -g @anthropic-ai/claude-code` |
| ~/.local/bin in PATH | Yes | `echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc` |

## Installation

```bash
claude plugins marketplace add extensions-factory/cc-skynet
claude plugins install skynet@cc-skynet
```

Start a new Claude Code session — the plugin auto-configures the `skynet` CLI on first run.

You should see:

```
[SKYNET] Online, sẵn sàng phục vụ
```
