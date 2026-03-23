#!/usr/bin/env bash
# skynet-auto-update: copy rules if plugin version is newer than installed version
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$SCRIPT_DIR/.."
RULES_SRC="$PLUGIN_ROOT/rules"
PROJECT_ROOT=$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null || pwd)
RULES_DEST="$PROJECT_ROOT/.claude/rules"
VERSION_FILE="$RULES_DEST/.skynet-version"
LOG="$HOME/.claude/logs/skynet-skills.log"

mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date '+%H:%M:%S')] [auto-update] $*" >> "$LOG"; }

log "start — cwd: $(pwd)"

PLUGIN_VERSION=$(jq -r '.version' "$PLUGIN_ROOT/.claude-plugin/plugin.json")
log "plugin version: $PLUGIN_VERSION"

STORED_VERSION=""
[ -f "$VERSION_FILE" ] && STORED_VERSION=$(cat "$VERSION_FILE")
log "stored version: ${STORED_VERSION:-none}"

if [ "$STORED_VERSION" = "$PLUGIN_VERSION" ]; then
  log "up to date — skip"
  exit 0
fi

mkdir -p "$RULES_DEST"

if [ -d "$RULES_DEST" ] && [ "$(ls -A "$RULES_DEST" 2>/dev/null)" ]; then
  BACKUP="${RULES_DEST}.bak.$(date +%Y%m%d%H%M%S)"
  cp -r "$RULES_DEST" "$BACKUP"
  log "backup: $BACKUP"
fi

cp -rf "$RULES_SRC/." "$RULES_DEST/"
echo "$PLUGIN_VERSION" > "$VERSION_FILE"

rule_count=$(find "$RULES_DEST" -name "*.md" -not -name ".skynet-version" 2>/dev/null | wc -l | tr -d ' ')
[ "$rule_count" -gt 0 ] || { log "ERROR: no rules copied — check $RULES_SRC"; exit 1; }

log "copied $rule_count rules: $STORED_VERSION → $PLUGIN_VERSION"
echo "updated: skynet rules $STORED_VERSION → $PLUGIN_VERSION"
for f in "$RULES_DEST"/*.md; do
  [ -f "$f" ] && echo "  .claude/rules/$(basename "$f")" && log "  $(basename "$f")"
done
