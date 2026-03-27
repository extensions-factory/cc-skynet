# Changelog

All notable changes to this project will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/).

## [0.8.5] - 2026-03-27

### Fixed

- Agent reference in `settings.json` — use fully qualified `skynet:skynet` instead of `skynet`
- Simplify README start command by removing redundant `--agent skynet:skynet` flag (now handled by settings.json)

## [0.8.4] - 2026-03-27

### Added

- "Manual Setup (Optional)" section in README — 5-step guide for full plugin setup (PATH config, doctor check, source sync, index build, symlink repair) with note that SessionStart hooks handle most steps automatically

## [0.8.3] - 2026-03-27

### Fixed

- **[C-2]** Replace `eval` command execution in `cmd_doctor` with safe array-based dispatch — prevents arbitrary code execution via `prerequisites.json`
- **[C-3]** Eliminate shell variable interpolation in all 17 `python3 -c` calls across `sources.sh`, `common.sh`, and `bin/skynet` — pass values via `os.environ` to prevent injection
- `_is_stale()` crash when `STATE_FILE` doesn't exist on cold start — added `os.path.exists()` guard
- `import_sync` broken counter lost in pipe subshell — converted to process substitution

### Changed

- `json_read()` in `common.sh` now accepts dot-separated key paths instead of arbitrary Python expressions
- `cmd_doctor` prerequisites check block uses env vars for Python interop

### Removed

- Dead `_now_ts()` function from `sources.sh` (was never called)

## [0.8.2] - 2026-03-27

### Changed

- Refactor README.md — comprehensive rewrite with 12 sections: features, architecture overview, hooks reference, external skills, CLI reference, project structure, and cross-platform prerequisites

## [0.8.1] - 2026-03-27

### Changed

- Rewrite `skynet.md` agent definition — explicit tool blacklist/whitelist, delegation table with real subagent types, 5-step protocol (Analyze→Decompose→Delegate→Parallelize→Synthesize)

### Removed

- `test-fake` hook from SessionStart (referenced non-existent file)
- Agent initialization section (redundant with hooks)

## [0.8.0] - 2026-03-27

### Added

- Agent initialization section — auto-resolves plugin install path and loads all rule files on startup
- Embedded operational rules in agent definition (user-priority, suffix-bump, commit workflow, footer usage)
- `settings.json` — declares default agent for the plugin

### Changed

- Agent delegation rules section restructured for clarity

## [0.7.1] - 2026-03-27

### Changed

- All hooks now output `<name> hooked` or `<name> failed to hook` status lines (SessionStart + UserPromptSubmit)
- `greet.md` — presents boot status block to user on first response (template + example format)

## [0.7.0] - 2026-03-27

### Added

- `skynet source` command — manage external skill/agent repositories (add, sync, list, remove)
- `skynet import` command — import skills/agents into project via symlinks (search, link, list, index, sync, targets)
- `skynet unimport` command — remove imported skills/agents
- `lib/sources.sh` — source registry and import management library (660 lines)
- `sources.json` — default external repos: antigravity, everything (1400+ skills/agents)
- `auto-discover-skills` session rule — proactive skill discovery on SessionStart
- `.skills-manifest.json` — declarative import tracking with multi-target support (claude, gemini, codex)
- SessionStart hook: auto-sync sources on session start (with staleness check)
- `git` added to prerequisites (required for source sync)

## [0.6.1] - 2026-03-26

### Added

- `sync-prerequisites` rule — auto-update `prerequisites.json` and README when new dependencies are introduced

## [0.6.0] - 2026-03-26

### Added

- `skynet` CLI with `doctor`, `version`, `help` commands
- `prerequisites.json` — declarative dependency manifest for doctor checks
- `lib/common.sh` — shared utilities (colors, logging, platform detection, JSON helpers)
- `bin/setup.sh` — auto-symlink `skynet` CLI to `~/.local/bin`
- SessionStart hook: auto-run setup on first use or after plugin update
- README: prerequisites table, installation guide, CLI reference

## [0.5.2] - 2026-03-26

### Added

- README with installation instructions and quick-start guide

## [0.5.1] - 2026-03-26

### Added

- Changelog-before-commit rule and hook — auto-update CHANGELOG.md on every commit

### Changed

- Greet template: use `<AGENT_NAME>` placeholder instead of hardcoded `SKYNET`

## [0.5.0] - 2026-03-26

### Added

- Skynet orchestrator agent definition (`c408ee5`)
- User-priority rule: user instructions override system defaults (`c95b417`)
- Versioning rules and hooks — UserPromptSubmit, Stop (`71f9cf6`)
- SessionStart hook with greet rule (`8eb53c8`)
- Skynet plugin: AI orchestrator for multi-agent coordination (`ba5fdf9`)

### Fixed

- Hooks: use python3 for PLUGIN_DIR resolution, move rules to UserPromptSubmit (`4d4c862`)
- Hooks schema: use nested hooks array format, add hooks ref to plugin.json (`afde484`)

## [0.1.0] - 2026-03-21

### Added

- Initial marketplace scaffold
- Project structure and conventions
