#!/usr/bin/env bash
# Register daily skills-fetch cron job if not already present
set -euo pipefail

LOG="$HOME/.claude/logs/skynet-skills.log"

mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date '+%H:%M:%S')] [setup-cron] $*" >> "$LOG"; }

MARKER="skynet-skills-fetch"

if crontab -l 2>/dev/null | grep -qF "$MARKER"; then
  log "cron already registered — skip"
  exit 0
fi

CRON_CMD="0 0 * * * bash -c 'f=\$(ls \$HOME/.claude/plugins/cache/cc-skynet/skynet/*/scripts/skills-fetch.sh 2>/dev/null | sort | tail -1) && [ -n \"\$f\" ] && bash \"\$f\"' >> $LOG 2>&1 # $MARKER"

(crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -

log "cron registered: daily at 00:00"
echo "skynet: registered daily skills-fetch cron"
