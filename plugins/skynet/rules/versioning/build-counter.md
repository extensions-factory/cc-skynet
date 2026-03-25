# Build Counter

<!-- @hook:SubagentStop -->
Use a build counter suffix only when it helps track testable iterations across versioned artifacts.

## How it works

Examples:

```text
0.5.0   -> 0.5.0-1
0.5.0-1 -> 0.5.0-2
0.5.0-2 -> 0.5.0-3
```

## When to bump

- The project already uses synchronized version files for distributable artifacts
- You made a testable code change and want to mark an iteration before verification
- A mid-session fix changes behavior and the build suffix is part of the team's release workflow

## When NOT to bump

- Docs-only or comment-only changes
- Internal edits with no testable output
- Fast local iteration where the counter would only add diff noise
- At commit time; commit rules should strip the suffix and apply the semantic version bump if needed

## Version Files

- Use the same release-related version files identified by the commit rules
- Keep those files in sync if a build counter is used
- Do not introduce a build counter into unrelated manifests just because they contain a `version` field
<!-- @end:SubagentStop -->
