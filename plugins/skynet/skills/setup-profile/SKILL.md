---
name: setup-profile
description: Guided project operating profile creation
tools: Read, Write
---

# setup-profile

Create or reconfigure the project operating profile through guided conversation.

## Usage

Invoke this skill to define project type, team mode, workflow rigor, role coverage, and provider preferences. The profile is saved to `.skynet/profile.json`.

## Instructions

### Pre-checks

1. Check if `.skynet/project.json` exists in the current working directory.
   - If it does NOT exist, display: "No Skynet project found. Run `init-project` first." **Stop.**
   - If it exists but contains invalid JSON, display: "`.skynet/project.json` is corrupted. Re-initialize with `init-project`." **Stop.**

2. Check if `.skynet/profile.json` already exists.
   - If it exists, read it and display a summary of the current profile.
   - Ask: "A profile already exists. Do you want to reconfigure it? (yes/no)"
   - If the user declines → display "Keeping existing profile." **Stop.**
   - If the user confirms → proceed (the profile will be overwritten).

### Section 1 — Project Basics

3. Ask: "What type of project is this?"

   Options:
   - `web-app` — Web application (frontend, backend, or full-stack)
   - `api` — API service or backend
   - `cli` — Command-line tool
   - `library` — Reusable library or package
   - `monorepo` — Multi-package repository
   - `mobile` — Mobile application
   - `data` — Data pipeline, analytics, or ML project
   - `other` — Anything else

4. Ask: "Describe your project in one sentence."

5. Ask: "What is your team mode?"

   Options:
   - `solo` — One person doing everything
   - `small-team` — 2-5 people, informal coordination
   - `structured-team` — Formal roles and handoffs

### Section 2 — Workflow Rigor

6. Ask: "How strict should the workflow be?"

   Options:
   - `minimal` — Skip formal approvals, move fast
   - `standard` — Basic review and testing gates
   - `strict` — All workflow stages enforced, approvals required

### Section 3 — Role Coverage

7. Present the role table and ask the user to assign coverage:

   ```
   For each role, tell me who covers it:
   - human:    you or your team handles this
   - ai:       Skynet handles this autonomously
   - shared:   both human and AI collaborate
   - disabled: skip this role entirely

   Roles:
   1. PM  (Project Manager) — delivery coordination, timeline
   2. PO  (Product Owner) — requirements, prioritization
   3. BA  (Business Analyst) — requirement clarification, acceptance criteria
   4. SA  (Solution Architect) — technical design, architecture decisions
   5. Dev (Developer) — implementation
   6. QA  (Quality Assurance) — testing, validation
   ```

8. Accept answers in any natural format. Parse using these rules:

   **Parsing Rules:**

   | User says | Interpretation |
   |-----------|---------------|
   | "I handle PM and architecture, AI does everything else" | PM=human, SA=human, PO=ai, BA=ai, Dev=ai, QA=ai |
   | "Just use AI for everything" | All roles = ai |
   | "PM is mine, PO shared, disable BA, rest AI" | PM=human, PO=shared, BA=disabled, SA=ai, Dev=ai, QA=ai |
   | "I'm solo, I do the architecture and product decisions" | SA=human, PO=human, PM=ai, BA=ai, Dev=ai, QA=ai |
   | "I'm the developer, AI helps with everything else" | Dev=human, PM=ai, PO=ai, BA=ai, SA=ai, QA=ai |
   | "Human team does PM, PO, BA. AI does Dev and QA. SA is shared." | PM=human, PO=human, BA=human, SA=shared, Dev=ai, QA=ai |

   - "architecture" or "architect" maps to the SA role.
   - "product" or "product decisions" maps to the PO role.
   - "testing" maps to QA.
   - "development" or "coding" maps to Dev.
   - If a role is not mentioned, default to `ai`.
   - If you cannot confidently parse the answer, re-ask for that specific role.

9. After parsing, display the interpreted role table and ask user to confirm:
   ```
   Here is how I interpreted your role coverage:

   PM  (Project Manager):      {coverage}
   PO  (Product Owner):        {coverage}
   BA  (Business Analyst):     {coverage}
   SA  (Solution Architect):   {coverage}
   Dev (Developer):            {coverage}
   QA  (Quality Assurance):    {coverage}

   Is this correct? (yes/no)
   ```
   If the user says no, re-ask for role coverage.

