# Pool Profile: 2 Claude + 3 Gemini

Load this profile only when the current session actually has:

- 2 Claude lanes
- 3 Gemini lanes

## Intent

This pool is optimized for:

- heavier use of Claude across hard coding lanes
- Claude-to-Claude pairing on risky work when independent verification is valuable
- Gemini handling research and external validation in parallel

## Routing Rules

### Research

- Route research, docs lookup, comparisons, and external verification to Gemini
- Use up to 3 Gemini lanes in parallel when tracks are truly independent

### Single Coding Stream

- Use Claude for the primary implementation on medium or hard coding tasks
- Use the second Claude lane for verification when the task is risky, architecture-sensitive, or expensive to get wrong
- For tiny or routine edits, one Claude lane is enough and a second pass is optional

### Two Coding Streams

- Use both Claude lanes for the two harder parallel coding tracks when that is the best fit
- If only one coding stream exists, use `Claude implements -> Claude verifies` for risky work
- Do not force artificial separation just to keep both Claude lanes busy

### Review / Audit

- One Claude can run the primary deep review
- The second Claude can run independent verification or adversarial review
- Gemini can verify external docs, versions, upstream behavior, or standards

## Scheduling Priorities

1. Critical-path coding
2. Independent Claude verification for risky or important code
3. Secondary Claude execution lane for parallel high-judgment work
4. Non-critical follow-up work

## Anti-Patterns

- Do not underuse the second Claude lane on genuinely hard work
- Do not default to Codex-style routing assumptions when Codex is not in the active pool
- Do not spend both Claude lanes on low-risk routine edits unless there is no higher-value work pending
