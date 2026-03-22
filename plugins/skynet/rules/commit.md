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

## Rules

- Never commit without bumping version first
- All version files must stay in sync — no mismatches
- State the bump type and new version in the commit message
- If unsure between bump types, choose the lower one and ask
