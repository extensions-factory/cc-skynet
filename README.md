# Skynet — Claude Code Plugin Marketplace

**Version 0.3.0** | **License MIT**

AI orchestrator that coordinates work between user and multiple AI workers.

Skynet is a Claude Code plugin that turns Claude into an orchestrator agent (codename SKYNET). The orchestrator never executes code directly -- it analyzes your request, decomposes it into discrete tasks, delegates each task to specialized worker agents, parallelizes independent work, and synthesizes the results back to you.

## Installation

### Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/extensions-factory/cc-skynet/main/scripts/install.sh | sh
```

### Advanced / Manual Install

1. Add the marketplace:

```bash
claude plugins marketplace add extensions-factory/cc-skynet
```

2. Install the plugin:

```bash
claude plugins install skynet@cc-skynet
```

3. Start a new Claude Code session with the Skynet agent:

```bash
claude --dangerously-skip-permissions "start session"
```

See the [full install guide](docs/guides/install-guide.md) for prerequisites, troubleshooting, and uninstall instructions.

## Verify Installation

Run the `check-version` skill inside a Skynet session:

```
/skynet:check-version
```

You should see the boot message and version confirmation:

```
[SKYNET] Online
```

## Update

```bash
claude plugin update skynet@cc-skynet
```

## License

MIT -- see [LICENSE](LICENSE) for details.

---

[GitHub](https://github.com/extensions-factory/cc-skynet)
