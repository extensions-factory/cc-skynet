#!/usr/bin/env bash
# Delegate a task to Codex CLI via tmux.
# Single account — no round-robin, no failover.
# Signaling: tmux wait-for (instant, no polling) + atomic file write.
#
# Usage: spawn-codex-worker.sh <task-file>
#
# Env overrides:
#   SKYNET_ACCOUNTS_DIR  — path to credentials dir (default: $PWD/accounts)
#   SKYNET_TASK_TIMEOUT  — max seconds, 0 = no timeout (default: 0)
#   SKYNET_CODEX_MODEL   — model name (default: codex uses its own default)
#
# Exit codes: 0=SUCCESS, 1=FAILED, 2=TIMEOUT
set -euo pipefail

TASK_FILE="$(realpath "${1:?Usage: spawn-codex-worker.sh <task-file>}")"
TIMEOUT="${SKYNET_TASK_TIMEOUT:-0}"
PROJECT_DIR="$(pwd)"
ACCOUNTS_DIR="${SKYNET_ACCOUNTS_DIR:-$PROJECT_DIR/accounts}"
CODEX_MODEL="${SKYNET_CODEX_MODEL:-}"

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

log() { echo "[$(date '+%H:%M:%S')] [codex-worker] $*" >> "$LOG"; }
log "start — task: $TASK_ID, project: $PROJECT_DIR"

# ── Find credential file ────────────────────────────────────────────────────
CREDS=$(ls "$ACCOUNTS_DIR"/codex-auth-*.json 2>/dev/null | head -1)
if [ -z "$CREDS" ]; then
  log "ERROR: no codex auth file in $ACCOUNTS_DIR"
  echo "ERROR: no codex auth file found in $ACCOUNTS_DIR (expected codex-auth-*.json)" >&2
  exit 1
fi
ACCOUNT_NAME=$(basename "$CREDS" .json | sed 's/codex-auth-//')
log "account: $ACCOUNT_NAME ($CREDS)"

# ── Copy auth to ~/.codex/auth.json ─────────────────────────────────────────
CODEX_AUTH_DIR="$HOME/.codex"
mkdir -p "$CODEX_AUTH_DIR"
cp "$CREDS" "$CODEX_AUTH_DIR/auth.json"
log "auth copied to $CODEX_AUTH_DIR/auth.json"

# ── Build codex exec command ─────────────────────────────────────────────────
SESSION="skynet-codex-${TASK_ID}"
SIGNAL_CHANNEL="skynet-cxsig-${TASK_ID}"

rm -f "$EXIT_FILE" "$OUTPUT_FILE" "$ERR_FILE"

# ── Write wrapper script ────────────────────────────────────────────────────
WRAPPER="$PIPE_DIR/${TASK_ID}-wrapper.sh"
trap 'rm -f "$WRAPPER"' EXIT

MODEL_FLAG=""
if [ -n "$CODEX_MODEL" ]; then
  MODEL_FLAG="--model $(printf '%q' "$CODEX_MODEL")"
fi

cat > "$WRAPPER" <<WRAPPER_EOF
#!/usr/bin/env bash
set -e
cd $(printf '%q' "$PROJECT_DIR")

OUT=$(printf '%q' "$OUTPUT_FILE")
ERR=$(printf '%q' "$ERR_FILE")
EXITF=$(printf '%q' "$EXIT_FILE")
SIGNAL=$(printf '%q' "$SIGNAL_CHANNEL")
TASK=$(printf '%q' "$TASK_FILE")

# Safety net: signal DONE on unexpected exit
cleanup() {
  if [ ! -f "\$EXITF" ]; then
    echo "1" > "\${EXITF}.tmp" && mv "\${EXITF}.tmp" "\$EXITF"
  fi
  tmux wait-for -S "\$SIGNAL" 2>/dev/null || true
}
trap cleanup EXIT

cat "\$TASK" | codex exec \
  -C $(printf '%q' "$PROJECT_DIR") \
  --dangerously-bypass-approvals-and-sandbox \
  -o "\$OUT" \
  $MODEL_FLAG \
  - > "\$ERR" 2>&1 && EC=0 || EC=\$?

# Atomic write exit code
trap - EXIT
echo "\$EC" > "\${EXITF}.tmp" && mv "\${EXITF}.tmp" "\$EXITF"
tmux wait-for -S "\$SIGNAL" 2>/dev/null || true
WRAPPER_EOF

# ── Start tmux session ──────────────────────────────────────────────────────
tmux kill-session -t "$SESSION" 2>/dev/null || true
tmux new-session -d -s "$SESSION" -x 220 -y 50
tmux send-keys -t "$SESSION" "bash $(printf '%q' "$WRAPPER")" Enter

log "codex started in $SESSION (account: $ACCOUNT_NAME)"
echo "[skynet] worker started: $SESSION"
echo "[skynet] account: $ACCOUNT_NAME"
[ -n "$CODEX_MODEL" ] && echo "[skynet] model: $CODEX_MODEL"

# ── Wait for signal ─────────────────────────────────────────────────────────
START_TIME=$(date +%s)

if [ "$TIMEOUT" -gt 0 ]; then
  tmux wait-for "$SIGNAL_CHANNEL" &
  WAIT_PID=$!

  while kill -0 "$WAIT_PID" 2>/dev/null; do
    NOW=$(date +%s)
    elapsed=$(( NOW - START_TIME ))
    if [ "$elapsed" -ge "$TIMEOUT" ]; then
      kill "$WAIT_PID" 2>/dev/null || true
      log "TIMEOUT after ${TIMEOUT}s"
      tmux kill-session -t "$SESSION" 2>/dev/null || true
      echo "FAILED:timeout_${TIMEOUT}s" > "$STATUS_FILE"
      echo "[skynet] ERROR: timeout after ${TIMEOUT}s" >&2
      rm -f "$WRAPPER"
      exit 2
    fi
    sleep 2
  done
  wait "$WAIT_PID" 2>/dev/null || true
else
  tmux wait-for "$SIGNAL_CHANNEL"
fi

END_TIME=$(date +%s)
elapsed=$(( END_TIME - START_TIME ))

# ── Read result ──────────────────────────────────────────────────────────────
tmux kill-session -t "$SESSION" 2>/dev/null || true
rm -f "$WRAPPER"
trap - EXIT

if [ ! -f "$EXIT_FILE" ]; then
  log "no exit file — session may have crashed"
  echo "FAILED:no_exit_file" > "$STATUS_FILE"
  echo "[skynet] FAILED: no exit file (session crashed?)"
  exit 1
fi

EXIT_CODE=$(cat "$EXIT_FILE")
log "exit code: $EXIT_CODE (${elapsed}s, account: $ACCOUNT_NAME)"

# ── Report ───────────────────────────────────────────────────────────────────
echo "[skynet] account: $ACCOUNT_NAME"
echo "[skynet] elapsed: ${elapsed}s"

if [ "$EXIT_CODE" = "0" ]; then
  echo "SUCCESS" > "$STATUS_FILE"
  echo "[skynet] status: SUCCESS"
  echo "--- OUTPUT ---"
  cat "$OUTPUT_FILE" 2>/dev/null || echo "(no output)"
  rm -f "$EXIT_FILE"
  exit 0
else
  echo "FAILED:exit_${EXIT_CODE}" > "$STATUS_FILE"
  echo "[skynet] status: FAILED (exit $EXIT_CODE)"
  echo "--- ERROR ---"
  cat "$ERR_FILE" 2>/dev/null || echo "(no error output)"
  rm -f "$EXIT_FILE"
  exit 1
fi
