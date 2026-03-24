#!/usr/bin/env bash
# Delegate a task to Gemini CLI via tmux.
# Round-robin account selection with automatic failover on rate limit.
# Signaling: tmux wait-for (instant, no polling) + atomic file write.
#
# Usage: spawn-gemini-worker.sh <task-file>
#
# Env overrides:
#   SKYNET_ACCOUNTS_DIR  — path to credentials dir (default: $PWD/accounts)
#   SKYNET_TASK_TIMEOUT  — max seconds per attempt, 0 = no timeout (default: 0)
#
# Exit codes: 0=SUCCESS, 1=FAILED, 2=TIMEOUT
set -euo pipefail

TASK_FILE="$(realpath "${1:?Usage: spawn-gemini-worker.sh <task-file>}")"
TIMEOUT="${SKYNET_TASK_TIMEOUT:-0}"
PROJECT_DIR="$(pwd)"
ACCOUNTS_DIR="${SKYNET_ACCOUNTS_DIR:-$PROJECT_DIR/accounts}"

TASK_ID=$(basename "$TASK_FILE" .md)
PIPE_DIR="$PROJECT_DIR/tasks/.pipe"
OUTPUT_DIR="$PROJECT_DIR/tasks/.output"
OUTPUT_FILE="$OUTPUT_DIR/${TASK_ID}.md"
ERR_FILE="$OUTPUT_DIR/${TASK_ID}.err"
EXIT_FILE="$PIPE_DIR/${TASK_ID}.exit"
STATUS_FILE="$PIPE_DIR/${TASK_ID}.status"
LOG="$HOME/.claude/logs/skynet-skills.log"

mkdir -p "$PIPE_DIR" "$OUTPUT_DIR" "$(dirname "$LOG")"
rm -f "$EXIT_FILE" "$STATUS_FILE"

log() { echo "[$(date '+%H:%M:%S')] [gemini-worker] $*" >> "$LOG"; }
log "start — task: $TASK_ID, project: $PROJECT_DIR"

# ── Discover accounts ──────────────────────────────────────────────────────────
ACCOUNTS=()
while IFS= read -r f; do
  ACCOUNTS+=("$f")
done < <(ls "$ACCOUNTS_DIR"/gemini-oauth-*.json 2>/dev/null | sort)

