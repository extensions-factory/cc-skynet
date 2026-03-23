# Commit Rules

When the user asks to commit, always bump the version first.

## Version Bump

**Step 1.** Analyze staged/unstaged changes (`git diff`, `git status`) to determine bump type:

| Change type | Bump |
|---|---|
| Breaking change, major refactor, removed feature | `major` |
| New feature, new file, new capability | `minor` |
| Bug fix, docs, style, refactor, chore | `patch` |

**Step 2.** Find all files in the project that contain a version field. Common locations:
- `**/plugin.json` — `"version": "x.y.z"`
- `**/marketplace.json` — `"version": "x.y.z"`
- `package.json`, `pyproject.toml`, `Cargo.toml`, etc.

Search with: `grep -r '"version"' --include="*.json" -l` (or equivalent for other formats).

**Step 3.** Bump the version consistently across ALL found files.

**Step 4.** Stage the version file changes, then commit everything together.

## Build Counter (between commits)

After any code change that can be tested — **before running tests or asking user to verify** — bump a build counter suffix on the current version:

```
0.5.0   →  0.5.0-1   (first change in this iteration)
0.5.0-1 →  0.5.0-2   (second change)
0.5.0-2 →  0.5.0-3   (and so on)
```

**When to bump build counter:**
- Made code changes AND there is something testable (run tests, verify behavior, check output)
- Applied a fix mid-session before asking user to re-test

**When NOT to bump build counter:**
- Docs-only or comment-only changes
- Changes with no testable output

**On commit:** strip the build counter, then apply the normal semver bump.
```
0.5.0-4  →  commit  →  0.5.1 (patch) or 0.6.0 (minor), etc.
```

## Rules

- Never commit without bumping version first
- All version files must stay in sync — no mismatches
- State the bump type and new version in the commit message
- If unsure between bump types, choose the lower one and ask
- Build counter suffix is for in-session tracking only — always stripped before final commit
