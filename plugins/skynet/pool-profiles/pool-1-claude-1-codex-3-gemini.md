# Pool Profile: 1 Claude + 1 Codex + 3 Gemini

Load this profile only when the current session actually has:

- 1 Claude lane
- 1 Codex lane
- 3 Gemini lanes

## Intent

This pool is optimized for:

- `Codex` as the default primary execution lane for ordinary coding
- `Claude` reserved for high-judgment execution or verification
- `Gemini` used aggressively for independent research lanes

## Routing Rules

### Research

- Route research, docs lookup, comparisons, and external verification to Gemini
- Use up to 3 Gemini lanes in parallel when tracks are truly independent

### Single Coding Stream

- Default path: `Codex implements -> Claude verifies`
- Skip Claude verification for very small or low-risk changes when coordination cost is not justified
- Route the primary implementation to Claude only if the task is ambiguous, debug-heavy, architecture-sensitive, or likely to require clarification loops

### Two Coding Streams

- Use Codex for the bounded or more isolated implementation lane
- Use Claude for the harder lane, or keep Claude as verifier for Codex if that gives better risk reduction
- Do not split into two coding lanes unless ownership and acceptance criteria are clearly separable

### Review / Audit

- Claude is the default deep review lane
- Codex can provide bounded overflow review or implementation-oriented review
- Gemini can verify docs, versions, upstream behavior, or standards

## Scheduling Priorities

1. Critical-path coding
2. Claude verification for risky or important code
3. Bounded parallel coding on Codex
4. Non-critical follow-up work

## Anti-Patterns

- Do not spend Claude on routine primary execution if `Codex -> Claude verify` is enough
- Do not leave Gemini idle during research-heavy tasks
- Do not queue trivial verification work behind a critical Claude task
