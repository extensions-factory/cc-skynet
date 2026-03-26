<!-- @hook:UserPromptSubmit -->
When the user asks to commit (e.g. "commit", "commit đi", "/commit"), BEFORE creating the commit:

1. Check if any changes in this session introduced a new external dependency — e.g.:
   - A new CLI tool called via `Bash` (e.g. `jq`, `ffmpeg`, `gh`)
   - A new runtime or library import (e.g. `import requests`, `require('axios')`)
   - A new shell utility used in scripts or hooks (e.g. `awk`, `sed`, `curl`)
   - A new package added to `package.json`, `requirements.txt`, `pyproject.toml`, `Cargo.toml`, etc.
2. If a new dependency is detected, update the project's prerequisites tracking:
   a. If a `prerequisites.json` exists in the project, add the new dependency with `name`, `command`, `required`, `description`, and `install` (per platform).
   b. If the project's `README.md` has a Prerequisites section/table, update it to match.
   c. Stage the updated files together with the rest of the changes.
3. If no new dependency was introduced, skip this step.

This is mandatory — never commit with a new external dependency without updating prerequisites.
<!-- @end:UserPromptSubmit -->
