#!/usr/bin/env bash
# Delegate a task to Claude Code CLI via tmux.
# Round-robin account selection with automatic failover on rate limit.
# Supports Q&A: Claude can ask clarifying questions (max 2 follow-up rounds).
# Signaling: tmux wait-for (instant, no polling) + atomic file write.
#
# Usage:
#   spawn-claude-worker.sh <task-file>            — initial run
#   spawn-claude-worker.sh --answer <task-file>   — send answer (from stdin)
#
# Env overrides:
#   SKYNET_ACCOUNTS_DIR        — credentials dir (default: $PWD/accounts)
#   SKYNET_TASK_TIMEOUT        — max seconds, 0 = no timeout (default: 0)
#   SKYNET_CLAUDE_MODEL        — model name (default: sonnet)
#   SKYNET_CLAUDE_MAX_ROUNDS   — max rounds incl. initial (default: 3)
#
# Exit codes: 0=SUCCESS, 1=FAILED, 2=TIMEOUT, 3=NEEDS_CLARIFICATION
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/log-common.sh"
skynet_init_log

# ── Mode detection ─────────────────────────────────────────────────────────────
MODE="run"
if [ "${1:-}" = "--answer" ]; then
  MODE="answer"
  shift
fi

TASK_FILE="$(realpath "${1:?Usage: spawn-claude-worker.sh [--answer] <task-file>}")"
TASK_ID=$(basename "$TASK_FILE" .md)
TIMEOUT="${SKYNET_TASK_TIMEOUT:-0}"
PROJECT_DIR="$(pwd)"
ACCOUNTS_DIR="${SKYNET_ACCOUNTS_DIR:-$PROJECT_DIR/accounts}"
CLAUDE_MODEL="${SKYNET_CLAUDE_MODEL:-sonnet}"
MAX_ROUNDS="${SKYNET_CLAUDE_MAX_ROUNDS:-3}"

PIPE_DIR="$PROJECT_DIR/tasks/.pipe"
OUTPUT_DIR="$PROJECT_DIR/tasks/.output"
OUTPUT_FILE="$OUTPUT_DIR/${TASK_ID}.md"
ERR_FILE="$OUTPUT_DIR/${TASK_ID}.err"
EXIT_FILE="$PIPE_DIR/${TASK_ID}.exit"
STATUS_FILE="$PIPE_DIR/${TASK_ID}.status"
QUESTION_FILE="$PIPE_DIR/${TASK_ID}.question"
ANSWER_FILE="$PIPE_DIR/${TASK_ID}.answer"
STATE_FILE="$PIPE_DIR/${TASK_ID}.state"

mkdir -p "$PIPE_DIR" "$OUTPUT_DIR" "$LOG_DIR"

log() { skynet_log "claude-worker" "$*"; }

# ── Shared: wait for signal with optional timeout ──────────────────────────────
wait_for_signal() {
  local channel="$1"
  local start=$(date +%s)

  if [ "$TIMEOUT" -gt 0 ]; then
    tmux wait-for "$channel" &
    local wait_pid=$!
    while kill -0 "$wait_pid" 2>/dev/null; do
      local now=$(date +%s)
      local elapsed=$(( now - start ))
      if [ "$elapsed" -ge "$TIMEOUT" ]; then
        kill "$wait_pid" 2>/dev/null || true
        return 2
      fi
      sleep 2
    done
    wait "$wait_pid" 2>/dev/null || true
  else
    tmux wait-for "$channel"
  fi
  return 0
}

