#!/usr/bin/env bats
# ── tasks.bats — comprehensive test suite for plugins/skynet/lib/tasks.sh ──

setup() {
  # Create a fresh temp root for each test
  TEST_DIR=$(mktemp -d)
  export SKYNET_HOME="$TEST_DIR/skynet"
  export TASK_DIR="$TEST_DIR/tasks"
  mkdir -p "$SKYNET_HOME" "$SKYNET_HOME/credentials"

  # Create default config.json with task_dir pointing to TASK_DIR
  python3 -c "
import json
cfg = {
  'default_strategy': 'round-robin',
  'rate_limit_ttl_seconds': 300,
  'max_retries': 2,
  'task_dir': '$TASK_DIR'
}
with open('$SKYNET_HOME/config.json', 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
"

  # Create workers.json with several workers at various states
  cat > "$SKYNET_HOME/workers.json" <<'EOF'
{
  "version": 1,
  "workers": [
    {
      "name": "my-claude",
      "provider": "claude",
      "status": "active",
      "credentials": {}
    },
    {
      "name": "my-gemini",
      "provider": "gemini",
      "status": "active",
      "credentials": {}
    },
    {
      "name": "my-codex",
      "provider": "codex",
      "status": "active",
      "credentials": {}
    },
    {
      "name": "paused-worker",
      "provider": "claude",
      "status": "paused",
      "credentials": {}
    },
    {
      "name": "rate-limited-worker",
      "provider": "claude",
      "status": "rate_limited",
      "credentials": {}
    }
  ]
}
EOF

  # Create mock CLIs in a temp bin dir
  MOCK_BIN="$TEST_DIR/bin"
  mkdir -p "$MOCK_BIN"

  # Mock claude: echoes back the prompt text (success)
  cat > "$MOCK_BIN/claude" <<'SCRIPT'
#!/usr/bin/env bash
# Parse -p flag
while [ $# -gt 0 ]; do
  case "$1" in
    -p) prompt="$2"; shift 2 ;;
    --dangerously-skip-permissions) shift ;;
    *) shift ;;
  esac
done
echo "mock claude output: $prompt"
SCRIPT
  chmod +x "$MOCK_BIN/claude"

  # Mock gemini (success)
  cat > "$MOCK_BIN/gemini" <<'SCRIPT'
#!/usr/bin/env bash
# Parse -p flag
while [ $# -gt 0 ]; do
  case "$1" in
    -p) prompt="$2"; shift 2 ;;
    --yolo|--screen-reader) shift ;;
    --output-format) shift 2 ;;
    *) shift ;;
  esac
done
echo "mock gemini output: $prompt"
SCRIPT
  chmod +x "$MOCK_BIN/gemini"

  # Mock codex (success)
  cat > "$MOCK_BIN/codex" <<'SCRIPT'
#!/usr/bin/env bash
# Skip 'exec' subcommand and flags, take last arg as prompt
prompt="${@: -1}"
echo "mock codex output: $prompt"
SCRIPT
  chmod +x "$MOCK_BIN/codex"

  # Prepend mock bin to PATH so our mocks shadow any real CLIs
  export PATH="$MOCK_BIN:$PATH"

  # Source the libraries (SKYNET_HOME is already exported so workers.sh picks it up)
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  # shellcheck source=/dev/null
  source "$PLUGIN_DIR/lib/common.sh"
  # shellcheck source=/dev/null
  source "$PLUGIN_DIR/lib/workers.sh"
  # shellcheck source=/dev/null
  source "$PLUGIN_DIR/lib/tasks.sh"

  # Override constant now that libraries are sourced
  TASK_DIR_DEFAULT="$TASK_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# ─────────────────────────────────────────────────────────────────────────────
# Group 1: _get_task_dir
# ─────────────────────────────────────────────────────────────────────────────

@test "_get_task_dir: returns configured task_dir from config" {
  run _get_task_dir
  [ "$status" -eq 0 ]
  [ "$output" = "$TASK_DIR" ]
}

