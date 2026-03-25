#!/usr/bin/env bash
# skynet-auto-update: copy rules if plugin version is newer than installed version
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/log-common.sh"

PLUGIN_ROOT="$SCRIPT_DIR/.."
RULES_SRC="$PLUGIN_ROOT/rules"
PROJECT_ROOT=$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null || pwd)
RULES_DEST="$PROJECT_ROOT/.claude/rules"
VERSION_FILE="$PROJECT_ROOT/.claude/.skynet-version"
skynet_init_log
log() { skynet_log "auto-update" "$*"; }

log "start — cwd: $(pwd)"

PLUGIN_VERSION=$(jq -r '.version' "$PLUGIN_ROOT/.claude-plugin/plugin.json")
log "plugin version: $PLUGIN_VERSION"

STORED_VERSION=""
[ -f "$VERSION_FILE" ] && STORED_VERSION=$(cat "$VERSION_FILE")
log "stored version: ${STORED_VERSION:-none}"

EXPECTED_RULES=()
while IFS= read -r src; do
  EXPECTED_RULES+=("$(basename "$src")")
done < <(find "$RULES_SRC" -type f -name "*.md" ! -name "README.md" | sort)

SYNC_REASON=""
if [ "$STORED_VERSION" != "$PLUGIN_VERSION" ]; then
  SYNC_REASON="version change"
fi

if [ -z "$SYNC_REASON" ]; then
  while IFS= read -r src; do
    base="$(basename "$src")"
    dest="$RULES_DEST/$base"

    if [ ! -f "$dest" ]; then
      SYNC_REASON="missing rule: $base"
      break
    fi

    if grep -q '@hook:' "$src" && ! grep -q '@hook:' "$dest"; then
      SYNC_REASON="missing markers in: $base"
      break
    fi
  done < <(find "$RULES_SRC" -type f -name "*.md" ! -name "README.md" | sort)
fi

if [ -z "$SYNC_REASON" ]; then
  for dest in "$RULES_DEST"/*.md; do
    [ -f "$dest" ] || continue
    base="$(basename "$dest")"
    case " ${EXPECTED_RULES[*]} " in
      *" $base "*) ;;
      *)
        SYNC_REASON="stale rule: $base"
        break
        ;;
    esac
  done
fi

if [ -z "$SYNC_REASON" ]; then
  log "up to date — skip"
  exit 0
fi

log "sync required: $SYNC_REASON"

mkdir -p "$RULES_DEST"

if [ -d "$RULES_DEST" ] && [ "$(ls -A "$RULES_DEST" 2>/dev/null)" ]; then
  BACKUP="${RULES_DEST}.bak.$(date +%Y%m%d%H%M%S)"
  cp -r "$RULES_DEST" "$BACKUP"
  log "backup: $BACKUP"
fi

find "$RULES_DEST" -maxdepth 1 -type f -name "*.md" -delete
while IFS= read -r src; do
  cp "$src" "$RULES_DEST/$(basename "$src")"
done < <(find "$RULES_SRC" -type f -name "*.md" ! -name "README.md" | sort)

echo "$PLUGIN_VERSION" > "$VERSION_FILE"

rule_count=$(find "$RULES_DEST" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
[ "$rule_count" -gt 0 ] || { log "ERROR: no rules copied — check $RULES_SRC"; exit 1; }

log "copied $rule_count rules (flattened): $STORED_VERSION → $PLUGIN_VERSION"
echo "updated: skynet rules $STORED_VERSION → $PLUGIN_VERSION"
for f in "$RULES_DEST"/*.md; do
  [ -f "$f" ] && echo "  .claude/rules/$(basename "$f")" && log "  $(basename "$f")"
done
