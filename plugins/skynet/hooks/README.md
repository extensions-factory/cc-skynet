# Hooks & Rules

## Architecture

```
.claude/rules/*.md          ← auto-loaded by Claude Code (background knowledge)
hooks.json                  ← extracts specific sections as timely reminders
```

Rules are organized by **domain**. Each rule file contains `<!-- @hook:Event -->` markers that hooks extract via `awk` at the right moment.

## Hook Events

| Event | When | What it does |
|---|---|---|
| `SessionStart` | Session begins/resumes | Setup scripts, greeting, pool profile |
| `UserPromptSubmit` | User sends a prompt | Inject commit rules when keyword detected |
| `PreToolUse` | Before tool executes | Guardrails + contextual reminders per tool |
| `SubagentStop` | Worker finishes | Result handling, reporting format, build counter |
| `Stop` | Claude ends a turn | Remind communication style |

## Rule → Hook Mapping

### orchestrator.md (domain: orchestrator identity)

| Marker | Event | Content |
|---|---|---|
| `@hook:SessionStart:greeting` | `SessionStart` | One-line greeting instruction |
| `@hook:Stop` | `Stop` | Communication style (language, conciseness) |
| `@hook:PreToolUse:protected-files` | `PreToolUse(Edit\|Write\|Bash)` | Block message for `.env`, `.credentials`, etc. (exit 2) |

### delegation.md (domain: task delegation)

| Marker | Event | Content |
|---|---|---|
| `@hook:PreToolUse:Edit\|Write` | `PreToolUse(Edit\|Write)` | "Do NOT edit directly" reminder |
| `@hook:PreToolUse:Bash` | `PreToolUse(Bash)` | "Only orchestration commands" reminder |
| `@hook:PreToolUse:Agent` | `PreToolUse(Agent)` | Delegation mechanism, mandatory rules, task brief template |
| `@hook:SubagentStop` | `SubagentStop` | Result handling statuses + reporting format |

### commit.md (domain: versioning)

| Marker | Event | Content |
|---|---|---|
| `@hook:UserPromptSubmit` | `UserPromptSubmit` | Full commit rules (when prompt contains "commit") |

### build-counter.md (domain: versioning)

| Marker | Event | Content |
|---|---|---|
| `@hook:SubagentStop` | `SubagentStop` | Build counter rules (after worker completes code changes) |

### skill-triggers.md (domain: skill suggestions)

| Marker | Event | Content |
|---|---|---|
| `@hook:PreToolUse:Agent` | `PreToolUse(Agent)` | Skill trigger map + suggestion rules |

## Extraction Pattern

All hooks use the same pattern:

```bash
awk '/@hook:EventName/,/@end:EventName/' .claude/rules/file.md | grep -v '@hook:\|@end:'
```

- `awk` extracts lines between markers (inclusive)
- `grep -v` strips the marker lines themselves
- `2>/dev/null || true` prevents errors if file is missing

## Hook Types

| Type | Behavior |
|---|---|
| **Advice** (exit 0) | Injects text into Claude's context as a reminder |
| **Enforcement** (exit 2) | Blocks the action; `stderr` sent as feedback to Claude |

Only `PreToolUse(Edit|Write|Bash)` for protected files uses enforcement (exit 2). All other hooks are advice.

## Adding a New Hook Section

1. Add `<!-- @hook:EventName -->` and `<!-- @end:EventName -->` markers in the relevant rule file
2. Add the `awk` extraction command in `hooks.json` under the target event
3. Test: `awk '/@hook:EventName/,/@end:EventName/' .claude/rules/file.md | grep -v '@hook:\|@end:'`
