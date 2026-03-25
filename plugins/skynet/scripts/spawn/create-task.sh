#!/usr/bin/env bash
# Create a task brief file for Gemini worker.
#
# Usage: create-task.sh <task-id> <title> [--parent-issue N] [--worker TYPE] [--project N] < body_from_stdin
# Output: prints absolute path to created task file
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/log-common.sh"
skynet_init_log
log() { skynet_log "create-task" "$*"; }

TASK_ID="${1:?Usage: create-task.sh <task-id> <title>}"
TITLE="${2:?Missing title}"
shift 2

TASKS_DIR="${SKYNET_TASKS_DIR:-$(pwd)/tasks}"
OUTPUT="$TASKS_DIR/task-${TASK_ID}.md"

# Capture body from stdin BEFORE argument parsing (stdin can only be read once)
BODY=""
if [ ! -t 0 ]; then
  BODY=$(cat)
fi

# Parse optional flags
PARENT_ISSUE=""
WORKER_TYPE=""
GH_PROJECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --parent-issue) PARENT_ISSUE="${2:?--parent-issue requires a value}"; shift 2 ;;
    --worker)       WORKER_TYPE="${2:?--worker requires a value}"; shift 2 ;;
    --project)      GH_PROJECT="${2:?--project requires a value}"; shift 2 ;;
    *) shift ;;
  esac
done

mkdir -p "$TASKS_DIR" "$LOG_DIR"

cat > "$OUTPUT" <<MARKDOWN
# $TITLE

**ID:** $TASK_ID | **Created:** $(date '+%Y-%m-%d %H:%M:%S')

$BODY

---
*Complete all instructions above. Provide a thorough, well-structured response.*
MARKDOWN

# Optional: create GitHub sub-issue if parent and worker are specified
if [ -n "${PARENT_ISSUE:-}" ] && [ -n "${WORKER_TYPE:-}" ]; then
  "$SCRIPT_DIR/gh-subtask-create.sh" "$TASK_ID" "$TITLE" \
    --parent "$PARENT_ISSUE" \
    --worker "$WORKER_TYPE" \
    ${GH_PROJECT:+--project "$GH_PROJECT"} \
    <<< "$BODY" \
    >> "$LOG" 2>&1 || log "WARNING: GitHub sub-issue creation failed (non-fatal)"
fi

echo "$OUTPUT"
