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
  git -C "$CACHE_DIR" fetch --quiet
  git -C "$CACHE_DIR" pull --quiet
  log "updated: $(git -C "$CACHE_DIR" rev-parse --short HEAD)"
else
  log "cloning $REPO..."
  git clone --depth=1 --quiet "$REPO" "$CACHE_DIR"
  log "cloned: $(git -C "$CACHE_DIR" rev-parse --short HEAD)"
fi

count=$(find "$CACHE_DIR/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
categories=$(jq -r '.[].category' "$CACHE_DIR/skills_index.json" 2>/dev/null | sort -u | tr '\n' ' ')

log "available: $count skills across categories: $categories"
echo "available: $count skills"
echo "categories: $categories"
