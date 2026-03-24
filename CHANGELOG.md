# Changelog

All notable changes to this project will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [0.9.1] - 2026-03-24

### Changed

- `skills-link.sh`: added Codex skills mirror (`.codex/skills → .claude/skills`) — refactored Gemini-only block into loop handling all CLI mirrors

## [0.9.0] - 2026-03-24

### Added

- Codex CLI worker for OpenAI-based code delegation with tmux signaling

## [0.8.0] - 2026-03-24

### Fixed

- **CRITICAL**: Account credential files now match glob patterns expected by worker scripts
- **CRITICAL**: Added outer trap cleanup in `spawn-claude-worker.sh` to prevent OAuth token leakage
- Fixed exit code capture in `spawn-claude-worker.sh` (`&& EC=0 || EC=$?` replaces `|| true; EC=$?`)
- Fixed `.env` guard pattern in hooks.json — anchored to path separator to prevent false positives
- Fixed `spawn-gemini-worker.sh` — stdin pipe replaces shell variable expansion for large tasks
- Fixed `create-task.sh` — `$TITLE` argument now written to output file
- Fixed `setup-cron.sh` — added `sort` before `tail -1` for correct version selection

### Added

- `plugin.json`: declared `"hooks"` and `"skills"` fields for marketplace discovery
- `delegation.md`: enforced external worker scripts as mandatory delegation mechanism
- Backfilled CHANGELOG entries for v0.4.1 through v0.7.3

## [0.7.3] - 2026-03-24

### Changed

- Renamed credential file pattern for Claude accounts to `claude-ooth-*.txt`

## [0.7.2] - 2026-03-24

### Changed

- Renamed credential file pattern for Gemini accounts to `gemini-oauth-*.json`

## [0.7.1] - 2026-03-24

### Fixed

- Added Gemini skills mirror symlink and corrected exit code bug in skills scripts

## [0.7.0] - 2026-03-24

### Added

- Claude Code CLI delegation with round-robin account rotation, Q&A relay, and tmux signaling

## [0.6.0] - 2026-03-23

### Added

- Gemini CLI delegation with round-robin accounts and tmux signaling

## [0.5.1] - 2026-03-23

### Changed

- Added build counter rule for in-session version tracking between commits

## [0.5.0] - 2026-03-23

### Added

- `everything-claude-code` repo integration and `agents-link` support for skills management

## [0.4.3] - 2026-03-23

### Fixed

- Production audit fixes — security hardening and bug fixes across scripts

## [0.4.2] - 2026-03-22

### Fixed

- Orchestrator multi-agent patterns — context isolation and direct pass-through behavior

## [0.4.1] - 2026-03-22

### Added

- `rules/commit.md`: commit rule requiring automatic version bump before every commit

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
