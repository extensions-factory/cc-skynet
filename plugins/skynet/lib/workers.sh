#!/usr/bin/env bash
# ── workers.sh — worker registry and config management ───

# ── Constants ────────────────────────────────────────────
SKYNET_HOME="${SKYNET_HOME:-$HOME/.claude/skynet}"
SKYNET_CONFIG="$SKYNET_HOME/config.json"
SKYNET_WORKERS="$SKYNET_HOME/workers.json"
SKYNET_CREDENTIALS="$SKYNET_HOME/credentials"
VALID_PROVIDERS=("claude" "gemini" "codex")
VALID_STATES=("active" "paused" "rate_limited")

# ── Config defaults ──────────────────────────────────────
readonly DEFAULT_CONFIG='{
  "default_strategy": "round-robin",
  "rate_limit_ttl_seconds": 300,
  "max_retries": 2,
  "task_dir": "./tasks"
}'

readonly DEFAULT_WORKERS='{
  "version": 1,
  "workers": []
}'

# ── Ensure directories ──────────────────────────────────
ensure_skynet_home() {
  if [ ! -d "$SKYNET_HOME" ]; then
    mkdir -p "$SKYNET_HOME"
    chmod 0700 "$SKYNET_HOME"
  fi
  if [ ! -d "$SKYNET_CREDENTIALS" ]; then
    mkdir -p "$SKYNET_CREDENTIALS"
    chmod 0700 "$SKYNET_CREDENTIALS"
  fi
}

# ── Config management ────────────────────────────────────
ensure_config() {
  if [ ! -f "$SKYNET_CONFIG" ]; then
    printf '%s\n' "$DEFAULT_CONFIG" > "$SKYNET_CONFIG"
    chmod 0600 "$SKYNET_CONFIG"
    return 0  # created
  fi
  return 1  # already exists
}

ensure_workers_registry() {
  if [ ! -f "$SKYNET_WORKERS" ]; then
    printf '%s\n' "$DEFAULT_WORKERS" > "$SKYNET_WORKERS"
    chmod 0600 "$SKYNET_WORKERS"
    return 0  # created
  fi
  return 1  # already exists
}

# Read a config value
config_read() {
  local key="$1"
  _FILE="$SKYNET_CONFIG" _KEY="$key" python3 -c "
import json, os, functools, operator
with open(os.environ['_FILE']) as f:
    d = json.load(f)
keys = os.environ['_KEY'].split('.')
print(functools.reduce(operator.getitem, keys, d))
"
}

