# Commit Rules

When the user asks to commit, review the change scope first, then bump version if the project uses versioned artifacts.

## Version Bump

**Step 1.** Inspect staged and unstaged changes with `git diff` and `git status`.

**Step 2.** Determine whether a version bump is appropriate.

| Change type | Bump |
|---|---|
| Breaking change, removed capability, incompatible behavior change | `major` |
| New user-facing capability or distributable feature | `minor` |
| Bug fix, docs, test, style, refactor, chore, internal-only change | `patch` |

Adding a file alone does **not** imply `minor`.

**Step 3.** Find versioned manifest files that are meant to stay aligned, for example:
- `**/plugin.json`
- `**/marketplace.json`
- `package.json`, `pyproject.toml`, `Cargo.toml`

Search with a targeted command such as `rg -n '"version"'`.

**Step 4.** If the current version includes a build counter suffix such as `0.5.0-3`, strip the suffix before applying the semver bump.

**Step 5.** Bump only the version files that are part of the same release surface, and keep those files in sync.

**Step 6.** Stage the version changes together with the commit.

## Rules

- Do not commit without checking whether versioned artifacts need a bump
- Keep related version files in sync; do not blindly edit unrelated manifests
- State the bump type and new version in the commit message when a version bump is applied
- If bump type is ambiguous, choose the lower bump and ask before committing
