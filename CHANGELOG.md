# Changelog

All notable changes to this project will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [0.4.0] - 2026-03-22

### Added

- `scripts/skills-fetch.sh`: clone/pull `antigravity-awesome-skills` repo to `~/.claude/skills-cache/`, list available categories from `skills_index.json`
- `scripts/skills-link.sh`: symlink skills matching project categories (from `.claude/skynet.json`) to `.claude/skills/` using `skills_index.json` — no separate map file needed
- `scripts/setup-cron.sh`: idempotent cron registration — adds daily `skills-fetch` cron at 00:00 if not already present
- SessionStart hooks: `setup-cron.sh` (cron check) + `skills-link.sh` (auto-link on session start)

### Changed

- Orchestrator gains **Phase 1: Analyze & Resolve Skills** — reads `skills_index.json`, identifies needed categories, links missing skills, then uses/suggests them in task briefs
- `skills-fetch.sh` and `skills-link.sh` use `skills_index.json` directly instead of a separate map file
- All scripts share a single log file at `~/.claude/logs/skynet-skills.log`
- Removed `skynet-skills` skill — skill management is now handled by the orchestrator

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