### Section 4 — Provider Preferences

10. Ask: "What is your primary AI provider?" (e.g., Claude, GPT, Gemini, or other)

11. Ask: "Any notes about your provider setup?" (e.g., "Pro subscription", "API key only", "multiple accounts"). This is optional — the user can skip.

### Confirmation

12. Display a full summary of all collected information:
    ```
    Profile Summary
    ───────────────
    Project Type:  {type}
    Description:   {description}
    Team Mode:     {teamMode}
    Rigor:         {rigor}

    Role Coverage:
      PM:   {coverage}
      PO:   {coverage}
      BA:   {coverage}
      SA:   {coverage}
      Dev:  {coverage}
      QA:   {coverage}

    Provider:      {primary}
    Notes:         {notes}
    ```

13. Ask: "Does this look correct? (yes / edit / cancel)"
    - `yes` → proceed to persist
    - `edit` → ask which section to revise (1: Project Basics, 2: Workflow Rigor, 3: Role Coverage, 4: Provider Preferences), re-collect that section, then show summary again
    - `cancel` → display "Profile setup cancelled. No changes made." **Stop.**

### Persist

14. Build the profile JSON using this template:

    ```json
    {
      "version": "0.1.0",
      "createdAt": "{ISO 8601 timestamp}",
      "updatedAt": "{ISO 8601 timestamp}",
      "project": {
        "type": "{collected value}",
        "description": "{collected value}",
        "teamMode": "{collected value}"
      },
      "workflow": {
        "rigor": "{collected value}",
        "description": "{auto-generated based on rigor}"
      },
      "roles": {
        "PM":  { "coverage": "{collected}" },
        "PO":  { "coverage": "{collected}" },
        "BA":  { "coverage": "{collected}" },
        "SA":  { "coverage": "{collected}" },
        "Dev": { "coverage": "{collected}" },
        "QA":  { "coverage": "{collected}" }
      },
      "providers": {
        "primary": "{collected}",
        "notes": "{collected or empty string}"
      }
    }
    ```

    Auto-generated workflow descriptions:
    - `minimal` → "Skip formal approvals, move fast"
    - `standard` → "Basic review and testing gates"
    - `strict` → "All workflow stages enforced, approvals required"

    If reconfiguring an existing profile, preserve the original `createdAt` value and only update `updatedAt`.

15. Write the JSON to `.skynet/profile.json`.

16. Read `.skynet/project.json`, update `status` to `"configured"` and `updatedAt` to the current ISO 8601 timestamp, then write it back.

17. Display success message:
    ```
    Project Profile Configured
    ──────────────────────────
    Project:  {name from project.json}
    Type:     {project.type}
    Team:     {teamMode}
    Rigor:    {workflow.rigor}
    Roles:    {count} configured
    Provider: {providers.primary}
    Status:   Profile saved

    Skynet will use this profile to guide delegation and workflow decisions.
    ```

## Error Handling

| Scenario | Detection | Message |
|----------|-----------|---------|
| No project initialized | `.skynet/project.json` missing | "No Skynet project found. Run `init-project` first." |
| Profile already exists | `.skynet/profile.json` exists | Show current profile, ask to reconfigure or keep |
| Write permission denied | Write tool fails | "Cannot write profile — check directory permissions." |
| User cancels mid-flow | User says cancel/stop at any point | "Profile setup cancelled. No changes made." |
| Ambiguous role answers | Cannot confidently parse coverage | Re-ask with explicit per-role options |
| Empty/skipped sections | User skips a question | Defaults: type=other, teamMode=solo, rigor=standard, all roles=ai, provider="not specified" |
| project.json corrupted | Invalid JSON in project.json | "`.skynet/project.json` is corrupted. Re-initialize with `init-project`." |

## Notes

- This skill is conversational — ask one section at a time. Do not dump all questions at once.
- Always confirm the parsed role coverage with the user before writing.
- The profile is a planning input — it does not directly change Skynet's runtime behavior yet.
- Provider preferences are free-text placeholders, not validated against real provider inventory.
- All file paths are relative to the user's current working directory.