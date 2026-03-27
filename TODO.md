# TODO — Skynet Task Engine

## Dispatch Issues (identified 2026-03-27)

### 1. ARG_MAX limit on prompt
- Prompt is passed directly as CLI argument (`-p "$prompt"`)
- macOS ARG_MAX ~2MB — long prompts will fail with `Argument list too long`
- **Fix**: pipe prompt via stdin or write to temp file, pass file path instead

### 2. No system prompt / context injection
- Workers receive only the raw user prompt
- No project context, rules, conventions, or CLAUDE.md content injected
- **Fix**: build a composite prompt with system context + user prompt before dispatch

### 3. No explicit working directory
- Worker CLI runs in whatever CWD `legion` was called from
- No guarantee it's the project root
- **Fix**: accept `--cwd` flag or resolve project root, `cd` before dispatch

## Task Engine Gaps

### 4. Sync-only execution
- `task_run_sync` blocks until CLI finishes — no `task_run_async`
- **Fix**: implement background execution with PID tracking

### 5. No retry logic
- `config.json` has `max_retries: 2` but it's not implemented
- **Fix**: wrap dispatch in retry loop with backoff

### 6. No auto rate-limit detection
- If CLI fails due to rate-limit (HTTP 429), worker is not auto-set to `rate_limited`
- **Fix**: parse stderr/exit code for rate-limit signals, call `worker_rate_limit`

### 7. No round-robin / worker selection
- `config.json` has `default_strategy: "round-robin"` but it's not implemented
- **Fix**: implement strategy engine that picks next available worker

### 8. No completion callback
- No way to notify when a task finishes (besides polling)
- **Fix**: support `--on-complete` hook or webhook URL
