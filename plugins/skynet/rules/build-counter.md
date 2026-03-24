# Build Counter

Track iteration progress between commits by bumping a build counter suffix on the current version.

## How it works

After any code change that can be tested — **before running tests or asking user to verify** — bump the build counter suffix across ALL version files:

```
0.5.0   →  0.5.0-1   (first testable change)
0.5.0-1 →  0.5.0-2   (second change)
0.5.0-2 →  0.5.0-3   (and so on)
```

## When to bump

- Made code changes AND there is something testable (run tests, verify behavior, check output)
- Applied a fix mid-session before asking user to re-test

## When NOT to bump

- Docs-only or comment-only changes
- Changes with no testable output
- At commit time (commit rules handle stripping the counter and applying semver bump)

## Version files

Same files as commit rules — find with: `grep -r '"version"' --include="*.json" -l`

All version files must stay in sync, including the build counter suffix.
