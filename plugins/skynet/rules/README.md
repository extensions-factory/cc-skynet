# Rules

Domain-organized rules for the Skynet orchestrator. Each file contains `<!-- @hook:Event -->` markers for contextual loading via hooks.

## Structure

```
rules/
  orchestration/            ← core orchestrator behavior
    orchestrator.md         identity, cycle, workers, constraints
    delegation.md           decision flow, worker selection, execution path
    skill-triggers.md       skill suggestion map for delegation
  versioning/               ← version management
    commit.md               commit-time version bump rules
    build-counter.md        in-session build counter tracking
```

## How rules are loaded

1. **Background**: `auto-update.sh` flattens all `*.md` into `.claude/rules/` — Claude Code auto-loads them as project instructions
2. **Contextual**: `hooks.json` extracts marked sections via `awk` at specific hook events as timely reminders

## Marker format

```markdown
<!-- @hook:EventName -->
Section content loaded at this event
<!-- @end:EventName -->
```

See [`../hooks/README.md`](../hooks/README.md) for the full event → rule mapping.
