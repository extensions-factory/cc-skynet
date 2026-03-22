# Changelog

All notable changes to this project will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [0.3.0] - 2026-03-22

### Added

- `scripts/auto-update.sh`: version-aware rule sync — copies plugin rules to `.claude/rules/` only when plugin version changes, tracked via `.skynet-version`
- `skills/skynet-sync`: combined init + update skill — runs auto-update script then syncs `# RULES` section in `CLAUDE.md` with descriptions of each rule
- `rules/skynet.md`: core Skynet behavioral rules (cycle, delegation, constraints)
- `rules/delegation.md`: worker selection matrix, task brief template, parallel/sequential patterns, retry policy
- `rules/skill-triggers.md`: skill suggestion map by task type for orchestrator and workers

### Changed

- SessionStart hook split into 4 stages: plugin update check → rule file sync → `.claude/rules/` context injection → greeting prompt
- Rules now injected dynamically from `.claude/rules/*.md` at session start — no longer hardcoded in hooks or requiring CLAUDE.md edits

## [0.2.0] - 2026-03-22

### Added

- `hooks/hooks.json`: SessionStart hook (greeting prompt) and PreToolUse hook (file guard for `.env`, credentials, `docker-compose.prod.yml`)
- Inline commands in hooks for portability across projects

## [0.1.0] - 2026-03-21

### Added

- Initial marketplace scaffold with `.claude-plugin/marketplace.json`
- Skynet plugin with orchestrator, worker-claude, worker-gemini agents
- Project structure and conventions documented in `CLAUDE.md`
