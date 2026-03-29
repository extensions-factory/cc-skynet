---
name: show-profile
description: Display current project profile
tools: Read
---

# show-profile

Display the current project operating profile.

## Usage

Invoke this skill to inspect the project profile at any time — useful to verify configuration or review role assignments.

## Instructions

### Step 1 — Check for project

1. Check if `.skynet/project.json` exists in the current working directory.
2. If the file does NOT exist, display:
   ```
   No Skynet project detected.
   ───────────────────────────
   Location:  {cwd}

   Run `init-project` to initialize this directory as a Skynet project.
   ```
   Stop here.

### Step 2 — Check for profile

1. Check if `.skynet/profile.json` exists.
2. If the file does NOT exist, display:
   ```
   Project initialized but no profile configured.
   ──────────────────────────────────────────────
   Project:  {name from project.json}
   Status:   {status from project.json}

   Run `setup-profile` to create your project operating profile.
   ```
   Stop here.

### Step 3 — Read and validate

1. Read `.skynet/profile.json`.
2. Parse it as JSON.
3. If parsing fails, display:
   ```
   Error: `.skynet/profile.json` exists but contains invalid JSON.
   The profile may be corrupted. Run `setup-profile` to recreate it.
   ```
   Stop here.
4. Also read `.skynet/project.json` for the project name.

### Step 4 — Display profile

Display the profile in this format:

```
Skynet Project Profile
──────────────────────
Project:     {name from project.json}
Type:        {project.type}
Description: {project.description}
Team Mode:   {project.teamMode}
Rigor:       {workflow.rigor}

Role Coverage
─────────────
PM:   {roles.PM.coverage}
PO:   {roles.PO.coverage}
BA:   {roles.BA.coverage}
SA:   {roles.SA.coverage}
Dev:  {roles.Dev.coverage}
QA:   {roles.QA.coverage}

Provider Preferences
────────────────────
Primary: {providers.primary}
Notes:   {providers.notes}

Profile:  v{version}
Created:  {createdAt}
Updated:  {updatedAt}
```

Where each `{field}` is read from the parsed JSON files.

## Notes

- This skill is read-only — it never modifies any files.
- All fields are read from `.skynet/profile.json` and `.skynet/project.json` in the current working directory.
- If the profile was created with an older schema version, still display whatever fields are present.
- If any field is missing from the JSON, display "not specified" for that field.