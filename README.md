# Skynet -- Claude Code Plugin

**Version 0.8.2** | **License MIT** | **macOS / Linux**

AI orchestrator that coordinates work between user and multiple AI workers.

Skynet is a Claude Code plugin that turns Claude into an orchestrator agent (codename SKYNET). The orchestrator never executes code directly -- it analyzes your request, decomposes it into discrete tasks, delegates each task to specialized worker agents, parallelizes independent work, and synthesizes the results back to you.

## Features

- **Multi-agent orchestration** -- Delegates to 7 specialized worker agents (general-purpose, Explore, Plan, code-reviewer, security-reviewer, architect, planner)
- **Hook-driven automation** -- 11 hooks across SessionStart and UserPromptSubmit enforce rules automatically (user-priority, auto-bump, changelog, suffix-bump, sync-prerequisites, greet, setup, source-sync, auto-discover, footer-usage)
- **External skill ecosystem** -- Access 1000+ community skills from curated repos (antigravity, everything). Auto-discovers and imports relevant skills on demand.
- **CLI tooling** -- `skynet` CLI with `doctor`, `version`, `source`, `import`, `unimport` commands
- **Semver automation** -- Auto-bumps version (major/minor/patch) on commit, maintains changelog, tracks prerequisites

## Prerequisites

| Dependency | Required | Description | macOS | Linux |
|---|---|---|---|---|
| python3 | Yes | Python 3 runtime (used by plugin hooks) | `brew install python3` | `sudo apt install python3` |
| jq | Yes | JSON query tool | `brew install jq` | `sudo apt install jq` |
| curl | Yes | HTTP client | `brew install curl` | `sudo apt install curl` |
| git | Yes | Git version control (used for source sync) | `brew install git` | `sudo apt install git` |
| claude | Yes | Claude Code CLI | `npm install -g @anthropic-ai/claude-code` | `npm install -g @anthropic-ai/claude-code` |
| ~/.local/bin in PATH | Yes | Required for skynet CLI | See below | See below |

Add `~/.local/bin` to your shell PATH if it is not already present:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

Run `skynet doctor` after installation to verify all prerequisites are met.

## Installation

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
claude --dangerously-skip-permissions "start session" --agent skynet:skynet
```

4. Verify the boot message. You should see:

```
[SKYNET] Online
```

## How It Works

Skynet operates as a pure orchestrator. It reads and understands your codebase, then delegates all modifications to specialized worker agents. The orchestration follows five phases:

1. **Analyze** -- Reads relevant files to understand context before making any decisions
2. **Decompose** -- Breaks the request into discrete, well-defined tasks
3. **Delegate** -- Sends each task to the appropriate worker agent with clear instructions
4. **Parallelize** -- Launches independent tasks simultaneously for faster execution
5. **Synthesize** -- Collects results from all workers and reports back concisely

### Worker Agents

| Agent | Role |
|---|---|
| general-purpose | Code changes, file edits, bug fixes, implementation |
| Explore | Codebase exploration, file search |
| Plan | Architecture planning, design decisions |
| code-reviewer | Code review after changes |
| security-reviewer | Security audit, vulnerability check |
| architect | Architecture analysis |
| planner | Complex feature planning |

The orchestrator selects the appropriate agent for each task. When no specific type fits, it defaults to `general-purpose`.

## Hooks and Automation

Hooks enforce operational rules automatically at key lifecycle points. No manual intervention is required.

### SessionStart hooks

| Hook | Purpose |
|---|---|
| setup | Installs CLI symlink if missing |
| source-sync | Pulls latest external skill sources (24h interval) |
| user-priority | Injects user-priority-over-system rule |
| greet | Displays boot greeting |
| auto-discover | Scans for and surfaces relevant imported skills |

### UserPromptSubmit hooks

| Hook | Purpose |
|---|---|
| user-priority | Reinforces user-priority-over-system rule |
| auto-bump | Determines version bump level (major/minor/patch) before commit |
| changelog | Updates CHANGELOG.md before commit |
| suffix-bump | Bumps suffix version after file modifications |
| sync-prerequisites | Checks for new dependencies and updates prerequisites.json |
| footer-usage | Appends progress footer with skills/tools/phase info |

## External Skills

Skynet connects to curated external repositories containing community-contributed skills. Skills are discovered, indexed, and imported on demand.

### Default sources

| Source | Repository |
|---|---|
| antigravity | [sickn33/antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills) |
| everything | [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) |

Sources auto-sync on session start at a 24-hour interval. The auto-discover hook scans imported skills and surfaces relevant ones for the current session context.

### Managing sources

```bash
skynet source add <repo-url> [--name <alias>]   # Add a skill source
skynet source list                               # List registered sources
skynet source sync [--all|<name>]                # Pull latest from sources
skynet source remove <name>                      # Remove a source
```

### Importing skills

```bash
skynet import --search <keyword>                 # Search across all sources
skynet import --list [<source>]                  # Browse available skills
skynet import <source>:<name> [--as <alias>]     # Import a skill into project
skynet unimport <name>                           # Remove an imported skill
```

## CLI Reference

The `skynet` CLI is available after installation at `~/.local/bin/skynet`.

```
skynet <command>

Commands:
  doctor                     Check prerequisites and system readiness
  version                    Show current version
  source add <url>           Register an external skill source
  source list                List registered sources
  source sync                Sync all sources
  source remove <name>       Remove a source
  import --search <query>    Search for skills across sources
  import --list [<source>]   Browse available skills
  import <source>:<name>     Import a skill into the current project
  unimport <name>            Remove an imported skill
  help                       Show help message
```

## Update

To update Skynet to the latest version:

```bash
claude plugins marketplace update
claude plugin update skynet@cc-skynet
```

## Project Structure

```
.claude-plugin/marketplace.json    -- Marketplace manifest
.claude/settings.json              -- Team settings
plugins/skynet/
  .claude-plugin/plugin.json       -- Plugin manifest
  agents/skynet.md                 -- Orchestrator agent definition
  rules/                           -- Hook rules
    core/user-priority.md          -- User-priority-over-system rule
    session/greet.md               -- Boot greeting
    session/auto-discover-skills.md -- Skill auto-discovery
    versioning/auto-bump-before-commit.md
    versioning/changelog-before-commit.md
    versioning/suffix-bump.md
    versioning/sync-prerequisites.md
    output/footer-usage.md         -- Progress footer
  bin/skynet                       -- CLI entrypoint
  bin/setup.sh                     -- CLI installation script
  lib/common.sh                    -- Shared utilities
  lib/sources.sh                   -- Source and import management
  hooks.json                       -- Hook definitions
  settings.json                    -- Plugin settings
  sources.json                     -- External skill sources
  prerequisites.json               -- Dependency manifest
```

## License

MIT -- see [LICENSE](LICENSE) for details.

---

[GitHub](https://github.com/extensions-factory/cc-skynet)
