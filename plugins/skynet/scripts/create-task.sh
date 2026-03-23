#!/usr/bin/env bash
# Create a task brief file for Gemini worker.
#
# Usage: create-task.sh <task-id> <title> < body_from_stdin
# Output: prints absolute path to created task file
set -euo pipefail

TASK_ID="${1:?Usage: create-task.sh <task-id> <title>}"
TITLE="${2:?Missing title}"
TASKS_DIR="${SKYNET_TASKS_DIR:-$(pwd)/tasks}"
OUTPUT="$TASKS_DIR/task-${TASK_ID}.md"

mkdir -p "$TASKS_DIR"

BODY=""
if [ ! -t 0 ]; then
  BODY=$(cat)
fi

cat > "$OUTPUT" <<MARKDOWN
**ID:** $TASK_ID | **Created:** $(date '+%Y-%m-%d %H:%M:%S')

$BODY

---
*Complete all instructions above. Provide a thorough, well-structured response.*
MARKDOWN

echo "$OUTPUT"
