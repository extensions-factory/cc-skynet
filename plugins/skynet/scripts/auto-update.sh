#!/usr/bin/env bash
# skynet-auto-update: copy rules if plugin version is newer than installed version
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$SCRIPT_DIR/.."
RULES_SRC="$PLUGIN_ROOT/rules"
RULES_DEST=".claude/rules"
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
cp -rf "$RULES_SRC/." "$RULES_DEST/"
echo "$PLUGIN_VERSION" > "$VERSION_FILE"
log "copied rules: $STORED_VERSION → $PLUGIN_VERSION"

echo "updated: skynet rules $STORED_VERSION → $PLUGIN_VERSION"
for f in "$RULES_DEST"/*.md; do
  [ -f "$f" ] && echo "  .claude/rules/$(basename "$f")" && log "  $(basename "$f")"
done