# Write a config value (atomic)
config_write() {
  local key="$1" value="$2"
  local tmp
  tmp="$(mktemp "${SKYNET_CONFIG}.XXXXXX")"
  _FILE="$SKYNET_CONFIG" _KEY="$key" _VAL="$value" _TMP="$tmp" python3 -c "
import json, os
with open(os.environ['_FILE']) as f:
    d = json.load(f)
keys = os.environ['_KEY'].split('.')
val = os.environ['_VAL']
# Try to parse as JSON (for numbers, booleans, etc)
try:
    val = json.loads(val)
except (json.JSONDecodeError, ValueError):
    pass
obj = d
for k in keys[:-1]:
    obj = obj[k]
obj[keys[-1]] = val
with open(os.environ['_TMP'], 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
"
  mv "$tmp" "$SKYNET_CONFIG"
}

# ── Init check ──────────────────────────────────────────
is_initialized() {
  [ -d "$SKYNET_HOME" ] && [ -f "$SKYNET_CONFIG" ] && [ -f "$SKYNET_WORKERS" ]
}

# ── Validation ──────────────────────────────────────────
_validate_worker_name() {
  local name="$1"
  # kebab-case, lowercase, max 64 chars
  if [ ${#name} -gt 64 ]; then
    fail "Worker name too long (max 64 chars): $name"
    return 1
  fi
  if ! [[ "$name" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
    fail "Invalid worker name (use kebab-case): $name"
    return 1
  fi
}

_validate_provider() {
  local provider="$1"
  local valid
  for valid in "${VALID_PROVIDERS[@]}"; do
    [ "$valid" = "$provider" ] && return 0
  done
  fail "Invalid provider: $provider (valid: ${VALID_PROVIDERS[*]})"
  return 1
}

# ── Worker CRUD ─────────────────────────────────────────
worker_exists() {
  local name="$1"
  _FILE="$SKYNET_WORKERS" _NAME="$name" python3 -c "
import json, os, sys
with open(os.environ['_FILE']) as f:
    d = json.load(f)
name = os.environ['_NAME']
sys.exit(0 if any(w['name'] == name for w in d['workers']) else 1)
"
}

worker_get() {
  local name="$1"
  _FILE="$SKYNET_WORKERS" _NAME="$name" python3 -c "
import json, os, sys
with open(os.environ['_FILE']) as f:
    d = json.load(f)
name = os.environ['_NAME']
for w in d['workers']:
    if w['name'] == name:
        print(json.dumps(w, indent=2))
        sys.exit(0)
sys.exit(1)
"
}

worker_add() {
  local name="$1" provider="$2"
  shift 2

  # Parse optional credential args
  local oauth_token="" service_account=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --oauth-token) oauth_token="$2"; shift 2 ;;
      --service-account) service_account="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  # Validate
  _validate_worker_name "$name" || return 1
  _validate_provider "$provider" || return 1

  if worker_exists "$name"; then
    fail "Worker already exists: $name"
    return 1
  fi

  # Build credentials based on provider
  local cred_json="{}"
  case "$provider" in
    claude)
      if [ -n "$oauth_token" ]; then
        # Store token to credential file
        local token_file="$SKYNET_CREDENTIALS/claude-${name}.token"
        printf '%s' "$oauth_token" > "$token_file"
        chmod 0600 "$token_file"
        cred_json="{\"token_file\": \"claude-${name}.token\"}"
      elif [ -n "${CLAUDE_OAUTH_TOKEN:-}" ]; then
        local token_file="$SKYNET_CREDENTIALS/claude-${name}.token"
        printf '%s' "$CLAUDE_OAUTH_TOKEN" > "$token_file"
        chmod 0600 "$token_file"
        cred_json="{\"token_file\": \"claude-${name}.token\"}"
      else
        warn "No OAuth token provided. Set --oauth-token or CLAUDE_OAUTH_TOKEN env."
        cred_json="{\"token_file\": null}"
      fi
      ;;
    gemini)
      if [ -n "$service_account" ]; then
        if [ ! -f "$service_account" ]; then
          fail "Service account file not found: $service_account"
          return 1
        fi
        # Copy to credentials dir
        local sa_file="gemini-${name}.json"
        cp "$service_account" "$SKYNET_CREDENTIALS/$sa_file"
        chmod 0600 "$SKYNET_CREDENTIALS/$sa_file"
        cred_json="{\"service_account\": \"${sa_file}\"}"
      else
        warn "No service account provided. Use --service-account <path>."
        cred_json="{\"service_account\": null}"
      fi
      ;;
    codex)
      # Codex uses subscription login (no API key needed)
      # Enforce single Codex worker per machine
      if _FILE="$SKYNET_WORKERS" python3 -c "
import json, os, sys
with open(os.environ['_FILE']) as f:
    d = json.load(f)
sys.exit(0 if any(w['provider'] == 'codex' for w in d['workers']) else 1)
"; then
        fail "Only one Codex worker per machine. Remove existing codex worker first."
        return 1
      fi
      cred_json="{\"auth\": \"subscription\"}"
      ;;
  esac

  # Atomic add to registry
  local tmp
  tmp="$(mktemp "${SKYNET_WORKERS}.XXXXXX")"
  _FILE="$SKYNET_WORKERS" _NAME="$name" _PROVIDER="$provider" _CRED="$cred_json" _TMP="$tmp" python3 -c "
import json, os
from datetime import datetime, timezone
with open(os.environ['_FILE']) as f:
    d = json.load(f)
worker = {
    'name': os.environ['_NAME'],
    'provider': os.environ['_PROVIDER'],
    'status': 'active',
    'created_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'credentials': json.loads(os.environ['_CRED']),
    'rate_limit': None
}
d['workers'].append(worker)
with open(os.environ['_TMP'], 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
"
  mv "$tmp" "$SKYNET_WORKERS"
  ok "Added worker: $name (provider: $provider, status: active)"
}

worker_remove() {
  local name="$1"

  if ! worker_exists "$name"; then
    fail "Worker not found: $name"
    return 1
  fi

  # Get provider for credential cleanup
  local provider
  provider=$(_FILE="$SKYNET_WORKERS" _NAME="$name" python3 -c "
import json, os
with open(os.environ['_FILE']) as f:
    d = json.load(f)
for w in d['workers']:
    if w['name'] == os.environ['_NAME']:
        print(w['provider'])
        break
")

  # Remove credential files
  case "$provider" in
    claude)
      rm -f "$SKYNET_CREDENTIALS/claude-${name}.token"
      ;;
    gemini)
      rm -f "$SKYNET_CREDENTIALS/gemini-${name}.json"
      ;;
  esac

  # Atomic remove from registry
  local tmp
  tmp="$(mktemp "${SKYNET_WORKERS}.XXXXXX")"
  _FILE="$SKYNET_WORKERS" _NAME="$name" _TMP="$tmp" python3 -c "
import json, os
with open(os.environ['_FILE']) as f:
    d = json.load(f)
d['workers'] = [w for w in d['workers'] if w['name'] != os.environ['_NAME']]
with open(os.environ['_TMP'], 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
"
  mv "$tmp" "$SKYNET_WORKERS"
  ok "Removed worker: $name"
}

worker_list() {
  local format="${1:-table}"

  if [ ! -f "$SKYNET_WORKERS" ]; then
    fail "Worker system not initialized. Run: skynet init"
    return 1
  fi

  if [ "$format" = "--json" ]; then
    _FILE="$SKYNET_WORKERS" python3 -c "
import json, os
with open(os.environ['_FILE']) as f:
    d = json.load(f)
print(json.dumps(d['workers'], indent=2))
"
    return 0
  fi

  # Table format
  _FILE="$SKYNET_WORKERS" python3 -c "
import json, os
with open(os.environ['_FILE']) as f:
    d = json.load(f)
workers = d['workers']
if not workers:
    print('No workers registered. Add one with: genisys add <name> --provider <claude|gemini|codex>')
else:
    print(f'{'Name':<20} {'Provider':<10} {'Status':<15} {'Created':>20}')
    print('-' * 67)
    for w in workers:
        created = w.get('created_at', 'N/A')[:10]
        print(f'{w[\"name\"]:<20} {w[\"provider\"]:<10} {w[\"status\"]:<15} {created:>20}')
    print(f'\nTotal: {len(workers)} worker(s)')
"
}

worker_count() {
  _FILE="$SKYNET_WORKERS" python3 -c "
import json, os
with open(os.environ['_FILE']) as f:
    d = json.load(f)
print(len(d['workers']))
"
}