TOTAL=${#ACCOUNTS[@]}
if [ "$TOTAL" -eq 0 ]; then
  log "ERROR: no accounts in $ACCOUNTS_DIR"
  echo "ERROR: no credential files found in $ACCOUNTS_DIR" >&2
  exit 1
fi
log "accounts: $TOTAL found"

# ── Round-robin state ──────────────────────────────────────────────────────────
RR_STATE="$HOME/.claude/skynet-rr-index"
RR_INDEX=0
[ -f "$RR_STATE" ] && RR_INDEX=$(cat "$RR_STATE" 2>/dev/null) || true
[ "$RR_INDEX" -ge "$TOTAL" ] 2>/dev/null && RR_INDEX=0 || true

# ── Failover loop ─────────────────────────────────────────────────────────────
SKIP_LIST=""
FINAL_STATUS="FAILED:unknown"
ATTEMPT=0
TOTAL_ELAPSED=0

for attempt_i in $(seq 0 $((TOTAL - 1))); do
  # Select next account — round-robin, skip rate-limited ones
  CREDS=""
  for scan in $(seq 0 $((TOTAL - 1))); do
    POS=$(( (RR_INDEX + attempt_i + scan) % TOTAL ))
    CANDIDATE="${ACCOUNTS[$POS]}"
    if ! echo "$SKIP_LIST" | grep -qF "$CANDIDATE"; then
      CREDS="$CANDIDATE"
      echo $(( (POS + 1) % TOTAL )) > "$RR_STATE"
      break
    fi
  done

  if [ -z "$CREDS" ]; then
    log "all accounts exhausted"
    break
  fi

  ACCOUNT_NAME=$(basename "$CREDS" .json | sed 's/gemini-oauth-//')
  ATTEMPT=$((ATTEMPT + 1))
  SESSION="skynet-${TASK_ID}-${ATTEMPT}"
  SIGNAL_CHANNEL="skynet-done-${TASK_ID}-${ATTEMPT}"

  log "attempt $ATTEMPT/$TOTAL — account: $ACCOUNT_NAME"
  echo "[skynet] attempt $ATTEMPT/$TOTAL — account: $ACCOUNT_NAME"

  # Clean up previous attempt artifacts
  rm -f "$EXIT_FILE" "$OUTPUT_FILE" "$ERR_FILE"

  # Write wrapper script
  WRAPPER="$PIPE_DIR/${TASK_ID}-wrapper.sh"
  cat > "$WRAPPER" <<WRAPPER_EOF
#!/usr/bin/env bash
set -e
cd $(printf '%q' "$PROJECT_DIR")
export GOOGLE_APPLICATION_CREDENTIALS=$(printf '%q' "$CREDS")
export GOOGLE_GENAI_USE_GCA=true
CONTENT=\$(cat $(printf '%q' "$TASK_FILE"))
gemini -p "\$CONTENT" > $(printf '%q' "$OUTPUT_FILE") 2> $(printf '%q' "$ERR_FILE")
EC=\$?
# Atomic write: tmp → mv (no partial reads)
echo "\$EC" > $(printf '%q' "${EXIT_FILE}.tmp") && mv $(printf '%q' "${EXIT_FILE}.tmp") $(printf '%q' "$EXIT_FILE")
# Signal: instant notification via tmux wait-for
tmux wait-for -S $(printf '%q' "$SIGNAL_CHANNEL") 2>/dev/null || true
WRAPPER_EOF

  # Start tmux session
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  tmux new-session -d -s "$SESSION" -x 220 -y 50
  tmux send-keys -t "$SESSION" "bash $(printf '%q' "$WRAPPER")" Enter

  log "gemini started in $SESSION (account: $ACCOUNT_NAME, signal: $SIGNAL_CHANNEL)"
  echo "[skynet] worker started: $SESSION"
  echo "[skynet] output: $OUTPUT_FILE"

  # ── Wait for signal ────────────────────────────────────────────────────────
  START_TIME=$(date +%s)

  if [ "$TIMEOUT" -gt 0 ]; then
    # Wait with timeout: background wait-for + timeout watchdog
    tmux wait-for "$SIGNAL_CHANNEL" &
    WAIT_PID=$!

    while kill -0 "$WAIT_PID" 2>/dev/null; do
      NOW=$(date +%s)
      elapsed=$(( NOW - START_TIME ))
      if [ "$elapsed" -ge "$TIMEOUT" ]; then
        kill "$WAIT_PID" 2>/dev/null || true
        log "TIMEOUT after ${TIMEOUT}s on account $ACCOUNT_NAME"
        tmux kill-session -t "$SESSION" 2>/dev/null || true
        FINAL_STATUS="FAILED:timeout_${TIMEOUT}s"
        echo "$FINAL_STATUS" > "$STATUS_FILE"
        echo "[skynet] ERROR: timeout after ${TIMEOUT}s" >&2
        rm -f "$WRAPPER"
        exit 2
      fi
      sleep 2
    done
    wait "$WAIT_PID" 2>/dev/null || true
  else
    # No timeout — pure blocking wait
    tmux wait-for "$SIGNAL_CHANNEL"
  fi

  END_TIME=$(date +%s)
  elapsed=$(( END_TIME - START_TIME ))
  TOTAL_ELAPSED=$((TOTAL_ELAPSED + elapsed))

  # ── Read result ────────────────────────────────────────────────────────────
  tmux kill-session -t "$SESSION" 2>/dev/null || true

  if [ ! -f "$EXIT_FILE" ]; then
    log "no exit file — session may have crashed"
    FINAL_STATUS="FAILED:no_exit_file"
    break
  fi

  EXIT_CODE=$(cat "$EXIT_FILE")
  log "exit code: $EXIT_CODE (${elapsed}s elapsed, account: $ACCOUNT_NAME)"

  if [ "$EXIT_CODE" = "0" ]; then
    FINAL_STATUS="SUCCESS"
    log "SUCCESS — account: $ACCOUNT_NAME"
    break
  fi

  # Check for rate limit in stderr → failover to next account
  if grep -qiE "429|RESOURCE_EXHAUSTED|rateLimitExceeded|capacity" "$ERR_FILE" 2>/dev/null; then
    log "rate limited on $ACCOUNT_NAME — failover to next"
    echo "[skynet] rate limited on $ACCOUNT_NAME — trying next..."
    SKIP_LIST="$SKIP_LIST|$CREDS"
    continue
  fi

  # Non-rate-limit error — stop retrying
  FINAL_STATUS="FAILED:exit_${EXIT_CODE}"
  log "FAILED on $ACCOUNT_NAME — exit $EXIT_CODE (not rate limit)"
  break
done

# All accounts exhausted
if [ "$FINAL_STATUS" = "FAILED:unknown" ]; then
  FINAL_STATUS="FAILED:all_accounts_rate_limited"
  log "all $TOTAL accounts rate limited — giving up"
fi

echo "$FINAL_STATUS" > "$STATUS_FILE"
rm -f "$WRAPPER" "$EXIT_FILE"

# ── Report ─────────────────────────────────────────────────────────────────────
echo "[skynet] status: $FINAL_STATUS"
echo "[skynet] output: $OUTPUT_FILE"
echo "[skynet] attempts: $ATTEMPT/$TOTAL"
echo "[skynet] elapsed: ${TOTAL_ELAPSED}s"

if [ "$FINAL_STATUS" = "SUCCESS" ]; then
  echo "--- OUTPUT ---"
  cat "$OUTPUT_FILE"
  exit 0
else
  echo "--- ERROR ---"
  cat "$OUTPUT_FILE" 2>/dev/null || echo "(no output)"
  exit 1
fi