@test "_get_task_dir: returns default when config missing" {
  # Remove config so the else-branch fires
  rm -f "$SKYNET_CONFIG"
  run _get_task_dir
  [ "$status" -eq 0 ]
  # Should equal TASK_DIR_DEFAULT (we set it to $TASK_DIR above, but the
  # in-code constant is set at source time; test that it returns *some* value
  # that looks like a path ending in "tasks")
  [[ "$output" == *tasks* ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Group 2: _ensure_task_dir
# ─────────────────────────────────────────────────────────────────────────────

@test "_ensure_task_dir: creates task directory" {
  [ ! -d "$TASK_DIR" ]  # pre-condition
  _ensure_task_dir
  [ -d "$TASK_DIR" ]
}

@test "_ensure_task_dir: creates .gitignore in task dir" {
  _ensure_task_dir
  [ -f "$TASK_DIR/.gitignore" ]
  grep -q '^\*$' "$TASK_DIR/.gitignore"
  grep -q '^!\.gitignore$' "$TASK_DIR/.gitignore"
}

@test "_ensure_task_dir: idempotent — does not overwrite existing .gitignore" {
  _ensure_task_dir
  # Add a custom line
  echo "custom-marker" >> "$TASK_DIR/.gitignore"
  # Call again
  _ensure_task_dir
  # Custom line must still be present
  grep -q "custom-marker" "$TASK_DIR/.gitignore"
}

# ─────────────────────────────────────────────────────────────────────────────
# Group 3: task_create — validation failures
# ─────────────────────────────────────────────────────────────────────────────

@test "task_create: fails when worker does not exist" {
  run task_create "no-such-worker" "Do something"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "worker"
}

@test "task_create: fails when worker is paused" {
  run task_create "paused-worker" "Do something"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "not active\|paused"
}

@test "task_create: fails when worker is rate_limited" {
  run task_create "rate-limited-worker" "Do something"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "not active\|rate"
}

@test "task_create: fails when not initialized (SKYNET_HOME missing)" {
  rm -rf "$SKYNET_HOME"
  # workers.sh variables still point to the (now-removed) paths;
  # worker_exists will fail to open workers.json → task_create should fail
  run task_create "my-claude" "Do something"
  [ "$status" -ne 0 ]
}

# ─────────────────────────────────────────────────────────────────────────────
# Group 4: task_create — success cases
# ─────────────────────────────────────────────────────────────────────────────

@test "task_create: creates task directory" {
  task_id=$(task_create "my-claude" "Fix bug")
  [ -d "$TASK_DIR/$task_id" ]
}

@test "task_create: creates meta.json with correct structure" {
  task_id=$(task_create "my-claude" "Fix bug")
  meta_file="$TASK_DIR/$task_id/meta.json"
  [ -f "$meta_file" ]
  # All required fields present
  python3 -c "
import json, sys
with open('$meta_file') as f:
    d = json.load(f)
required = ['id', 'worker', 'provider', 'prompt', 'status', 'created_at', 'finished_at', 'exit_code']
missing = [k for k in required if k not in d]
if missing:
    print('Missing fields:', missing, file=sys.stderr)
    sys.exit(1)
"
}

@test "task_create: sets status to pending" {
  task_id=$(task_create "my-claude" "Fix bug")
  meta_file="$TASK_DIR/$task_id/meta.json"
  python3 -c "
import json, sys
with open('$meta_file') as f:
    d = json.load(f)
assert d['status'] == 'pending', f'expected pending, got {d[\"status\"]}'
"
}

@test "task_create: sets created_at to ISO-8601 UTC timestamp" {
  task_id=$(task_create "my-claude" "Fix bug")
  meta_file="$TASK_DIR/$task_id/meta.json"
  python3 -c "
import json, re, sys
with open('$meta_file') as f:
    d = json.load(f)
ts = d['created_at']
pattern = r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$'
assert re.match(pattern, ts), f'bad timestamp format: {ts}'
"
}

@test "task_create: sets finished_at to null" {
  task_id=$(task_create "my-claude" "Fix bug")
  meta_file="$TASK_DIR/$task_id/meta.json"
  python3 -c "
import json, sys
with open('$meta_file') as f:
    d = json.load(f)
assert d['finished_at'] is None, f'expected None, got {d[\"finished_at\"]}'
"
}

@test "task_create: sets exit_code to null" {
  task_id=$(task_create "my-claude" "Fix bug")
  meta_file="$TASK_DIR/$task_id/meta.json"
  python3 -c "
import json, sys
with open('$meta_file') as f:
    d = json.load(f)
assert d['exit_code'] is None, f'expected None, got {d[\"exit_code\"]}'
"
}

@test "task_create: task_id format matches task-[0-9]+-[a-f0-9]{8}" {
  task_id=$(task_create "my-claude" "Fix bug")
  echo "$task_id" | grep -qE '^task-[0-9]+-[a-f0-9]{8}$'
}

@test "task_create: outputs task_id to stdout (non-empty)" {
  run task_create "my-claude" "Fix bug"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [[ "$output" =~ ^task- ]]
}

@test "task_create: records correct provider from worker registry" {
  task_id=$(task_create "my-gemini" "Fix bug")
  meta_file="$TASK_DIR/$task_id/meta.json"
  python3 -c "
import json, sys
with open('$meta_file') as f:
    d = json.load(f)
assert d['provider'] == 'gemini', f'expected gemini, got {d[\"provider\"]}'
"
}

# ─────────────────────────────────────────────────────────────────────────────
# Group 5: task_update_status
# ─────────────────────────────────────────────────────────────────────────────

@test "task_update_status: fails when task does not exist" {
  run task_update_status "task-0000000000-nonexist" "running"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "task not found\|not found"
}

@test "task_update_status: updates status field" {
  task_id=$(task_create "my-claude" "Fix bug")
  task_update_status "$task_id" "running"
  meta_file="$TASK_DIR/$task_id/meta.json"
  python3 -c "
import json, sys
with open('$meta_file') as f:
    d = json.load(f)
assert d['status'] == 'running', f'expected running, got {d[\"status\"]}'
"
}

@test "task_update_status: does not set finished_at for running status" {
  task_id=$(task_create "my-claude" "Fix bug")
  task_update_status "$task_id" "running"
  meta_file="$TASK_DIR/$task_id/meta.json"
  python3 -c "
import json, sys
with open('$meta_file') as f:
    d = json.load(f)
assert d['finished_at'] is None, f'expected None, got {d[\"finished_at\"]}'
"
}

@test "task_update_status: sets finished_at for completed status" {
  task_id=$(task_create "my-claude" "Fix bug")
  task_update_status "$task_id" "completed" "0"
  meta_file="$TASK_DIR/$task_id/meta.json"
  python3 -c "
import json, re, sys
with open('$meta_file') as f:
    d = json.load(f)
ts = d['finished_at']
assert ts is not None, 'finished_at should not be None for completed'
pattern = r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$'
assert re.match(pattern, ts), f'bad timestamp: {ts}'
"
}

@test "task_update_status: sets finished_at for failed status" {
  task_id=$(task_create "my-claude" "Fix bug")
  task_update_status "$task_id" "failed" "1"
  meta_file="$TASK_DIR/$task_id/meta.json"
  python3 -c "
import json, re, sys
with open('$meta_file') as f:
    d = json.load(f)
ts = d['finished_at']
assert ts is not None, 'finished_at should not be None for failed'
pattern = r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$'
assert re.match(pattern, ts), f'bad timestamp: {ts}'
"
}

@test "task_update_status: sets exit_code when provided" {
  task_id=$(task_create "my-claude" "Fix bug")
  task_update_status "$task_id" "failed" "42"
  meta_file="$TASK_DIR/$task_id/meta.json"
  python3 -c "
import json, sys
with open('$meta_file') as f:
    d = json.load(f)
assert d['exit_code'] == 42, f'expected 42, got {d[\"exit_code\"]}'
"
}

@test "task_update_status: sets exit_code to null when not provided" {
  task_id=$(task_create "my-claude" "Fix bug")
  task_update_status "$task_id" "running"
  meta_file="$TASK_DIR/$task_id/meta.json"
  python3 -c "
import json, sys
with open('$meta_file') as f:
    d = json.load(f)
assert d['exit_code'] is None, f'expected None, got {d[\"exit_code\"]}'
"
}

@test "task_update_status: meta.json is valid JSON after update (atomic write)" {
  task_id=$(task_create "my-claude" "Fix bug")
  task_update_status "$task_id" "running"
  task_update_status "$task_id" "completed" "0"
  meta_file="$TASK_DIR/$task_id/meta.json"
  python3 -c "
import json, sys
with open('$meta_file') as f:
    d = json.load(f)
# Just loading without error confirms valid JSON
"
}

# ─────────────────────────────────────────────────────────────────────────────
# Group 6: task_get
# ─────────────────────────────────────────────────────────────────────────────

@test "task_get: fails when task does not exist" {
  run task_get "task-0000000000-nonexist"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "task not found\|not found"
}

@test "task_get: outputs valid JSON" {
  task_id=$(task_create "my-claude" "Fix bug")
  run task_get "$task_id"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}

@test "task_get: output contains correct task_id" {
  task_id=$(task_create "my-claude" "Fix bug")
  run task_get "$task_id"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['id'] == '$task_id', f'expected $task_id, got {d[\"id\"]}'
"
}

# ─────────────────────────────────────────────────────────────────────────────
# Group 7: task_output
# ─────────────────────────────────────────────────────────────────────────────

@test "task_output: fails when output.txt does not exist" {
  task_id=$(task_create "my-claude" "Fix bug")
  run task_output "$task_id"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "no output\|not found"
}

@test "task_output: outputs content of output.txt" {
  task_id=$(task_create "my-claude" "Fix bug")
  output_dir="$TASK_DIR/$task_id"
  echo "hello from output" > "$output_dir/output.txt"
  run task_output "$task_id"
  [ "$status" -eq 0 ]
  [ "$output" = "hello from output" ]
}

# ─────────────────────────────────────────────────────────────────────────────
# Group 8: task_run_sync — full execution
# ─────────────────────────────────────────────────────────────────────────────

@test "task_run_sync: fails when task does not exist" {
  run task_run_sync "task-0000000000-nonexist"
  [ "$status" -ne 0 ]
}

@test "task_run_sync: status is completed after successful run" {
  task_id=$(task_create "my-claude" "Fix bug")
  task_run_sync "$task_id"
  meta_file="$TASK_DIR/$task_id/meta.json"
  python3 -c "
import json, sys
with open('$meta_file') as f:
    d = json.load(f)
assert d['status'] == 'completed', f'expected completed, got {d[\"status\"]}'
"
}

@test "task_run_sync: creates output.txt with CLI output" {
  task_id=$(task_create "my-claude" "Fix bug")
  task_run_sync "$task_id"
  output_file="$TASK_DIR/$task_id/output.txt"
  [ -f "$output_file" ]
  grep -q "mock claude output" "$output_file"
}

@test "task_run_sync: creates error.txt" {
  task_id=$(task_create "my-claude" "Fix bug")
  task_run_sync "$task_id"
  [ -f "$TASK_DIR/$task_id/error.txt" ]
}

@test "task_run_sync: returns exit 0 on success" {
  task_id=$(task_create "my-claude" "Fix bug")
  run task_run_sync "$task_id"
  [ "$status" -eq 0 ]
}

@test "task_run_sync: updates status to failed when CLI exits non-zero" {
  # Replace mock claude with a failing version
  cat > "$MOCK_BIN/claude" <<'SCRIPT'
#!/usr/bin/env bash
echo "error output" >&2
exit 1
SCRIPT
  chmod +x "$MOCK_BIN/claude"

  task_id=$(task_create "my-claude" "Fix bug")
  task_run_sync "$task_id" || true
  meta_file="$TASK_DIR/$task_id/meta.json"
  python3 -c "
import json, sys
with open('$meta_file') as f:
    d = json.load(f)
assert d['status'] == 'failed', f'expected failed, got {d[\"status\"]}'
"
}

@test "task_run_sync: records non-zero exit_code in meta.json on failure" {
  cat > "$MOCK_BIN/claude" <<'SCRIPT'
#!/usr/bin/env bash
exit 2
SCRIPT
  chmod +x "$MOCK_BIN/claude"

  task_id=$(task_create "my-claude" "Fix bug")
  task_run_sync "$task_id" || true
  meta_file="$TASK_DIR/$task_id/meta.json"
  python3 -c "
import json, sys
with open('$meta_file') as f:
    d = json.load(f)
assert d['exit_code'] == 2, f'expected 2, got {d[\"exit_code\"]}'
"
}

@test "task_run_sync: propagates non-zero exit code on failure" {
  cat > "$MOCK_BIN/claude" <<'SCRIPT'
#!/usr/bin/env bash
exit 3
SCRIPT
  chmod +x "$MOCK_BIN/claude"

  task_id=$(task_create "my-claude" "Fix bug")
  run task_run_sync "$task_id"
  [ "$status" -ne 0 ]
}

# ─────────────────────────────────────────────────────────────────────────────
# Group 9: _dispatch routing
# ─────────────────────────────────────────────────────────────────────────────

@test "_dispatch: routes claude provider to _dispatch_claude" {
  out_file=$(mktemp)
  err_file=$(mktemp)
  _dispatch "my-claude" "hello" "$out_file" "$err_file"
  grep -q "mock claude output" "$out_file"
  rm -f "$out_file" "$err_file"
}

@test "_dispatch: routes gemini provider to _dispatch_gemini" {
  out_file=$(mktemp)
  err_file=$(mktemp)
  _dispatch "my-gemini" "hello" "$out_file" "$err_file"
  grep -q "mock gemini output" "$out_file"
  rm -f "$out_file" "$err_file"
}

@test "_dispatch: routes codex provider to _dispatch_codex" {
  out_file=$(mktemp)
  err_file=$(mktemp)
  _dispatch "my-codex" "hello" "$out_file" "$err_file"
  grep -q "mock codex output" "$out_file"
  rm -f "$out_file" "$err_file"
}

@test "_dispatch: fails on unknown provider" {
  # Inject a worker with a bogus provider directly into workers.json
  python3 -c "
import json
with open('$SKYNET_WORKERS') as f:
    d = json.load(f)
d['workers'].append({'name': 'bad-worker', 'provider': 'unknown-provider', 'status': 'active', 'credentials': {}})
with open('$SKYNET_WORKERS', 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
"
  out_file=$(mktemp)
  err_file=$(mktemp)
  run _dispatch "bad-worker" "hello" "$out_file" "$err_file"
  [ "$status" -ne 0 ]
  rm -f "$out_file" "$err_file"
}

# ─────────────────────────────────────────────────────────────────────────────
# Group 10: _dispatch_claude credentials
# ─────────────────────────────────────────────────────────────────────────────

@test "_dispatch_claude: runs without token_file when credentials empty" {
  out_file=$(mktemp)
  err_file=$(mktemp)
  # my-claude has empty credentials — should succeed using mock claude
  run _dispatch_claude "my-claude" "hello world" "$out_file" "$err_file"
  [ "$status" -eq 0 ]
  grep -q "mock claude output" "$out_file"
  rm -f "$out_file" "$err_file"
}

@test "_dispatch_claude: uses CLAUDE_CODE_OAUTH_TOKEN when token_file set" {
  # Inject a token file into credentials and update worker registry
  token_content="test-oauth-token-value"
  echo "$token_content" > "$SKYNET_HOME/credentials/my-claude.token"

  # Update worker registry so my-claude has a token_file credential
  python3 -c "
import json
with open('$SKYNET_WORKERS') as f:
    d = json.load(f)
for w in d['workers']:
    if w['name'] == 'my-claude':
        w['credentials'] = {'token_file': 'my-claude.token'}
        break
with open('$SKYNET_WORKERS', 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
"

  # Replace mock claude with one that echoes the token env var so we can
  # verify the token was actually set on the environment
  cat > "$MOCK_BIN/claude" <<'SCRIPT'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do
  case "$1" in
    -p) prompt="$2"; shift 2 ;;
    --dangerously-skip-permissions) shift ;;
    *) shift ;;
  esac
done
echo "token=${CLAUDE_CODE_OAUTH_TOKEN} prompt=${prompt}"
SCRIPT
  chmod +x "$MOCK_BIN/claude"

  out_file=$(mktemp)
  err_file=$(mktemp)
  _dispatch_claude "my-claude" "hello" "$out_file" "$err_file"
  grep -q "token=$token_content" "$out_file"
  rm -f "$out_file" "$err_file"
}
