# versioning/

Rules for version management: commit-time semver bumps and in-session build counter tracking.

## Files

### commit.md

Version bump and commit rules, triggered when user asks to commit.

| Section | Hook | Purpose |
|---|---|---|
| Full content | `@hook:UserPromptSubmit` | 6-step version bump flow + commit rules (keyword: "commit") |

Key rules:
- Inspect changes → determine bump type (major/minor/patch)
- Find & sync versioned manifests (`plugin.json`, `marketplace.json`, etc.)
- Strip build counter suffix before semver bump
- State bump type in commit message

### build-counter.md

In-session build counter for tracking testable iterations.

| Section | Hook | Purpose |
|---|---|---|
| Full content | `@hook:SubagentStop` | Remind to consider version bump after worker completes code changes |

Key rules:
- Bump: after testable code changes, before verification
- Skip: docs-only, no testable output, at commit time
- Keep version files in sync
