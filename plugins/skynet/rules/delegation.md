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

- Ideal pool: `2 Claude + 3 Gemini`
- Current pool: `1 Claude + 1 Codex + 3 Gemini`
- Treat available capacity as part of the routing decision:
  - research = up to 3 parallel Gemini lanes
  - coding = up to 2 parallel lanes across Claude and Codex
  - synthesis and final validation stay with the orchestrator

| Task signal | Worker | Why |
|---|---|---|
| Implement, fix, refactor, add feature, write test | Claude or Codex | Coding task |
| Review code, find bugs, optimize code | Claude first, Codex second | Code reasoning with lane priority |
| Research, compare, summarize docs, analyze references | Gemini | Information gathering |
| Mixed code + research | Split work by dependency | Better isolation and parallelism |

### Coding Worker Preference

- Prefer Claude for ambiguous, iterative, or high-judgment tasks.
- Prefer Codex for bounded implementation, mechanical refactors, isolated edits, or second-pass review.
- Use Codex to absorb overflow when Claude is already occupied by the critical path.
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
- Do not consume Claude on work that Codex or Gemini can finish with lower coordination cost.
- Do not idle Gemini capacity during research-heavy work if parallel tracks exist.
- Do not start two coding lanes unless file ownership and acceptance criteria are clearly separable.

## Delegation Mechanism

Use one execution path consistently within the current environment.

- If the external worker scripts are available and healthy, use them.
- If the platform's agent system is the supported execution path, use that.
- Do not mix multiple delegation mechanisms in the same step unless there is a clear reason.

Document the chosen mechanism in the brief or status update when it matters for debugging.

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

- Use Claude for higher ambiguity or debugging
- Use Codex for bounded execution-heavy work
- Use Gemini in parallel only for supporting research

#### Two coding streams in parallel

This is the current best-case coding setup with `1 Claude + 1 Codex`.

- Claude handles the harder or more stateful lane
- Codex handles the narrower or more isolated lane
- Gemini can support both lanes with verification or references

#### Mixed research + coding

- Start Gemini immediately on independent research
- Start coding immediately only for the part that does not depend on research output
- If coding depends on research, pass a synthesized result forward rather than raw worker output

#### Review / audit

- Claude: primary deep review
- Codex: secondary independent coding review when useful
- Gemini: external standard, docs, or version verification

### Capacity-Aware Priority Rules

1. Reserve Claude for tasks that benefit most from deeper reasoning or clarification loops.
2. Use Codex before queueing a second non-critical Claude-class coding task.
3. Prioritize coding work in this order:
   - critical-path coding
   - bounded parallel coding
   - non-critical follow-up coding
4. Prioritize research work in this order:
   - high-uncertainty research that gates implementation
   - risk-reduction or verification research
   - optional comparison or nice-to-have research
5. Rebalance when a worker blocks:
   - Claude blocked -> move bounded remainder to Codex if possible
   - Codex blocked -> avoid stealing Claude from critical-path work unless the task is small
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
