#!/usr/bin/env bash
# Symlink skills matching project categories to .claude/skills/
# Reads categories from .claude/skynet.json, resolves via skills_index.json
set -euo pipefail

CACHE_DIR="$HOME/.claude/skills-cache/antigravity-awesome-skills"
INDEX="$CACHE_DIR/skills_index.json"
PROJECT_CONFIG=".claude/skynet.json"
SKILLS_DIR=".claude/skills"
LOG="$HOME/.claude/logs/skynet-skills.log"

mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date '+%H:%M:%S')] [skills-link] $*" >> "$LOG"; }

log "start — cwd: $(pwd)"

[ -f "$PROJECT_CONFIG" ] || { log "no $PROJECT_CONFIG — skip"; exit 0; }
[ -d "$CACHE_DIR" ]      || { log "cache not found — skip"; echo "skills cache not found — run /skynet-skills fetch first" >&2; exit 0; }
[ -f "$INDEX" ]          || { log "index not found — skip"; echo "skills_index.json missing — re-run /skynet-skills fetch" >&2; exit 0; }

mkdir -p "$SKILLS_DIR"

categories=$(jq -r '.skills[]?' "$PROJECT_CONFIG" 2>/dev/null)
[ -n "$categories" ] || { log "no categories in $PROJECT_CONFIG — skip"; exit 0; }

log "categories: $(echo "$categories" | tr '\n' ' ')"

linked=0
skipped=0
while IFS= read -r category; do
  [ -n "$category" ] || continue

  while IFS= read -r skill_path; do
    [ -n "$skill_path" ] || continue
    skill_name=$(basename "$skill_path")
    src="$CACHE_DIR/$skill_path"
    dst="$SKILLS_DIR/$skill_name"

    if [ ! -d "$src" ]; then
      log "  [$category] $skill_name — src not found, skip"
      skipped=$((skipped + 1))
      continue
    fi

    # Remove broken symlinks before checking existence
    if [ -L "$dst" ] && [ ! -e "$dst" ]; then
      rm "$dst"
      log "  [$category] $skill_name — removed broken symlink"
    fi

    if [ -e "$dst" ]; then
      log "  [$category] $skill_name — already linked, skip"
      skipped=$((skipped + 1))
    else
      ln -sf "$src" "$dst"
      log "  [$category] $skill_name — linked"
      echo "linked: $skill_name [$category]"
      linked=$((linked + 1))
    fi
  done < <(jq -r --arg c "$category" '.[] | select(.category == $c) | .path' "$INDEX" 2>/dev/null)
done <<< "$categories"

log "done — linked: $linked, skipped: $skipped"
[ "$linked" -gt 0 ] && echo "total: $linked skills linked" || true
