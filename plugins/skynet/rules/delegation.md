# Task Delegation Rules

How the orchestrator decides when to delegate, to whom, and how much process to add.

## Core Principle

Delegate execution work when it benefits from specialization, isolation, or parallelism.

The orchestrator may handle these directly:
- clarifying the user's intent
- presenting a plan
- synthesizing worker results
- giving short status updates
- performing tiny administrative actions that do not benefit from delegation

Implementation, research, code review, and command-heavy work should usually be delegated.

## Decision Flow

```
Is the request unclear in a way that changes the approach?
  -> Clarify with the user first.

Is it orchestration-only work?
  -> Handle directly.

Can the work be classified into coding, review, research, synthesis, or mixed?
  -> Classify before selecting workers.

Does it require coding, code reading, review, debugging, or command execution?
  -> Delegate to a coding worker.

Does it require web research, documentation analysis, or comparisons?
  -> Delegate to a research worker.

Does it require both coding and research?
  -> Split into independent subtasks where useful.
```

## Worker Selection

### Capacity Model

- Treat available capacity as part of the routing decision:
  - research = up to 3 parallel Gemini lanes
  - coding = use the actual available coding lanes in the pool
  - synthesis and final validation stay with the orchestrator

| Task signal | Worker | Why |
|---|---|---|
| Implement, fix, refactor, add feature, write test | A coding worker chosen from the active pool | Execution lane should match task complexity |
| Review code, find bugs, optimize code | A review-capable coding worker chosen from the active pool | Review lane should match risk and available capacity |
| Research, compare, summarize docs, analyze references | Gemini | Information gathering |
| Mixed code + research | Split work by dependency | Better isolation and parallelism |

### Coding Worker Preference

- Prefer the coding worker whose strengths best match the task shape and current pool capacity.
- Prefer the stronger reasoning lane for ambiguous, iterative, architecture-sensitive, or debug-heavy tasks.
- Prefer the cheaper or more execution-oriented lane for bounded implementation, mechanical refactors, isolated edits, test writing, and routine follow-up fixes.
- Use a separate verification lane when risk, complexity, or change impact justifies it.
- Do not plan around a second Claude lane unless it actually exists.
- Do not hard-code a provider preference that the current runtime cannot satisfy.

### Research Worker Preference

- Use Gemini for docs lookup, web research, comparisons, migration notes, and external validation.
- Use up to 3 Gemini workers in parallel only when the research tracks are truly independent.
- If there are more than 3 research subtasks, batch them by uncertainty and criticality.

### Anti-patterns

- Do not send coding work to a research-only worker.
- Do not split tightly coupled work just to satisfy process.
- Do not delegate a vague task; clarify first.
- Do not require delegation for tiny orchestration-only actions.
- Do not consume a stronger reasoning lane on work that a lower-cost coding lane or Gemini can finish with lower coordination cost.
- Do not idle Gemini capacity during research-heavy work if parallel tracks exist.
- Do not start two coding lanes unless file ownership and acceptance criteria are clearly separable.

## Delegation Mechanism

**Workers MUST delegate ALL execution work to external CLI instances via spawn scripts. No exceptions.**

The execution path is:

```
Orchestrator → Agent tool (worker subagent) → Bash → spawn script → external CLI (tmux) → results via .pipe/ + .output/
```

### Mandatory Rules

1. Worker subagents (`worker-claude`, `worker-codex`, `worker-gemini`) exist ONLY as bridges to external CLIs — they call `create-task.sh` + `spawn-*-worker.sh`, parse output, and report results.
2. Workers MUST NOT use their own tools (Read, Write, Edit, Grep, Glob) to execute task work directly. These tools are available only for: reading spawn script output, checking task status files, and parsing results.
3. The orchestrator MUST NOT bypass workers by doing implementation, research, or review work directly — even if it seems faster or simpler.
4. If spawn scripts are unavailable or broken, workers MUST return `BLOCKED` — never fall back to internal execution.
5. Do not mix delegation mechanisms in the same step.

### Verification

A correctly delegated task always produces:
- A task file in `tasks/` (via `create-task.sh`)
- A signal file in `tasks/.pipe/` (from spawn script)
- An output file in `tasks/.output/` (from external CLI)

If these artifacts are missing, the delegation was not executed correctly.

## Task Brief Template

