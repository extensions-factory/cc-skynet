<!-- @hook:UserPromptSubmit -->
**SKILL MATCHING — proactive skill usage**

Before responding to each user request, scan the available skills list (shown in system-reminder) and check if any skill matches the user's intent.

Matching criteria — invoke the Skill tool when:
- The user's request clearly maps to a skill's trigger description (e.g. security concern → `security-review`, code review → `code-reviewer`, scheduling → `schedule`)
- The user explicitly names a skill or slash command (e.g. "/simplify", "/commit", "run code review")
- A delegated task would benefit from domain-specific guidance a skill provides

Rules:
1. Invoke the matching Skill tool BEFORE generating other responses or delegating work
2. If multiple skills match, invoke them in priority order (most specific first)
3. When delegating to worker agents, include relevant skill guidance in the delegation prompt so workers benefit from the skill's patterns
4. Do NOT invoke skills speculatively — only when there's a clear match
5. For external skills (not in the built-in list), use the `skynet import --search` workflow from auto-discover

Common trigger mappings:
| User intent | Skill |
|---|---|
| "review code", "check quality" | `code-reviewer` |
| "security check", "audit", "vulnerability" | `security-review` |
| "simplify", "clean up code" | `simplify` |
| "schedule", "cron", "recurring" | `schedule` |
| "create a skill", "write skill" | `skill-writer` |
| "check skill", "validate skill" | `skill-check` |
| "scan skill for security" | `skill-scanner` |
| "configure settings", "add permission", "add hook" | `update-config` |
| "keyboard shortcut", "keybinding" | `keybindings-help` |
| "Claude API", "Anthropic SDK" | `claude-api` |
| "multi-agent", "agent patterns" | `multi-agent-patterns` |
| "bash script", "shell script" | `bash-scripting` |
| "run repeatedly", "poll", "loop" | `loop` |
| "parallel tasks", "run in parallel" | `parallel-agents` |
| "agent harness", "optimize harness" | `agent-harness-construction` |
| "shellcheck", "lint shell" | `shellcheck-configuration` |
<!-- @end:UserPromptSubmit -->
