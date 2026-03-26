<!-- @hook:UserPromptSubmit -->
When the user asks to commit (e.g. "commit", "commit đi", "/commit"), BEFORE creating the commit:

1. Read the current `CHANGELOG.md` file.
2. Check `git log` for any new commits since the last changelog entry.
3. Add a new section (or update `[Unreleased]`) with the new changes, grouped by:
   - **Added** — new features or capabilities
   - **Changed** — changes to existing functionality
   - **Fixed** — bug fixes
   - **Removed** — removed features
4. Include the short commit hash in parentheses for each entry (e.g. `(`abc1234`)`).
5. Stage `CHANGELOG.md` together with the rest of the changes.

This is mandatory — never commit without updating the changelog first.
<!-- @end:UserPromptSubmit -->
