---
name: detect-project
description: Detect and display an initialized Skynet project in the current directory
tools: Read
---

# detect-project

Detect whether the current directory is an initialized Skynet project and display its configuration.

## Usage

Invoke this skill to verify project state in any session — useful after reopening a project or to confirm initialization.

## Instructions

### Step 1 — Check for project config

1. Check if `.skynet/project.json` exists in the current working directory.
2. If the file does NOT exist, display:
   ```
   No Skynet project detected.
   ───────────────────────────
   Location:  {cwd}

   Run `init-project` to initialize this directory as a Skynet project.
   ```
   Stop here.

### Step 2 — Read and validate

1. Read `.skynet/project.json`.
2. Parse it as JSON.
3. If parsing fails, display:
   ```
   ✗ Error: `.skynet/project.json` exists but contains invalid JSON.
     The project configuration may be corrupted.
   ```
   Stop here.

### Step 3 — Display project summary

Display the project information in this format:

```
Skynet Project Detected
───────────────────────
Project:     {name}
Initialized: {initialized}
Status:      {status}
Skynet:      {skynetVersion}
Schema:      v{version}
Location:    {cwd}/.skynet/
```

Where each `{field}` is read from the parsed `project.json`.

## Notes

- This skill is read-only — it never modifies project configuration.
- All fields are read from `.skynet/project.json` in the current working directory.
- If the project was initialized with an older schema version, still display whatever fields are present.
