#!/usr/bin/env bash
set -euo pipefail

# ── Resolve plugin dir from script location ─────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"

source "$PLUGIN_DIR/lib/common.sh"

LINK_DIR="$HOME/.local/bin"

# All CLIs to symlink
CLI_NAMES=("skynet" "genisys" "legion")

# ── Symlink a single CLI ────────────────────────────────
ensure_symlink() {
  local name="$1"
  local source_bin="$PLUGIN_DIR/bin/$name"
  local link_path="$LINK_DIR/$name"

  # Skip if binary doesn't exist yet (future CLIs)
  if [ ! -f "$source_bin" ]; then
    return 0
  fi

  if [ -L "$link_path" ]; then
    local current_target
    current_target="$(readlink "$link_path")"
    if [ "$current_target" = "$source_bin" ]; then
      ok "$name — symlink OK"
    else
      ln -sf "$source_bin" "$link_path"
      ok "$name — symlink updated"
    fi
  elif [ -e "$link_path" ]; then
    warn "$name — $link_path exists but is not a symlink (skipped)"
  else
    ln -s "$source_bin" "$link_path"
    ok "$name — symlink created"
  fi
}

# ── Setup ───────────────────────────────────────────────
printf "\n${BOLD}[SKYNET] Setup${RESET}\n\n"

# 1. Ensure ~/.local/bin exists
if [ ! -d "$LINK_DIR" ]; then
  info "Creating $LINK_DIR"
  mkdir -p "$LINK_DIR"
fi

# 2. Create/update symlinks for all CLIs
for cli in "${CLI_NAMES[@]}"; do
  ensure_symlink "$cli"
done

# 3. Check if ~/.local/bin is in PATH
if echo "$PATH" | tr ':' '\n' | grep -qx "$LINK_DIR"; then
  ok "\$PATH includes $LINK_DIR"
else
  warn "$LINK_DIR is not in your \$PATH"
  printf "\n  Add to ~/.zshrc or ~/.bashrc:\n\n"
  printf "    ${CYAN}export PATH=\"\$HOME/.local/bin:\$PATH\"${RESET}\n\n"
fi

printf "\n${GREEN}${BOLD}Done!${RESET}\n"
