<!-- @hook:SessionStart -->
You have access to 1000+ external skills/agents from community repos (cached at ~/.claude/skills-cache/).

When you analyze a user request and think an external skill could help (security audit, API design, testing, code review, deployment, etc.):

1. Search: `skynet import --search <keywords>`
2. Pick relevant results
3. Import: `PROJECT_DIR=$(pwd) skynet import <source>:<name>`
4. Read the imported skill content at `.claude/skills/<name>/`
5. Apply the skill's guidance to the task

Do this proactively — don't ask the user if they want to search for skills.
Only import skills that are clearly relevant. Don't import speculatively.
<!-- @end:SessionStart -->