# ══════════════════════════════════════════════════════════════════════════════════
# ANSWER MODE — send answer to waiting Q&A session
# ══════════════════════════════════════════════════════════════════════════════════
if [ "$MODE" = "answer" ]; then
  log "answer mode — task: $TASK_ID"

  if [ -t 0 ]; then
    echo "ERROR: answer must be provided via stdin" >&2
    exit 1
  fi
  ANSWER_TEXT=$(cat)

  if [ ! -f "$STATE_FILE" ]; then
    echo "ERROR: no active Q&A session for $TASK_ID" >&2
    exit 1
  fi

  SIGNAL_CHANNEL=$(grep '^SIGNAL_CHANNEL=' "$STATE_FILE" | cut -d= -f2-)
  ANSWER_CHANNEL=$(grep '^ANSWER_CHANNEL=' "$STATE_FILE" | cut -d= -f2-)
  SESSION_NAME=$(grep '^SESSION_NAME=' "$STATE_FILE" | cut -d= -f2-)
  ACCOUNT_NAME=$(grep '^ACCOUNT_NAME=' "$STATE_FILE" | cut -d= -f2-)

  # Verify tmux session still alive
  if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "ERROR: tmux session $SESSION_NAME no longer exists" >&2
    rm -f "$STATE_FILE"
    exit 1
  fi

  # Write answer atomically
  echo "$ANSWER_TEXT" > "${ANSWER_FILE}.tmp" && mv "${ANSWER_FILE}.tmp" "$ANSWER_FILE"

  # Start waiting BEFORE signaling answer (prevent race condition)
  tmux wait-for "$SIGNAL_CHANNEL" &
  WAIT_PID=$!

  # Signal wrapper to resume
  tmux wait-for -S "$ANSWER_CHANNEL"
  log "answer sent, waiting for response..."
  echo "[skynet] answer sent, waiting..."

  # Wait for next signal
  START_TIME=$(date +%s)
  if [ "$TIMEOUT" -gt 0 ]; then
    while kill -0 "$WAIT_PID" 2>/dev/null; do
      NOW=$(date +%s)
      elapsed=$(( NOW - START_TIME ))
      if [ "$elapsed" -ge "$TIMEOUT" ]; then
        kill "$WAIT_PID" 2>/dev/null || true
        tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
        echo "[skynet] ERROR: timeout after ${TIMEOUT}s" >&2
        rm -f "$STATE_FILE"
        exit 2
      fi
      sleep 2
    done
    wait "$WAIT_PID" 2>/dev/null || true
  else
    wait "$WAIT_PID"
  fi

  END_TIME=$(date +%s)
  elapsed=$(( END_TIME - START_TIME ))
  STATUS=$(cat "$STATUS_FILE" 2>/dev/null || echo "UNKNOWN")

  if [ "$STATUS" = "QUESTION" ]; then
    log "follow-up QUESTION (account: $ACCOUNT_NAME, ${elapsed}s)"
    echo "[skynet] status: NEEDS_CLARIFICATION (follow-up)"
    echo "[skynet] elapsed: ${elapsed}s"
    echo "--- QUESTION ---"
    cat "$QUESTION_FILE" 2>/dev/null || echo "(no question text)"
    exit 3
  fi

  # DONE
  tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
  EXIT_CODE=$(cat "$EXIT_FILE" 2>/dev/null || echo "1")

  echo "[skynet] account: $ACCOUNT_NAME"
  echo "[skynet] elapsed: ${elapsed}s"

  if [ "$EXIT_CODE" = "0" ]; then
    echo "[skynet] status: SUCCESS"
    echo "--- OUTPUT ---"
    if command -v jq >/dev/null 2>&1 && jq -e '.result' "$OUTPUT_FILE" >/dev/null 2>&1; then
      jq -r '.result' "$OUTPUT_FILE"
    else
      cat "$OUTPUT_FILE" 2>/dev/null || echo "(no output)"
    fi
    rm -f "$STATE_FILE" "$EXIT_FILE"
    exit 0
  else
    echo "[skynet] status: FAILED (exit $EXIT_CODE)"
    echo "--- ERROR ---"
    cat "$ERR_FILE" 2>/dev/null || echo "(no error)"
    rm -f "$STATE_FILE" "$EXIT_FILE"
    exit 1
  fi
