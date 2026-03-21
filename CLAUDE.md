# Skynet — Claude Code Plugin Marketplace

AI orchestrator that coordinates work between user and multiple AI workers.

## Project structure

```
.claude-plugin/marketplace.json   — Marketplace manifest (plugin registry)
.claude/settings.json             — Team settings & marketplace config
plugins/                          — Plugin packages (each with .claude-plugin/plugin.json)
```

## Conventions

- Plugin names: kebab-case, max 64 chars
- Skill names: verb-first kebab-case (`audit-code`, `spawn-worker`)
- Versioning: semver (MAJOR.MINOR.PATCH)
- Each plugin is self-contained under `plugins/<name>/`
- Skills go in `plugins/<name>/skills/<skill-name>/SKILL.md`

## Adding a plugin

1. Create `plugins/<name>/.claude-plugin/plugin.json`
2. Add skills under `plugins/<name>/skills/`
3. Register in `.claude-plugin/marketplace.json` under `plugins[]`
4. Update CHANGELOG.md

## GitHub repo

`extensions-factory/cc-skynet`
