# Changelog

All notable changes to this project will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/).

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
