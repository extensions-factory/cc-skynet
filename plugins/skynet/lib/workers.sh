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
      --service-account|--credentials) service_account="$2"; shift 2 ;;
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
        local token_file="$SKYNET_CREDENTIALS/${name}.token"
        printf '%s' "$oauth_token" > "$token_file"
        chmod 0600 "$token_file"
        cred_json="{\"token_file\": \"${name}.token\"}"
      elif [ -n "${CLAUDE_OAUTH_TOKEN:-}" ]; then
        local token_file="$SKYNET_CREDENTIALS/${name}.token"
        printf '%s' "$CLAUDE_OAUTH_TOKEN" > "$token_file"
        chmod 0600 "$token_file"
        cred_json="{\"token_file\": \"${name}.token\"}"
      else
        warn "No OAuth token provided. Set --oauth-token or CLAUDE_OAUTH_TOKEN env."
        cred_json="{\"token_file\": null}"
      fi
      ;;
    gemini)
      if [ -n "$service_account" ]; then
        if [ ! -f "$service_account" ]; then
          fail "Credentials file not found: $service_account"
          return 1
        fi
        # Copy to credentials dir
        local cred_file="${name}.json"
        cp "$service_account" "$SKYNET_CREDENTIALS/$cred_file"
        chmod 0600 "$SKYNET_CREDENTIALS/$cred_file"
        cred_json="{\"credentials_file\": \"${cred_file}\"}"
      else
        warn "No credentials file provided. Use --credentials <path> (OAuth JSON from gcloud auth)."
        cred_json="{\"credentials_file\": null}"
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

  # Remove credential files (read actual filename from registry)
  local cred_file
  cred_file=$(_FILE="$SKYNET_WORKERS" _NAME="$name" python3 -c "
import json, os
with open(os.environ['_FILE']) as f:
    d = json.load(f)
for w in d['workers']:
    if w['name'] == os.environ['_NAME']:
        creds = w.get('credentials', {})
        f = creds.get('token_file') or creds.get('credentials_file') or creds.get('service_account') or ''
        print(f)
        break
")
  if [ -n "$cred_file" ] && [ "$cred_file" != "None" ]; then
    rm -f "$SKYNET_CREDENTIALS/$cred_file"
  fi

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

# ── Worker Lifecycle ────────────────────────────────────────
worker_set_status() {
  local name="$1" new_status="$2"

  if ! worker_exists "$name"; then
    fail "Worker not found: $name"
    return 1
  fi

  # Validate status
  local valid
  local found=false
  for valid in "${VALID_STATES[@]}"; do
    [ "$valid" = "$new_status" ] && found=true
  done
  if [ "$found" = "false" ]; then
    fail "Invalid status: $new_status (valid: ${VALID_STATES[*]})"
    return 1
  fi

  local tmp
  tmp="$(mktemp "${SKYNET_WORKERS}.XXXXXX")"
  _FILE="$SKYNET_WORKERS" _NAME="$name" _STATUS="$new_status" _TMP="$tmp" python3 -c "
import json, os
with open(os.environ['_FILE']) as f:
    d = json.load(f)
for w in d['workers']:
    if w['name'] == os.environ['_NAME']:
        w['status'] = os.environ['_STATUS']
        if os.environ['_STATUS'] != 'rate_limited':
            w['rate_limit'] = None
        break
with open(os.environ['_TMP'], 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
"
  mv "$tmp" "$SKYNET_WORKERS"
}

worker_pause() {
  local name="$1"
  worker_set_status "$name" "paused"
  ok "Paused worker: $name"
}

worker_resume() {
  local name="$1"
  worker_set_status "$name" "active"
  ok "Resumed worker: $name"
}

worker_rate_limit() {
  local name="$1"
  local duration="${2:-}"

  if ! worker_exists "$name"; then
    fail "Worker not found: $name"
    return 1
  fi

  # Default TTL from config or 300 seconds
  if [ -z "$duration" ]; then
    if [ -f "$SKYNET_CONFIG" ]; then
      duration=$(config_read "rate_limit_ttl_seconds" 2>/dev/null || echo "300")
    else
      duration="300"
    fi
  fi

  local tmp
  tmp="$(mktemp "${SKYNET_WORKERS}.XXXXXX")"
  _FILE="$SKYNET_WORKERS" _NAME="$name" _DUR="$duration" _TMP="$tmp" python3 -c "
import json, os
from datetime import datetime, timezone, timedelta
with open(os.environ['_FILE']) as f:
    d = json.load(f)
dur = int(os.environ['_DUR'])
until = (datetime.now(timezone.utc) + timedelta(seconds=dur)).strftime('%Y-%m-%dT%H:%M:%SZ')
for w in d['workers']:
    if w['name'] == os.environ['_NAME']:
        w['status'] = 'rate_limited'
        w['rate_limit'] = {'until': until, 'duration_seconds': dur}
        break
with open(os.environ['_TMP'], 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
"
  mv "$tmp" "$SKYNET_WORKERS"
  ok "Rate-limited worker: $name (${duration}s TTL)"
}

worker_check_rate_limits() {
  # Auto-resume workers whose rate_limit TTL has expired
  if [ ! -f "$SKYNET_WORKERS" ]; then
    return 0
  fi

  local tmp
  tmp="$(mktemp "${SKYNET_WORKERS}.XXXXXX")"
  local resumed
  resumed=$(_FILE="$SKYNET_WORKERS" _TMP="$tmp" python3 -c "
import json, os
from datetime import datetime, timezone
with open(os.environ['_FILE']) as f:
    d = json.load(f)
now = datetime.now(timezone.utc)
resumed = []
for w in d['workers']:
    if w['status'] == 'rate_limited' and w.get('rate_limit') and w['rate_limit'].get('until'):
        until = datetime.strptime(w['rate_limit']['until'], '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
        if now >= until:
            w['status'] = 'active'
            w['rate_limit'] = None
            resumed.append(w['name'])
with open(os.environ['_TMP'], 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
print(','.join(resumed))
")
  mv "$tmp" "$SKYNET_WORKERS"

  if [ -n "$resumed" ]; then
    local IFS=','
    for name in $resumed; do
      info "Auto-resumed worker: $name (rate-limit expired)"
    done
  fi
}

worker_test() {
  local name="$1"

  if ! worker_exists "$name"; then
    fail "Worker not found: $name"
    return 1
  fi

  # Read provider and credential info from registry
  local worker_info
  worker_info=$(_FILE="$SKYNET_WORKERS" _NAME="$name" python3 -c "
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

  info "Testing worker: $name (provider: $provider)"

  case "$provider" in
    claude)
      # Check claude CLI exists
      if ! command -v claude &>/dev/null; then
        fail "claude CLI not found"
        return 1
      fi
      ok "claude CLI available"
      # Check credential file from registry
      if [ -n "$token_file" ] && [ "$token_file" != "None" ]; then
        if [ -f "$SKYNET_CREDENTIALS/$token_file" ]; then
          ok "Credential file exists: $token_file"
        else
          warn "Credential file missing: $token_file"
        fi
      else
        warn "No credential configured"
      fi
      ;;
    gemini)
      # Check credentials file from registry
      if [ -n "$sa_file" ] && [ "$sa_file" != "None" ]; then
        local cred_path="$SKYNET_CREDENTIALS/$sa_file"
        if [ -f "$cred_path" ]; then
          # Validate it's valid JSON
          if _FILE="$cred_path" python3 -c "
import json, os
with open(os.environ['_FILE']) as f:
    json.load(f)
" 2>/dev/null; then
            ok "Credentials file valid JSON: $sa_file"
          else
            fail "Credentials file is not valid JSON: $sa_file"
            return 1
          fi
        else
          fail "Credentials file not found: $sa_file"
          return 1
        fi
      else
        fail "No credentials file configured"
        return 1
      fi
      ;;
    codex)
      # Check codex CLI exists
      if command -v codex &>/dev/null; then
        ok "codex CLI available"
      else
        fail "codex CLI not found"
        return 1
      fi
      ;;
    *)
      fail "Unknown provider: $provider"
      return 1
      ;;
  esac

  ok "Worker test passed: $name"
}

worker_status() {
  local name="$1"

  if ! worker_exists "$name"; then
    fail "Worker not found: $name"
    return 1
  fi

  _FILE="$SKYNET_WORKERS" _NAME="$name" _CRED_DIR="$SKYNET_CREDENTIALS" python3 -c "
import json, os
from datetime import datetime, timezone

with open(os.environ['_FILE']) as f:
    d = json.load(f)

cred_dir = os.environ['_CRED_DIR']
name = os.environ['_NAME']

for w in d['workers']:
    if w['name'] == name:
        print(f\"  Name:       {w['name']}\")
        print(f\"  Provider:   {w['provider']}\")
        print(f\"  Status:     {w['status']}\")
        print(f\"  Created:    {w.get('created_at', 'N/A')}\")

        # Credential info (never show actual values)
        creds = w.get('credentials', {})
        if w['provider'] == 'claude':
            tf = creds.get('token_file')
            if tf:
                exists = os.path.isfile(os.path.join(cred_dir, tf))
                print(f\"  Credential: {tf} ({'found' if exists else 'MISSING'})\")
            else:
                print(f\"  Credential: not configured\")
        elif w['provider'] == 'gemini':
            cf = creds.get('credentials_file') or creds.get('service_account')
            if cf:
                exists = os.path.isfile(os.path.join(cred_dir, cf))
                print(f\"  Credential: {cf} ({'found' if exists else 'MISSING'})\")
            else:
                print(f\"  Credential: not configured\")
        elif w['provider'] == 'codex':
            print(f\"  Credential: subscription login\")

        # Rate limit info
        rl = w.get('rate_limit')
        if rl and rl.get('until'):
            until = datetime.strptime(rl['until'], '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
            now = datetime.now(timezone.utc)
            if now < until:
                remaining = int((until - now).total_seconds())
                print(f\"  Rate limit: {remaining}s remaining (until {rl['until']})\")
            else:
                print(f\"  Rate limit: expired (pending auto-resume)\")
        break
"
}

worker_available_list() {
  # Returns names of active workers, one per line
  _FILE="$SKYNET_WORKERS" python3 -c "
import json, os
with open(os.environ['_FILE']) as f:
    d = json.load(f)
for w in d['workers']:
    if w['status'] == 'active':
        print(w['name'])
"
}
