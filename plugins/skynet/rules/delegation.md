# Task Delegation Rules

How the orchestrator decides **when**, **to whom**, and **how** to delegate work to subagents.

## Mandatory Delegation

**Every task MUST be delegated to a sub-agent. No exceptions.**

The orchestrator NEVER executes tasks directly. It analyzes, delegates, and reports.

```
Does it require reading code, writing code, or running commands?
  → Delegate to Claude worker (or Codex worker as alternative).

Does it require web research, doc analysis, or data comparison?
  → Delegate to Gemini worker.

Does it require BOTH coding AND research?
  → Split into subtasks. Delegate in parallel to both workers.

Should the coding task use Codex instead of Claude?
  → Use Codex when: user explicitly requests it, Claude accounts exhausted,
    or task benefits from OpenAI models. Otherwise default to Claude.

Is the task ambiguous or too large?
  → STOP. Clarify with user first. Do NOT delegate unclear work.
```

## Worker Selection Matrix

| Signal in task | Worker | Why |
|---|---|---|
| "implement", "fix", "refactor", "add feature", "write test" | Claude | Code changes required |
| "review code", "find bugs", "optimize" | Claude | Needs code reasoning |
| "research", "compare", "summarize", "analyze docs" | Gemini | Information gathering |
| "what does X library do", "find best practice for Y" | Gemini | Web research |
| "add endpoint with docs" | Claude (code) + Gemini (docs) | Split: code + documentation |
| "investigate bug then fix" | Claude only | Single worker can read + fix |
| "implement with OpenAI", user requests Codex | Codex | Alternative coding worker |
| Claude accounts exhausted, coding task pending | Codex (fallback) | Failover from Claude |

### Anti-patterns

- **NEVER** send coding tasks to Gemini — it will return BLOCKED
- **NEVER** send research tasks to Claude — waste of a powerful coder
- **NEVER** send coding tasks to Codex when Claude is available and user hasn't requested Codex — Claude is the default coding worker
- **NEVER** use built-in Agent tool for delegation — MUST use external worker scripts (`create-task.sh` + `spawn-claude-worker.sh` / `spawn-gemini-worker.sh` / `spawn-codex-worker.sh`)
- **NEVER** self-handle any task — ALL work goes through sub-agents, sub-agents MUST delegate to external CLI

## Delegation Mechanism

All worker delegation MUST go through the external task system:

```
1. Create task brief:  scripts/create-task.sh <task-id> "<title>" <<< "<body>"
2. Spawn worker:       scripts/spawn-claude-worker.sh <task-id>    (coding — default)
                       scripts/spawn-codex-worker.sh <task-id>     (coding — alternative)
                       scripts/spawn-gemini-worker.sh <task-id>    (research)
3. Wait for result:    tmux wait-for (automatic via script)
```

**Built-in Agent tool is FORBIDDEN for all task execution.**

The ONLY permitted use of built-in Agent tool is spawning sub-agents (`skynet:worker-claude`, `skynet:worker-codex`, `skynet:worker-gemini`) which then MUST delegate to external CLI via scripts. Sub-agents are NOT allowed to execute tasks using their own tools — they exist solely as bridges to external workers.

## Task Brief Template

Every delegation MUST use this structure:

```markdown
ROLE: [Role the agent should assume for this task — e.g. "Security auditor", "Backend engineer"]
**Suggested agents:** <agent-name> — [why this agent is best suited]

## Task
[One sentence: what to do]

## Context
[Why this task exists. Link to relevant files, prior decisions, or user requirements]

## Scope
- IN: [what to touch]
- OUT: [what NOT to touch]

## Input Files
- `path/to/file.ts` — [why this file is relevant]

## Acceptance Criteria
1. [Specific, verifiable condition]
2. [Another condition]

## Constraints
- [Any technical constraints, style rules, or limitations]

**Suggested skills:** skill-a — [why], skill-b — [why]
```

### Brief Quality Rules

1. **Self-contained** — worker should NOT need to ask follow-up questions for well-defined tasks
2. **File paths are explicit** — don't say "the main file", say `src/index.ts`
3. **Acceptance criteria are testable** — "works correctly" is bad, "returns 200 with JSON body matching schema X" is good
4. **Context includes WHY** — workers make better decisions when they understand motivation
5. **Scope boundaries are clear** — prevent workers from over-engineering or touching unrelated code

## Parallel vs Sequential

```
Can subtasks run independently?
  YES → Delegate ALL in a single message (parallel Agent calls)
  NO  → Delegate sequentially, pass prior results as context

Examples:
  PARALLEL:  "Add login API" (Claude) + "Research OAuth providers" (Gemini)
  SEQUENTIAL: "Research best auth library" (Gemini) → "Implement auth with [result]" (Claude)
```

### Parallel Delegation Rules

- Launch all independent workers in ONE message with multiple Agent tool calls
- Each worker gets its own complete brief — no shared references between briefs
- After all complete, synthesize results before reporting to user

### Sequential Delegation Rules

- Wait for worker result before delegating next step
- Pass relevant findings from previous worker into next brief's Context section
- If a worker returns NEEDS_CLARIFICATION, resolve before continuing chain

## Result Handling

When a worker returns, the orchestrator MUST:

```
1. Read the Status field

   SUCCESS →
     - Verify output matches acceptance criteria (spot check, not re-do)
     - Report to user with concise summary
     - Proceed to next task if any

   NEEDS_CLARIFICATION →
     - Do NOT guess the answer
     - Forward worker's questions to user
     - Re-delegate with user's clarification

   QUALITY_FAILED →
     - Analyze what went wrong
     - Re-delegate with specific feedback (max 2 retries)
     - After 2 failures: escalate to user

   BLOCKED →
     - Check if blocker is resolvable (missing file? wrong branch?)
     - If resolvable: fix and re-delegate
     - If not: report to user with alternatives

   UNRECOVERABLE →
     - Stop immediately
     - Report full context to user
     - Wait for instructions
```

## Context Passing Rules

### What to include in every brief
- Relevant file paths (absolute, from project root)
- Current branch and any git context if relevant
- User's original intent (paraphrase, don't copy raw message)
- Related decisions or constraints from earlier in conversation

### What NOT to include
- Full conversation history — summarize relevant parts only
- Large file contents — reference paths, let worker read them
- Unrelated context — keep briefs focused
- Other workers' raw output — synthesize before passing

## Size Thresholds

| Task size | Behavior |
|---|---|
| **Trivial** (< 1 file, obvious change) | Delegate without confirmation |
| **Small** (1-3 files, clear scope) | Delegate directly, report after |
| **Medium** (3-10 files, some ambiguity) | Present plan to user, delegate after approval |
| **Large** (10+ files, architectural) | Enter Plan mode, break into phases, confirm each phase |

## Retry Policy

- **Max 2 retries** per worker per task
- Each retry MUST include specific feedback about what was wrong
- If same error repeats: different approach, not same prompt again
- After 2 retries: escalate to user, don't keep spinning

## Reporting to User

After delegation completes, report:

```
### [Task Name]
**Worker:** Claude/Gemini | **Status:** SUCCESS/FAILED/...
**Summary:** [1-2 sentences of what was done/found]
**Files changed:** [list if applicable]
**Next:** [what happens next, or "awaiting your input"]
```

Keep reports concise. User can ask for details if needed.
