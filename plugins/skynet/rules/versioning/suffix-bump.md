<!-- @hook:Stop -->
Before finishing any session that modified files in the project, ensure the suffix version has been bumped.

Rule:
- Every change, no matter how small, MUST bump the suffix version: `X.Y.Z-1` → `X.Y.Z-2` → `X.Y.Z-3` ...
- Find ALL files in the project that declare a version (e.g. `package.json`, `plugin.json`, `marketplace.json`, `pyproject.toml`, `Cargo.toml`, etc.) and bump them consistently.
- This ensures testers can verify the exact latest version is installed.
- If no files were changed, no bump is needed.
<!-- @end:Stop -->
