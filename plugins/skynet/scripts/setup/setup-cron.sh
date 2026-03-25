#!/usr/bin/env bash
# Register daily external-libs-fetch cron job if not already present
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/log-common.sh"
skynet_init_log
log() { skynet_log "setup-cron" "$*"; }

MARKER="skynet-external-libs-fetch"
LEGACY_MARKERS=("skynet-skills-fetch" "external-libs-fetch")
CRON_CMD="0 0 * * * bash -lc 'LOG_DIR=\"\$HOME/.claude/logs\"; mkdir -p \"\$LOG_DIR\"; LOG_FILE=\"\$LOG_DIR/skynet-\$(date +\\%Y-\\%m-\\%d).log\"; latest=\$(ls -1 \"\$HOME/.claude/plugins/cache/cc-skynet/skynet\" 2>/dev/null | sort -V | tail -1); f=\"\$HOME/.claude/plugins/cache/cc-skynet/skynet/\$latest/scripts/setup/external-libs-fetch.sh\"; [ -f \"\$f\" ] || f=\"\$HOME/.claude/plugins/cache/cc-skynet/skynet/\$latest/scripts/setup/skills-fetch.sh\"; [ -n \"\$latest\" ] && [ -f \"\$f\" ] && bash \"\$f\" >> \"\$LOG_FILE\" 2>&1' # $MARKER"
CURRENT_CRONTAB="$(crontab -l 2>/dev/null || true)"

HAS_SKYNET_ENTRY=0
for marker in "$MARKER" "${LEGACY_MARKERS[@]}"; do
  if printf '%s\n' "$CURRENT_CRONTAB" | grep -qF "$marker"; then
    HAS_SKYNET_ENTRY=1
    break
  fi
done

if [ "$HAS_SKYNET_ENTRY" -eq 1 ]; then
  UPDATED_CRONTAB="$(printf '%s\n' "$CURRENT_CRONTAB" | awk \
    -v replacement="$CRON_CMD" \
    -v marker1="$MARKER" \
    -v marker2="${LEGACY_MARKERS[0]}" \
    -v marker3="${LEGACY_MARKERS[1]}" '
    index($0, marker1) || index($0, marker2) || index($0, marker3) {
      if (!replaced) {
        print replacement
        replaced = 1
      }
      next
    }
    { print }
    END {
      if (!replaced) {
        print replacement
      }
    }
  ')"

  if [ "$UPDATED_CRONTAB" = "$CURRENT_CRONTAB" ]; then
    log "cron already registered — no changes"
    exit 0
  fi

  printf '%s\n' "$UPDATED_CRONTAB" | crontab -
  log "cron updated: daily at 00:00"
  echo "skynet: updated daily external-libs-fetch cron"
  exit 0
fi

{ printf '%s\n' "$CURRENT_CRONTAB"; echo "$CRON_CMD"; } | crontab -

log "cron registered: daily at 00:00"
echo "skynet: registered daily external-libs-fetch cron"
