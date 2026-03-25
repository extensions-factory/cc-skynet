#!/usr/bin/env bash
# Symlink agents from everything-claude-code to .claude/agents/ based on skynet.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/log-common.sh"

ECC_DIR="$HOME/.claude/skills-cache/everything-claude-code"
PROJECT_CONFIG=".claude/skynet.json"
AGENTS_DIR=".claude/agents"
skynet_init_log
log() { skynet_log "agents-link" "$*"; }

log "start — cwd: $(pwd)"

[ -f "$PROJECT_CONFIG" ] || { log "no $PROJECT_CONFIG — skip"; exit 0; }
[ -d "$ECC_DIR/agents" ] || { log "ecc agents not cached — skip (run external-libs-fetch first)"; exit 0; }

# Read requested agents list from skynet.json
agents=$(jq -r '.agents[]?' "$PROJECT_CONFIG" 2>/dev/null)
if [ -z "$agents" ]; then
  log "no agents configured in $PROJECT_CONFIG — skip"
  exit 0
fi

log "requested agents: $(echo "$agents" | tr '\n' ' ')"
mkdir -p "$AGENTS_DIR"

linked=0
skipped=0
not_found=0

while IFS= read -r agent_name; do
  [ -n "$agent_name" ] || continue
  src="$ECC_DIR/agents/${agent_name}.md"
  dst="$AGENTS_DIR/${agent_name}.md"

  if [ ! -f "$src" ]; then
    log "  $agent_name — not found in ecc, skip"
    not_found=$((not_found + 1))
    continue
  fi

  # Remove broken symlinks
  if [ -L "$dst" ] && [ ! -e "$dst" ]; then
    rm "$dst"
    log "  $agent_name — removed broken symlink"
  fi

  if [ -e "$dst" ]; then
    log "  $agent_name — already linked, skip"
    skipped=$((skipped + 1))
  else
    ln -sf "$src" "$dst"
    log "  $agent_name — linked"
    echo "linked agent: $agent_name"
    linked=$((linked + 1))
  fi
done <<< "$agents"

log "done — linked: $linked, skipped: $skipped, not_found: $not_found"
[ "$linked" -gt 0 ] && echo "total: $linked agents linked"
[ "$not_found" -gt 0 ] && echo "WARNING: $not_found agents not found in everything-claude-code" >&2 || true
