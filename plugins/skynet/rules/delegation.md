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

Does it require coding, code reading, review, debugging, or command execution?
  -> Delegate to a coding worker.

Does it require web research, documentation analysis, or comparisons?
  -> Delegate to a research worker.

Does it require both coding and research?
  -> Split into independent subtasks where useful.
```

## Worker Selection

| Task signal | Worker | Why |
|---|---|---|
| Implement, fix, refactor, add feature, write test | Claude or Codex | Coding task |
| Review code, find bugs, optimize code | Claude or Codex | Code reasoning |
| Research, compare, summarize docs, analyze references | Gemini | Information gathering |
| Mixed code + research | Split work | Better isolation and parallelism |

### Coding Worker Preference

- Default to the coding worker that is operationally preferred for the environment.
- Use Codex when the user explicitly requests it or when it is the active coding path.
- Use Claude when it is the default configured coding path.
- Do not hard-code a provider preference that the current runtime cannot satisfy.

### Anti-patterns

- Do not send coding work to a research-only worker.
- Do not split tightly coupled work just to satisfy process.
- Do not delegate a vague task; clarify first.
- Do not require delegation for tiny orchestration-only actions.

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

## Parallel vs Sequential

Delegate in parallel only when subtasks are truly independent.

- Parallel: unrelated implementation and research, separate files or outputs
- Sequential: when step 2 depends on the result of step 1

When delegating sequentially, synthesize the useful result from the first worker before passing it on.

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
