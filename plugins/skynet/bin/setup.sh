#!/usr/bin/env bash
set -euo pipefail

# ── Resolve plugin dir from script location ─────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"

source "$PLUGIN_DIR/lib/common.sh"

SKYNET_BIN="$PLUGIN_DIR/bin/skynet"
LINK_DIR="$HOME/.local/bin"
LINK_PATH="$LINK_DIR/skynet"

# ── Setup ───────────────────────────────────────────────
printf "\n${BOLD}[SKYNET] Setup${RESET}\n\n"

# 1. Ensure ~/.local/bin exists
if [ ! -d "$LINK_DIR" ]; then
  info "Creating $LINK_DIR"
  mkdir -p "$LINK_DIR"
fi

# 2. Create/update symlink
if [ -L "$LINK_PATH" ]; then
  current_target="$(readlink "$LINK_PATH")"
  if [ "$current_target" = "$SKYNET_BIN" ]; then
    ok "Symlink already correct: $LINK_PATH → $SKYNET_BIN"
  else
    info "Updating symlink (was → $current_target)"
    ln -sf "$SKYNET_BIN" "$LINK_PATH"
    ok "Symlink updated: $LINK_PATH → $SKYNET_BIN"
  fi
elif [ -e "$LINK_PATH" ]; then
  fail "$LINK_PATH exists but is not a symlink — skipping (remove it manually)"
  exit 1
else
  ln -s "$SKYNET_BIN" "$LINK_PATH"
  ok "Symlink created: $LINK_PATH → $SKYNET_BIN"
fi

# 3. Check if ~/.local/bin is in PATH
if echo "$PATH" | tr ':' '\n' | grep -qx "$LINK_DIR"; then
  ok "\$PATH already includes $LINK_DIR"
else
  warn "$LINK_DIR is not in your \$PATH"
  printf "\n  Add this to your shell profile (~/.zshrc or ~/.bashrc):\n\n"
  printf "    ${CYAN}export PATH=\"\$HOME/.local/bin:\$PATH\"${RESET}\n\n"
  printf "  Then reload: ${CYAN}source ~/.zshrc${RESET}\n"
fi

printf "\n${GREEN}${BOLD}Done!${RESET} Run ${CYAN}skynet doctor${RESET} to verify.\n"
