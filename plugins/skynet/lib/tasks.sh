#!/usr/bin/env bash
# ── tasks.sh — task lifecycle management ───────────────────
# Requires: common.sh, workers.sh (sourced before this file)

# ── Constants ──────────────────────────────────────────────
TASK_DIR_DEFAULT="./tasks"

# ── Helpers ────────────────────────────────────────────────
_get_task_dir() {
  local task_dir
  if [ -f "$SKYNET_CONFIG" ]; then
    task_dir=$(config_read "task_dir" 2>/dev/null || echo "$TASK_DIR_DEFAULT")
  else
    task_dir="$TASK_DIR_DEFAULT"
  fi
  echo "$task_dir"
}

_ensure_task_dir() {
  local task_dir
  task_dir=$(_get_task_dir)
  if [ ! -d "$task_dir" ]; then
    mkdir -p "$task_dir"
  fi
  if [ ! -f "$task_dir/.gitignore" ]; then
    printf '*\n!.gitignore\n' > "$task_dir/.gitignore"
  fi
}

# ── Task CRUD ──────────────────────────────────────────────
task_create() {
  local worker_name="$1" prompt="$2"

  # Validate worker exists
  if ! worker_exists "$worker_name"; then
    fail "Worker not found: $worker_name"
    return 1
  fi

  # Validate worker is active
  local status
  status=$(_FILE="$SKYNET_WORKERS" _NAME="$worker_name" python3 -c "
import json, os
with open(os.environ['_FILE']) as f:
    d = json.load(f)
for w in d['workers']:
    if w['name'] == os.environ['_NAME']:
        print(w['status'])
        break
")
  if [ "$status" != "active" ]; then
    fail "Worker is not active: $worker_name (status: $status)"
    return 1
  fi

  # Generate task ID
  local uuid_short
  uuid_short=$(python3 -c "import uuid; print(str(uuid.uuid4())[:8])")
  local task_id="task-$(date +%s)-${uuid_short}"

  # Ensure task directory
  _ensure_task_dir

  local task_dir
  task_dir=$(_get_task_dir)
  mkdir -p "$task_dir/$task_id"

  # Read provider from worker registry
  local provider
  provider=$(_FILE="$SKYNET_WORKERS" _NAME="$worker_name" python3 -c "
import json, os
with open(os.environ['_FILE']) as f:
    d = json.load(f)
for w in d['workers']:
    if w['name'] == os.environ['_NAME']:
        print(w['provider'])
        break
")

  # Create meta.json (atomic write)
  local meta_file="$task_dir/$task_id/meta.json"
  local tmp
  tmp="$(mktemp "${meta_file}.XXXXXX")"
  _ID="$task_id" _WORKER="$worker_name" _PROVIDER="$provider" _PROMPT="$prompt" _TMP="$tmp" python3 -c "
import json, os
from datetime import datetime, timezone
meta = {
    'id': os.environ['_ID'],
    'worker': os.environ['_WORKER'],
    'provider': os.environ['_PROVIDER'],
    'prompt': os.environ['_PROMPT'],
    'status': 'pending',
    'created_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'finished_at': None,
    'exit_code': None
}
with open(os.environ['_TMP'], 'w') as f:
    json.dump(meta, f, indent=2)
    f.write('\n')
"
  mv "$tmp" "$meta_file"

  # Print task_id to stdout for callers to capture
  echo "$task_id"
}

task_update_status() {
  local task_id="$1" status="$2" exit_code="${3:-null}"

  local task_dir
  task_dir=$(_get_task_dir)
  local meta_file="$task_dir/$task_id/meta.json"

  if [ ! -f "$meta_file" ]; then
    fail "Task not found: $task_id"
    return 1
  fi

  local tmp
  tmp="$(mktemp "${meta_file}.XXXXXX")"
  _FILE="$meta_file" _STATUS="$status" _EXIT="$exit_code" _TMP="$tmp" python3 -c "
import json, os
from datetime import datetime, timezone
with open(os.environ['_FILE']) as f:
    d = json.load(f)
d['status'] = os.environ['_STATUS']
exit_val = os.environ['_EXIT']
if exit_val == 'null':
    d['exit_code'] = None
else:
    d['exit_code'] = int(exit_val)
if os.environ['_STATUS'] in ('completed', 'failed'):
    d['finished_at'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
with open(os.environ['_TMP'], 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
"
  mv "$tmp" "$meta_file"
}

task_get() {
  local task_id="$1"

  local task_dir
  task_dir=$(_get_task_dir)
  local meta_file="$task_dir/$task_id/meta.json"

  if [ ! -f "$meta_file" ]; then
    fail "Task not found: $task_id"
    return 1
  fi

  _FILE="$meta_file" python3 -c "
import json, os
with open(os.environ['_FILE']) as f:
    d = json.load(f)
print(json.dumps(d, indent=2))
"
}

task_output() {
  local task_id="$1"

  local task_dir
  task_dir=$(_get_task_dir)
  local output_file="$task_dir/$task_id/output.txt"

  if [ ! -f "$output_file" ]; then
    fail "No output found for task: $task_id"
    return 1
  fi

  cat "$output_file"
}

# ── Dispatch ───────────────────────────────────────────────
_dispatch_claude() {
  local worker_name="$1" prompt="$2" output_file="$3" error_file="$4"

  if ! command -v claude &>/dev/null; then
    fail "claude CLI not found"
    return 127
  fi

  # Read token_file from worker registry
  local worker_info
  worker_info=$(_FILE="$SKYNET_WORKERS" _NAME="$worker_name" python3 -c "
import json, os
with open(os.environ['_FILE']) as f:
    d = json.load(f)
for w in d['workers']:
    if w['name'] == os.environ['_NAME']:
        creds = w.get('credentials', {})
        token_file = creds.get('token_file', '')
        sa_file = creds.get('credentials_file') or creds.get('service_account', '')
        auth = creds.get('auth', '')
        print(f\"{w['provider']}|{token_file}|{sa_file}|{auth}\")
        break
")
  local provider token_file sa_file auth
  IFS='|' read -r provider token_file sa_file auth <<< "$worker_info"

  local exit_code=0
  if [ -n "$token_file" ] && [ "$token_file" != "None" ]; then
    CLAUDE_CODE_OAUTH_TOKEN=$(cat "$SKYNET_CREDENTIALS/$token_file") claude --dangerously-skip-permissions -p "$prompt" > "$output_file" 2> "$error_file" || exit_code=$?
  else
    claude --dangerously-skip-permissions -p "$prompt" > "$output_file" 2> "$error_file" || exit_code=$?
  fi
  return $exit_code
}

_dispatch_gemini() {
  local worker_name="$1" prompt="$2" output_file="$3" error_file="$4"

  if ! command -v gemini &>/dev/null; then
    fail "gemini CLI not found"
    return 127
  fi

  # Read credentials_file from worker registry
  local worker_info
  worker_info=$(_FILE="$SKYNET_WORKERS" _NAME="$worker_name" python3 -c "
import json, os
with open(os.environ['_FILE']) as f:
    d = json.load(f)
for w in d['workers']:
    if w['name'] == os.environ['_NAME']:
        creds = w.get('credentials', {})
        token_file = creds.get('token_file', '')
        sa_file = creds.get('credentials_file') or creds.get('service_account', '')
        auth = creds.get('auth', '')
        print(f\"{w['provider']}|{token_file}|{sa_file}|{auth}\")
        break
")
  local provider token_file sa_file auth
  IFS='|' read -r provider token_file sa_file auth <<< "$worker_info"

  local exit_code=0
  if [ -n "$sa_file" ] && [ "$sa_file" != "None" ]; then
    local cred_path="$SKYNET_CREDENTIALS/$sa_file"
    GOOGLE_APPLICATION_CREDENTIALS="$cred_path" gemini --yolo --screen-reader --output-format text -p "$prompt" > "$output_file" 2> "$error_file" || exit_code=$?
  else
    gemini --yolo --screen-reader --output-format text -p "$prompt" > "$output_file" 2> "$error_file" || exit_code=$?
  fi
  return $exit_code
}

_dispatch_codex() {
  local worker_name="$1" prompt="$2" output_file="$3" error_file="$4"

  if ! command -v codex &>/dev/null; then
    fail "codex CLI not found"
    return 127
  fi

  local exit_code=0
  codex exec --dangerously-bypass-approvals-and-sandbox "$prompt" > "$output_file" 2> "$error_file" || exit_code=$?
  return $exit_code
}

_dispatch() {
  local worker_name="$1" prompt="$2" output_file="$3" error_file="$4"

  # Read provider from worker registry
  local provider
  provider=$(_FILE="$SKYNET_WORKERS" _NAME="$worker_name" python3 -c "
import json, os
with open(os.environ['_FILE']) as f:
    d = json.load(f)
for w in d['workers']:
    if w['name'] == os.environ['_NAME']:
        print(w['provider'])
        break
")

  case "$provider" in
    claude) _dispatch_claude "$worker_name" "$prompt" "$output_file" "$error_file" ;;
    gemini) _dispatch_gemini "$worker_name" "$prompt" "$output_file" "$error_file" ;;
    codex)  _dispatch_codex  "$worker_name" "$prompt" "$output_file" "$error_file" ;;
    *)
      fail "Unknown provider: $provider"
      return 1
      ;;
  esac
}

# ── Task execution ─────────────────────────────────────────
task_run_sync() {
  local task_id="$1"

  local task_dir
  task_dir=$(_get_task_dir)
  local meta_file="$task_dir/$task_id/meta.json"

  if [ ! -f "$meta_file" ]; then
    fail "Task not found: $task_id"
    return 1
  fi

  # Read worker and prompt from meta.json
  local worker
  worker=$(_FILE="$meta_file" python3 -c "
import json, os
with open(os.environ['_FILE']) as f:
    d = json.load(f)
print(d['worker'])
")
  local prompt
  prompt=$(_FILE="$meta_file" python3 -c "
import json, os
with open(os.environ['_FILE']) as f:
    d = json.load(f)
import sys
sys.stdout.write(d['prompt'])
")

  # Update status to running
  task_update_status "$task_id" "running"

  # Dispatch
  local output_file="$task_dir/$task_id/output.txt"
  local error_file="$task_dir/$task_id/error.txt"
  local exit_code=0
  _dispatch "$worker" "$prompt" "$output_file" "$error_file" || exit_code=$?

  # Update status based on result
  if [ $exit_code -eq 0 ]; then
    task_update_status "$task_id" "completed" "0"
  else
    task_update_status "$task_id" "failed" "$exit_code"
  fi

  return $exit_code
}
