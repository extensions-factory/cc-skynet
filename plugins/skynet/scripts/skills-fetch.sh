#!/usr/bin/env bash
# Fetch or update the antigravity skills repository
set -euo pipefail

CACHE_DIR="$HOME/.claude/skills-cache/antigravity-awesome-skills"
REPO="https://github.com/sickn33/antigravity-awesome-skills"
LOG="$HOME/.claude/logs/skynet-skills.log"

mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date '+%H:%M:%S')] [skills-fetch] $*" | tee -a "$LOG"; }

log "start — cache: $CACHE_DIR"

if [ -d "$CACHE_DIR/.git" ]; then
  log "repo exists, pulling..."
  if git -C "$CACHE_DIR" pull --quiet 2>/dev/null; then
    log "updated: $(git -C "$CACHE_DIR" rev-parse --short HEAD)"
  else
    log "WARN: pull failed (network issue?) — using cached version"
    echo "WARNING: skills update failed, using cached version" >&2
  fi
else
  log "cloning $REPO..."
  if git clone --depth=1 --quiet "$REPO" "$CACHE_DIR"; then
    log "cloned: $(git -C "$CACHE_DIR" rev-parse --short HEAD)"
  else
    log "ERROR: clone failed — check network and repo URL"
    echo "ERROR: failed to clone skills repo" >&2
    exit 1
  fi
fi

count=$(find "$CACHE_DIR/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
categories=$(jq -r '.[].category' "$CACHE_DIR/skills_index.json" 2>/dev/null | sort -u | tr '\n' ' ')

# Basic integrity check
valid=$(find "$CACHE_DIR/skills" -name "SKILL.md" -maxdepth 2 2>/dev/null | wc -l | tr -d ' ')
if [ "$valid" -lt 10 ]; then
  log "WARN: only $valid SKILL.md files found — verify repo integrity at $REPO"
  echo "WARNING: skills repo may be incomplete ($valid skills found)" >&2
fi

log "available: $count skills across categories: $categories"
echo "available: $count skills"
echo "categories: $categories"
