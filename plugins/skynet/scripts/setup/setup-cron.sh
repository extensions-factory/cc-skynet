#!/usr/bin/env bash
# Register daily skills-fetch cron job if not already present
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/log-common.sh"
skynet_init_log
log() { skynet_log "setup-cron" "$*"; }

MARKER="skynet-skills-fetch"
CRON_CMD="0 0 * * * bash -lc 'LOG_DIR=\"\$HOME/.claude/logs\"; mkdir -p \"\$LOG_DIR\"; LOG_FILE=\"\$LOG_DIR/skynet-\$(date +\\%Y-\\%m-\\%d).log\"; f=\$(ls \$HOME/.claude/plugins/cache/cc-skynet/skynet/*/scripts/setup/skills-fetch.sh 2>/dev/null | sort | tail -1); [ -n \"\$f\" ] && bash \"\$f\" >> \"\$LOG_FILE\" 2>&1' # $MARKER"
CURRENT_CRONTAB="$(crontab -l 2>/dev/null || true)"

if printf '%s\n' "$CURRENT_CRONTAB" | grep -qF "$MARKER"; then
  UPDATED_CRONTAB="$(printf '%s\n' "$CURRENT_CRONTAB" | awk -v marker="$MARKER" -v replacement="$CRON_CMD" '
    index($0, marker) { print replacement; next }
    { print }
  ')"

  if [ "$UPDATED_CRONTAB" = "$CURRENT_CRONTAB" ]; then
    log "cron already registered — no changes"
    exit 0
  fi

  printf '%s\n' "$UPDATED_CRONTAB" | crontab -
  log "cron updated: daily at 00:00"
  echo "skynet: updated daily skills-fetch cron"
  exit 0
fi

{ printf '%s\n' "$CURRENT_CRONTAB"; echo "$CRON_CMD"; } | crontab -

log "cron registered: daily at 00:00"
echo "skynet: registered daily skills-fetch cron"
