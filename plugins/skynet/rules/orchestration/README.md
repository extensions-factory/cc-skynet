# orchestration/

Core rules governing orchestrator behavior, task delegation, and skill suggestions.

## Files

### orchestrator.md

Skynet orchestrator identity, workflow cycle, and constraints.

| Section | Hook | Purpose |
|---|---|---|
| Identity & Cycle | _(auto-loaded)_ | LISTEN → PLAN → EXECUTE/DELEGATE → REPORT |
| Communication | `@hook:Stop` | Language, conciseness, footer format |
| Workers & Execution Path | _(auto-loaded)_ | Worker roles, mandatory spawn script flow |
| Protected Files | `@hook:PreToolUse:protected-files` | BLOCK `.env`, `.credentials`, `docker-compose.prod.yml` (exit 2) |
| Greeting | `@hook:SessionStart:greeting` | One-line greeting at session start |
| Constraints | _(auto-loaded)_ | No protected file edits, confirm destructive actions, no auto-commit |

### delegation.md

Decision flow for when/how to delegate work to workers.

| Section | Hook | Purpose |
|---|---|---|
| Core Principle & Decision Flow | _(auto-loaded)_ | Classify tasks → pick worker type |
| Worker Selection | _(auto-loaded)_ | Capacity model, coding/research preferences, anti-patterns |
| Direct Edit Restriction | `@hook:PreToolUse:Edit\|Write` | Remind: no direct file edits by orchestrator |
| Command Restriction | `@hook:PreToolUse:Bash` | Remind: only orchestration commands directly |
| Delegation Mechanism | `@hook:PreToolUse:Agent` | Execution path, mandatory rules, task brief template |
| Scheduling Scenarios | _(auto-loaded)_ | Research-heavy, single/dual coding, mixed, review patterns |
| Capacity-Aware Priorities | _(auto-loaded)_ | Priority ordering for coding & research work |
| Result Handling & Reporting | `@hook:SubagentStop` | Handle SUCCESS/BLOCKED/FAILED, report format |
| Context Passing & Size Thresholds | _(auto-loaded)_ | What to include/exclude, task size → behavior |

### skill-triggers.md

Skill suggestion map for worker delegation.

| Section | Hook | Purpose |
|---|---|---|
| Full content | `@hook:PreToolUse:Agent` | Trigger map (code, quality, devops, research, skynet) + suggestion rules |