fi

# ══════════════════════════════════════════════════════════════════════════════════
# INITIAL RUN MODE
# ══════════════════════════════════════════════════════════════════════════════════
log "start — task: $TASK_ID, project: $PROJECT_DIR"
rm -f "$EXIT_FILE" "$STATUS_FILE" "$QUESTION_FILE" "$STATE_FILE"

# ── Discover accounts ──────────────────────────────────────────────────────────
ACCOUNTS=()
while IFS= read -r f; do
  ACCOUNTS+=("$f")
done < <(ls "$ACCOUNTS_DIR"/claude-ooth-*.txt 2>/dev/null | sort)

TOTAL=${#ACCOUNTS[@]}
if [ "$TOTAL" -eq 0 ]; then
  log "ERROR: no accounts in $ACCOUNTS_DIR"
  echo "ERROR: no Claude token files found in $ACCOUNTS_DIR (expected claude-ooth-*.txt)" >&2
  exit 1
fi
log "accounts: $TOTAL found"

# ── Round-robin state ──────────────────────────────────────────────────────────
RR_STATE="$HOME/.claude/skynet-claude-rr-index"
RR_INDEX=0
[ -f "$RR_STATE" ] && RR_INDEX=$(cat "$RR_STATE" 2>/dev/null) || true
[ "$RR_INDEX" -ge "$TOTAL" ] 2>/dev/null && RR_INDEX=0 || true

# ── Failover loop ─────────────────────────────────────────────────────────────
SKIP_LIST=""
ATTEMPT=0

for attempt_i in $(seq 0 $((TOTAL - 1))); do
  # Select next account — round-robin, skip failed ones
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

  ACCOUNT_NAME=$(basename "$CREDS" .txt | sed 's/claude-ooth-//')
  ATTEMPT=$((ATTEMPT + 1))
  SESSION="skynet-claude-${TASK_ID}-${ATTEMPT}"
  SIGNAL_CHANNEL="skynet-csig-${TASK_ID}-${ATTEMPT}"
  ANSWER_CHANNEL="skynet-cans-${TASK_ID}-${ATTEMPT}"

  log "attempt $ATTEMPT/$TOTAL — account: $ACCOUNT_NAME"
  echo "[skynet] attempt $ATTEMPT/$TOTAL — account: $ACCOUNT_NAME"

  rm -f "$EXIT_FILE" "$STATUS_FILE" "$OUTPUT_FILE" "$ERR_FILE" "$QUESTION_FILE"

  # Read and validate token
  TOKEN=$(cat "$CREDS" 2>/dev/null | tr -d '[:space:]')
  if [ -z "$TOKEN" ]; then
    log "empty token in $CREDS — skip"
    SKIP_LIST="$SKIP_LIST|$CREDS"
    continue
  fi

  # Generate session UUID
  UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')

  # Save state for --answer mode
  cat > "$STATE_FILE" <<STATE_EOF
SIGNAL_CHANNEL=$SIGNAL_CHANNEL
ANSWER_CHANNEL=$ANSWER_CHANNEL
SESSION_NAME=$SESSION
ACCOUNT_NAME=$ACCOUNT_NAME
UUID=$UUID
STATE_EOF

  # ── Write wrapper script ───────────────────────────────────────────────────
  WRAPPER="$PIPE_DIR/${TASK_ID}-wrapper.sh"
  trap 'rm -f "$WRAPPER"' EXIT
  cat > "$WRAPPER" <<WRAPPER_EOF
#!/usr/bin/env bash
set -e
cd $(printf '%q' "$PROJECT_DIR")
export CLAUDE_CODE_OAUTH_TOKEN=$(printf '%q' "$TOKEN")

SIGNAL=$(printf '%q' "$SIGNAL_CHANNEL")
ANSWER=$(printf '%q' "$ANSWER_CHANNEL")
OUT=$(printf '%q' "$OUTPUT_FILE")
ERR=$(printf '%q' "$ERR_FILE")
EXITF=$(printf '%q' "$EXIT_FILE")
STATUSF=$(printf '%q' "$STATUS_FILE")
QUESTIONF=$(printf '%q' "$QUESTION_FILE")
ANSWERF=$(printf '%q' "$ANSWER_FILE")
UUID=$(printf '%q' "$UUID")
MODEL=$(printf '%q' "$CLAUDE_MODEL")
MAX_ROUNDS=$MAX_ROUNDS
TASK_FILE=$(printf '%q' "$TASK_FILE")

# Safety net: signal DONE on unexpected exit
cleanup() {
  if [ ! -f "\$EXITF" ]; then
    echo "1" > "\${EXITF}.tmp" && mv "\${EXITF}.tmp" "\$EXITF"
  fi
  local s=\$(cat "\$STATUSF" 2>/dev/null || echo "")
  if [ "\$s" != "DONE" ] && [ "\$s" != "QUESTION" ]; then
    echo "DONE" > "\${STATUSF}.tmp" && mv "\${STATUSF}.tmp" "\$STATUSF"
    tmux wait-for -S "\$SIGNAL" 2>/dev/null || true
  fi
}
trap cleanup EXIT

ROUND=0
EC=1

while [ \$ROUND -lt \$MAX_ROUNDS ]; do
  ROUND=\$((ROUND + 1))
  rm -f "\$STATUSF" "\$EXITF"

  if [ \$ROUND -eq 1 ]; then
    claude -p "\$(cat \$TASK_FILE)" \
      --output-format json \
      --session-id "\$UUID" \
      --dangerously-skip-permissions \
      --model "\$MODEL" \
      > "\$OUT" 2> "\$ERR" && EC=0 || EC=\$?
  else
    A=\$(cat "\$ANSWERF" 2>/dev/null || echo "Please continue.")
    rm -f "\$ANSWERF"
    claude -r "\$UUID" -p "\$A" \
      --output-format json \
      --dangerously-skip-permissions \
      --model "\$MODEL" \
      > "\$OUT" 2> "\$ERR" && EC=0 || EC=\$?
  fi

  # Detect NEEDS_CLARIFICATION — tight match: **Status** immediately followed by it
  # Avoids false positives when output mentions NEEDS_CLARIFICATION in other context
  if grep -qE '\*\*Status\*\*:? *NEEDS_CLARIFICATION' "\$OUT" 2>/dev/null && [ \$ROUND -lt \$MAX_ROUNDS ]; then
    # Extract question from JSON result field
    if command -v jq >/dev/null 2>&1; then
      jq -r '.result // empty' "\$OUT" > "\$QUESTIONF" 2>/dev/null || \
        cp "\$OUT" "\$QUESTIONF"
    else
      cp "\$OUT" "\$QUESTIONF"
    fi
    echo "QUESTION" > "\${STATUSF}.tmp" && mv "\${STATUSF}.tmp" "\$STATUSF"
    trap - EXIT
    tmux wait-for -S "\$SIGNAL" 2>/dev/null || true
    tmux wait-for "\$ANSWER"
    trap cleanup EXIT
    continue
  fi

  break
done

# Final result
trap - EXIT
echo "\$EC" > "\${EXITF}.tmp" && mv "\${EXITF}.tmp" "\$EXITF"
echo "DONE" > "\${STATUSF}.tmp" && mv "\${STATUSF}.tmp" "\$STATUSF"
tmux wait-for -S "\$SIGNAL" 2>/dev/null || true
WRAPPER_EOF

  # ── Start tmux session ─────────────────────────────────────────────────────
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  tmux new-session -d -s "$SESSION" -x 220 -y 50
  tmux send-keys -t "$SESSION" "bash $(printf '%q' "$WRAPPER")" Enter

  log "claude started in $SESSION (account: $ACCOUNT_NAME, model: $CLAUDE_MODEL, uuid: $UUID)"
  echo "[skynet] worker started: $SESSION"
  echo "[skynet] model: $CLAUDE_MODEL | session: $UUID"

  # ── Wait for signal ────────────────────────────────────────────────────────
  START_TIME=$(date +%s)

  if ! wait_for_signal "$SIGNAL_CHANNEL"; then
    log "TIMEOUT on account $ACCOUNT_NAME"
    tmux kill-session -t "$SESSION" 2>/dev/null || true
    echo "[skynet] ERROR: timeout after ${TIMEOUT}s" >&2
    rm -f "$WRAPPER" "$STATE_FILE"
    exit 2
  fi

  END_TIME=$(date +%s)
  elapsed=$(( END_TIME - START_TIME ))
  STATUS=$(cat "$STATUS_FILE" 2>/dev/null || echo "UNKNOWN")
  rm -f "$WRAPPER"
  trap - EXIT

  # ── Handle QUESTION ────────────────────────────────────────────────────────
  if [ "$STATUS" = "QUESTION" ]; then
    log "QUESTION from worker (account: $ACCOUNT_NAME, ${elapsed}s)"
    echo "[skynet] status: NEEDS_CLARIFICATION"
    echo "[skynet] account: $ACCOUNT_NAME"
    echo "[skynet] elapsed: ${elapsed}s"
    echo "--- QUESTION ---"
    cat "$QUESTION_FILE" 2>/dev/null || echo "(no question text)"
    exit 3
  fi

  # ── Handle DONE ────────────────────────────────────────────────────────────
  tmux kill-session -t "$SESSION" 2>/dev/null || true

  if [ ! -f "$EXIT_FILE" ]; then
    log "no exit file — session may have crashed"
    SKIP_LIST="$SKIP_LIST|$CREDS"
    rm -f "$STATE_FILE"
    continue
  fi

  EXIT_CODE=$(cat "$EXIT_FILE")
  log "exit code: $EXIT_CODE (${elapsed}s, account: $ACCOUNT_NAME)"

  if [ "$EXIT_CODE" = "0" ]; then
    echo "[skynet] status: SUCCESS"
    echo "[skynet] account: $ACCOUNT_NAME"
    echo "[skynet] attempts: $ATTEMPT/$TOTAL"
    echo "[skynet] elapsed: ${elapsed}s"
    echo "--- OUTPUT ---"
    if command -v jq >/dev/null 2>&1 && jq -e '.result' "$OUTPUT_FILE" >/dev/null 2>&1; then
      jq -r '.result' "$OUTPUT_FILE"
    else
      cat "$OUTPUT_FILE" 2>/dev/null || echo "(no output)"
    fi
    rm -f "$STATE_FILE" "$EXIT_FILE"
    exit 0
  fi

  # Rate limit → failover
  if grep -qiE "429|rate.?limit|overloaded|capacity" "$ERR_FILE" 2>/dev/null; then
    log "rate limited on $ACCOUNT_NAME — failover"
    echo "[skynet] rate limited on $ACCOUNT_NAME — trying next..."
    SKIP_LIST="$SKIP_LIST|$CREDS"
    rm -f "$STATE_FILE" "$EXIT_FILE"
    continue
  fi

  # Other error — stop
  echo "[skynet] status: FAILED (exit $EXIT_CODE)"
  echo "[skynet] account: $ACCOUNT_NAME"
  echo "[skynet] elapsed: ${elapsed}s"
  echo "--- ERROR ---"
  cat "$ERR_FILE" 2>/dev/null || echo "(no error)"
  rm -f "$STATE_FILE" "$EXIT_FILE"
  exit 1
done

# All accounts exhausted
echo "[skynet] FAILED: all $TOTAL accounts exhausted"
echo "[skynet] attempts: $ATTEMPT/$TOTAL"
rm -f "$STATE_FILE"
exit 1