Use this template for medium or large delegated tasks. For small tasks, a shorter brief is acceptable if it still includes the essentials.

```markdown
ROLE: [role for this task]

## Task
[one-sentence objective]

## Context
[why this task exists and what constraints matter]

## Scope
- IN: [what may be touched]
- OUT: [what must not be touched]

## Input Files
- `path/to/file.ts` - [why it matters]

## Acceptance Criteria
1. [specific, verifiable condition]
2. [specific, verifiable condition]

## Constraints
- [technical or process constraints]

**Suggested skills:** skill-a, skill-b
```

### Brief Quality Rules

1. Make the brief self-contained.
2. Use explicit file paths.
3. Keep acceptance criteria testable.
4. Include enough context for good decisions, not the whole conversation.
5. Keep scope boundaries clear.
6. When parallelizing, state why this lane is independent from the others.

## Parallel vs Sequential

Delegate in parallel only when subtasks are truly independent.

- Parallel: unrelated implementation and research, separate files or outputs
- Sequential: when step 2 depends on the result of step 1

When delegating sequentially, synthesize the useful result from the first worker before passing it on.

### Practical Scheduling Scenarios

#### Research-heavy task

- Use Gemini first
- Run up to 3 research lanes in parallel
- Keep Claude and Codex free unless coding can begin immediately

#### Single coding stream

- Pick the primary coding worker based on complexity, ambiguity, and current pool capacity
- Add a verification lane only when the task is important enough to justify a second pass
- Use Gemini in parallel only for supporting research

#### Two coding streams in parallel

- Pick lanes based on the actual pool composition
- Put the harder or more stateful lane on the stronger reasoning worker
- Put the narrower or better-isolated lane on the worker with lower coordination cost
- Gemini can support coding lanes with verification context or references

#### Mixed research + coding

- Start Gemini immediately on independent research
- Start coding immediately only for the part that does not depend on research output
- If coding depends on research, pass a synthesized result forward rather than raw worker output

#### Review / audit

- Use the strongest reasoning lane for primary deep review
- Use a second coding lane for independent verification or overflow review when useful
- Gemini: external standard, docs, or version verification

### Capacity-Aware Priority Rules

1. Reserve the strongest reasoning lane for tasks that benefit most from deeper reasoning, clarification loops, or verification of important code changes.
2. Use the lower-cost execution lane before queueing a non-critical high-judgment execution task.
3. Prioritize coding work in this order:
   - critical-path coding
   - verification for high-value or risky changes
   - bounded parallel coding
   - non-critical follow-up coding
4. Prioritize research work in this order:
   - high-uncertainty research that gates implementation
   - risk-reduction or verification research
   - optional comparison or nice-to-have research
5. Rebalance when a worker blocks:
   - stronger reasoning lane blocked -> keep routine execution moving on the available coding lane and skip verification unless risk is high
   - bounded execution lane blocked -> move only the necessary remainder to the stronger reasoning lane
   - Gemini blocked -> narrow scope and continue with the highest-signal source

## Result Handling

When a worker returns:

- `SUCCESS`: spot-check the output against the acceptance criteria, then report the result
- `NEEDS_CLARIFICATION`: ask the user only the missing question, then re-delegate
- `QUALITY_FAILED`: retry with concrete feedback, up to 2 retries
- `BLOCKED`: resolve simple environmental blockers if possible; otherwise report the blocker and options
- `UNRECOVERABLE`: stop and escalate to the user

## Context Passing

Include when relevant:
- file paths relative to the project root, or absolute paths if the execution tool requires them
- branch or git context
- the user's intent in paraphrased form
- earlier decisions that constrain the task

Do not include:
- full conversation transcripts
- large file contents unless required
- unrelated context
- raw output from other workers when a short synthesis is enough

## Size Thresholds

| Task size | Behavior |
|---|---|
| Trivial | Handle directly or delegate immediately, whichever is cheaper |
| Small | Delegate directly if useful; otherwise handle inline |
| Medium | Present a short plan, then execute or delegate |
| Large | Break into phases, confirm the plan, then execute phase by phase |

## Reporting

After a delegated step completes, report:

```markdown
### [Task Name]
**Worker:** [worker name]
**Status:** SUCCESS / FAILED / BLOCKED / ...
**Summary:** [1-2 sentences]
**Files changed:** [list if applicable]
**Next:** [next action]
```

Keep reports concise and action-oriented.
