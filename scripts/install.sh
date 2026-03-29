#!/bin/sh
# ──────────────────────────────────────────────────────────────
# Skynet Claude Code Plugin — Bootstrap Installer
# Repository: extensions-factory/cc-skynet
# Version:    0.3.0
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/extensions-factory/cc-skynet/main/scripts/install.sh | sh
#
# This script:
#   1. Checks for the Claude CLI
#   2. Registers the cc-skynet marketplace
#   3. Installs the skynet plugin
#   4. Verifies the installation
#   5. Prints next steps
#
# Respects NO_COLOR (https://no-color.org/).
# Passes shellcheck — no bashisms.
# ──────────────────────────────────────────────────────────────

set -eu
TMP_ERR=$(mktemp)
trap 'rm -f "${TMP_ERR}"' EXIT INT TERM

# ── Version ───────────────────────────────────────────────────

VERSION="0.3.0"
REPO="extensions-factory/cc-skynet"
MARKETPLACE_URL="https://github.com/${REPO}"

# ── Color helpers ─────────────────────────────────────────────
# Disable color when NO_COLOR is set or stdout is not a terminal.

if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  BOLD=""
  RESET=""
else
  RED=$(tput setaf 1 2>/dev/null || printf '')
  GREEN=$(tput setaf 2 2>/dev/null || printf '')
  YELLOW=$(tput setaf 3 2>/dev/null || printf '')
  BLUE=$(tput setaf 4 2>/dev/null || printf '')
  BOLD=$(tput bold 2>/dev/null || printf '')
  RESET=$(tput sgr0 2>/dev/null || printf '')
fi

# ── Logging helpers ───────────────────────────────────────────

die() {
  printf '%s%s%s: %s\n' "${RED}" "ERROR" "${RESET}" "$1" >&2
  exit 1
}

warn() {
  printf '%s%s%s:  %s\n' "${YELLOW}" "WARN" "${RESET}" "$1" >&2
}

info() {
  printf '%s%s%s:  %s\n' "${BLUE}" "INFO" "${RESET}" "$1"
}

success() {
  printf '%s%s%s:    %s\n' "${GREEN}" "OK" "${RESET}" "$1"
}

# ── Banner ────────────────────────────────────────────────────

banner() {
  printf "\n"
  printf '%s╔══════════════════════════════════════════╗%s\n' "${BOLD}" "${RESET}"
  printf '%s║   Skynet — Claude Code Plugin Installer  ║%s\n' "${BOLD}" "${RESET}"
  printf '%s║   v%s                                 ║%s\n' "${BOLD}" "${VERSION}" "${RESET}"
  printf '%s╚══════════════════════════════════════════╝%s\n' "${BOLD}" "${RESET}"
  printf "\n"
}

# ── Step 1: Check for Claude CLI ─────────────────────────────

check_claude_cli() {
  info "Checking for Claude CLI..."

  if ! command -v claude >/dev/null 2>&1; then
    die "Claude CLI not found in PATH. Install it first: https://docs.anthropic.com/en/docs/claude-code/overview"
  fi

  success "Claude CLI found: $(command -v claude)"
}

# ── Step 2: Register the marketplace ─────────────────────────

add_marketplace() {
  info "Adding cc-skynet marketplace..."

  # Detect if the marketplace is already registered.
  if claude plugins marketplace list 2>/dev/null | grep -q "${REPO}"; then
    warn "Marketplace ${REPO} is already registered — skipping."
    return 0
  fi

  if ! claude plugins marketplace add "${REPO}" 2>"${TMP_ERR}"; then
    err_msg=$(cat "${TMP_ERR}" 2>/dev/null || echo "unknown error")

    # Detect specific failures.
    case "${err_msg}" in
      *"network"*|*"connect"*|*"resolve"*|*"timeout"*)
        die "Network failure while adding marketplace. Check your internet connection and try again."
        ;;
      *"permission"*|*"denied"*|*"EACCES"*)
        die "Permission denied. Try running with appropriate permissions or check directory ownership."
        ;;
      *)
        die "Failed to add marketplace: ${err_msg}"
        ;;
    esac
  fi
  success "Marketplace registered: ${REPO}"
}

# ── Step 3: Install the plugin ────────────────────────────────

install_plugin() {
  info "Installing skynet plugin..."

  # Detect if the plugin is already installed.
  if claude plugins list 2>/dev/null | grep -q "skynet@cc-skynet"; then
    warn "Plugin skynet@cc-skynet is already installed."
    warn "Run 'claude plugin update skynet@cc-skynet' to update instead."
    return 0
  fi

  if ! claude plugins install "skynet@cc-skynet" 2>"${TMP_ERR}"; then
    err_msg=$(cat "${TMP_ERR}" 2>/dev/null || echo "unknown error")

    # Detect specific failures.
    case "${err_msg}" in
      *"network"*|*"connect"*|*"resolve"*|*"timeout"*)
        die "Network failure during plugin install. Check your internet connection and try again."
        ;;
      *"permission"*|*"denied"*|*"EACCES"*)
        die "Permission denied during plugin install. Check directory permissions."
        ;;
      *"not found"*|*"404"*|*"invalid"*)
        die "Plugin not found or registry returned an invalid state. Verify the marketplace was added correctly."
        ;;
      *)
        die "Failed to install plugin: ${err_msg}"
        ;;
    esac
  fi
  success "Plugin installed: skynet@cc-skynet"
}

# ── Step 4: Verify installation ───────────────────────────────

verify_install() {
  info "Verifying installation..."

  if ! claude plugins list 2>/dev/null | grep -qF "skynet@cc-skynet"; then
    die "Verification failed: skynet plugin not found after install. This may indicate an invalid state — try uninstalling and reinstalling."
  fi

  success "Verification passed — skynet plugin is installed."
}

# ── Step 5: Print success and next steps ──────────────────────

print_success() {
  printf "\n"
  printf '%s%s════════════════════════════════════════════%s\n' "${GREEN}" "${BOLD}" "${RESET}"
  printf '%s%s  Skynet v%s installed successfully!%s\n' "${GREEN}" "${BOLD}" "${VERSION}" "${RESET}"
  printf '%s%s════════════════════════════════════════════%s\n' "${GREEN}" "${BOLD}" "${RESET}"
  printf "\n"
  printf "  Next steps:\n"
  printf "\n"
  printf "  1. Start a new Claude Code session:\n"
  printf '     %s%s%s\n' "${BOLD}" 'claude --dangerously-skip-permissions "start session"' "${RESET}"
  printf "\n"
  printf "  2. Look for the boot message:\n"
  printf '     %s%s%s\n' "${BOLD}" '[SKYNET] Online' "${RESET}"
  printf "\n"
  printf "  3. To update later:\n"
  printf '     %s%s%s\n' "${BOLD}" 'claude plugin update skynet@cc-skynet' "${RESET}"
  printf "\n"
  printf "  Docs:   %s\n" "${MARKETPLACE_URL}"
  printf "  Issues: %s/issues\n" "${MARKETPLACE_URL}"
  printf "\n"
}

# ── Main ──────────────────────────────────────────────────────

main() {
  banner
  check_claude_cli
  add_marketplace
  install_plugin
  verify_install
  print_success
}

main
