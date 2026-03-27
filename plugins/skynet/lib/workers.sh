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
