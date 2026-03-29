---
name: init-project
description: Initialize a project workspace with Skynet configuration scaffold
tools: Read, Write, Bash
---

# init-project

Initialize the current project directory for Skynet by creating a `.skynet/` configuration scaffold.

## Usage

Invoke this skill in any project directory to bootstrap Skynet project configuration.

## Instructions

Follow these steps in order. If any step fails, report the error clearly and stop.

### Step 1 — Safety checks

1. Run `pwd` to get the current working directory.
2. **Root/home guard**: If the current directory is `/` or the user's home directory (`$HOME`), warn:
   ```
   ⚠ Warning: You are about to initialize Skynet in {cwd}.
   This does not look like a project root. Are you sure you want to continue?
   ```
   Wait for user confirmation before proceeding. If the user declines, stop.

### Step 2 — Check for existing initialization

1. Check if `.skynet/project.json` exists in the current directory.
2. If it exists:
   a. Try to read and parse it as JSON.
   b. If valid JSON, display:
      ```
      Project already initialized.
      ────────────────────────────
      Project:     {name}
      Initialized: {initialized}
      Status:      {status}
      Skynet:      {skynetVersion}

      Use `detect-project` to view full project details.
      ```
   c. Do NOT overwrite. Stop here.
   d. If the file exists but is NOT valid JSON, display:
      ```
      ✗ Error: Existing `.skynet/project.json` is corrupted (invalid JSON).
        Back up the file and re-initialize manually.
      ```
      Stop here.

### Step 3 — Read Skynet version

1. Read `~/.claude/plugins/installed_plugins.json`.
2. Find the entry where `name` is `"skynet"` (or marketplace is `"cc-skynet"`).
3. Extract the `version` field. Store as `{skynetVersion}`.
4. If the file does not exist or no skynet entry is found:
   ```
   ✗ Error: Skynet plugin not found in installed plugins.
     Make sure the Skynet plugin is installed first.
   ```
   Stop here.

### Step 4 — Detect project name

1. Extract the project name from the current directory name (last segment of `pwd`).
2. This is the default `{projectName}`.

### Step 5 — Create scaffold

1. Create the `.skynet/` directory:
   ```bash
   mkdir -p .skynet
   ```
   If this fails (permission error), display:
   ```
   ✗ Error: Cannot create `.skynet/` — check directory permissions.
   ```
   Stop here.

2. Write `.skynet/project.json` with this exact structure:
   ```json
   {
     "name": "{projectName}",
     "version": "0.1.0",
     "initialized": "{current ISO 8601 timestamp}",
     "skynetVersion": "{skynetVersion}",
     "status": "initialized"
   }
   ```
   Use the actual current UTC timestamp in ISO 8601 format (e.g., `2026-03-29T12:00:00Z`).

3. Write `.skynet/.gitignore` with this exact content:
   ```
   # Skynet local state — do not commit
   local/
   *.log

   # Keep project config tracked
   !project.json
   !.gitignore
   ```

### Step 6 — Confirm success

Display this confirmation:

```
Skynet Project Initialized
──────────────────────────
Project:     {projectName}
Location:    {cwd}/.skynet/
Config:      .skynet/project.json
Version:     {skynetVersion}
Status:      ✓ Ready

Next step:   configure your project profile (coming in a future release)
```

## Error Summary

| Scenario | Message |
|----------|---------|
| Already initialized | "Project already initialized. Use `detect-project` to view current config." |
| No write permission | "Cannot create `.skynet/` — check directory permissions." |
| Skynet not installed | "Skynet plugin not found in installed plugins." |
| Root/home directory | Warning with confirmation prompt |
| Corrupted project.json | "Existing `.skynet/project.json` is corrupted (invalid JSON)." |

## Notes

- This skill creates the MINIMUM scaffold only. Do NOT add profile fields — that is US-004's responsibility.
- The `version` field in `project.json` is the schema version (`0.1.0`), not the Skynet plugin version.
- All runtime reads use `~/.claude/plugins/installed_plugins.json`, never local repo paths.
