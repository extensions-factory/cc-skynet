<!-- @hook:UserPromptSubmit -->
When the user asks to commit (e.g. "commit", "commit đi", "/commit"), BEFORE creating the commit:

1. Find all files in the project that declare a version (e.g. `package.json`, `plugin.json`, `marketplace.json`, `pyproject.toml`, `Cargo.toml`, etc.)
2. Bump the minor version (e.g. `0.1.0` → `0.2.0`) across all version files consistently.
Determine whether a version bump is appropriate.

| Change type | Bump |
|---|---|
| Breaking change, removed capability, incompatible behavior change | `major` |
| New user-facing capability or distributable feature | `minor` |
| Bug fix, docs, test, style, refactor, chore, internal-only change | `patch` |

3. Stage the version-bumped files together with the rest of the changes.
4. Then proceed with the commit.

This is mandatory — never commit without bumping version first.
<!-- @end:UserPromptSubmit -->
