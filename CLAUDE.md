# Skynet — Claude Code Plugin Marketplace

AI orchestrator that coordinates work between user and multiple AI workers.

## IMPORTANT RULES

- This project is a **Claude Code plugin distributed via marketplace** — it is installed by many users across many projects, not just this repository. After installation, plugin metadata lives at `~/.claude/plugins/installed_plugins.json`, NOT in the local project tree.

### Mandatory skills

These skills MUST be invoked when their trigger conditions are met. Do NOT skip them.

| Skill | Trigger | What it does |
|-------|---------|--------------|
| `commit-flow` | User says "commit", "/commit", "push", "commit đi", or any commit/push request | Orchestrates: classify → bump version → changelog → commit → suffix bump |
| `ss-changelog-update` | Called by `commit-flow` before the main commit | Inserts new section into `wiki/CHANGELOG.md`, commits and pushes inside the `wiki/` submodule |
| `ss-suffix-bump` | Any file modification outside of `commit-flow` | Bumps dev suffix `X.Y.Z-N` in version files. Do NOT skip, do NOT defer |

## Conventions

### Naming

| Thing | Rule | Example |
|-------|------|---------|
| Plugin | kebab-case, max 64 chars | `git-workflow` |
| Skill | verb-first kebab-case + prefix | `wf-setup-project`, `spawn-worker` |

**Skill prefixes:**

| Prefix | Meaning |
|--------|---------|
| `wf-`  | workflow — multi-step, user-facing flow |
| `ss-`  | sub-skill — internal, called by other skills |
| `doc-` | document — generates or updates docs |

### Versioning

Semver: `MAJOR.MINOR.PATCH`

### Directory Layout

Each plugin is fully self-contained:

```
plugins/<name>/
  skills/<skill-name>/
    SKILL.md                        # skill entry point
    helpers/<helper>                # skill-scoped helpers
    templates/<template>            # skill-scoped templates
  helpers/<helper>                  # plugin-scoped shared helpers
  templates/<template>              # plugin-scoped shared templates

scripts/                            # global scripts (repo-level, not plugin-specific)
```