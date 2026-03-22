#!/usr/bin/env bash
# skynet-auto-update: copy rules if plugin version is newer than installed version
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$SCRIPT_DIR/.."
RULES_SRC="$PLUGIN_ROOT/rules"
RULES_DEST=".claude/rules"
VERSION_FILE="$RULES_DEST/.skynet-version"

PLUGIN_VERSION=$(jq -r '.version' "$PLUGIN_ROOT/.claude-plugin/plugin.json")

STORED_VERSION=""
[ -f "$VERSION_FILE" ] && STORED_VERSION=$(cat "$VERSION_FILE")

if [ "$STORED_VERSION" = "$PLUGIN_VERSION" ]; then
  exit 0
fi

mkdir -p "$RULES_DEST"
cp -rf "$RULES_SRC/." "$RULES_DEST/"
echo "$PLUGIN_VERSION" > "$VERSION_FILE"

echo "updated: skynet rules $STORED_VERSION → $PLUGIN_VERSION"
for f in "$RULES_DEST"/*.md; do
  [ -f "$f" ] && echo "  .claude/rules/$(basename "$f")"
done
