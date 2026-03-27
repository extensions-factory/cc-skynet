#!/usr/bin/env bash
# ── common.sh — shared utilities for skynet scripts ────

# ── Paths ───────────────────────────────────────────────
# Resolve PLUGIN_DIR from any script that sources this file.
# Assumes lib/ is one level under the plugin root.
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="${PLUGIN_DIR:-$(dirname "$COMMON_DIR")}"

# ── Colors ──────────────────────────────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

# ── Log helpers ─────────────────────────────────────────
info()  { printf "${CYAN}▸${RESET} %s\n" "$*"; }
ok()    { printf "${GREEN}✔${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}⚠${RESET} %s\n" "$*"; }
fail()  { printf "${RED}✘${RESET} %s\n" "$*"; }

# ── Platform detection ──────────────────────────────────
detect_platform() {
  case "$(uname -s)" in
    Darwin*) echo "darwin" ;;
    Linux*)  echo "linux" ;;
    *)       echo "unknown" ;;
  esac
}

# ── JSON helpers (python3) ──────────────────────────────
# Read a key from a JSON file: json_read <file> <dot.separated.key>
# Example: json_read plugin.json "version"
json_read() {
  local file="$1" key="$2"
  _FILE="$file" _KEY="$key" python3 -c "
import json, os, functools, operator
with open(os.environ['_FILE']) as f:
    d = json.load(f)
keys = os.environ['_KEY'].split('.')
print(functools.reduce(operator.getitem, keys, d))
"
}

# ── Version ─────────────────────────────────────────────
plugin_version() {
  json_read "$PLUGIN_DIR/.claude-plugin/plugin.json" "version"
}
