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

# ── Gemini skills mirror ─────────────────────────────────────────────────────
# Symlink .gemini/skills → .claude/skills so Gemini CLI sees the same skills
GEMINI_SKILLS=".gemini/skills"
mkdir -p "$(dirname "$GEMINI_SKILLS")"
if [ -L "$GEMINI_SKILLS" ] && [ ! -e "$GEMINI_SKILLS" ]; then
  rm "$GEMINI_SKILLS"
  log "removed broken .gemini/skills symlink"
fi
if [ ! -e "$GEMINI_SKILLS" ]; then
  ln -sf "../$SKILLS_DIR" "$GEMINI_SKILLS"
  log "linked .gemini/skills → $SKILLS_DIR"
  echo "linked: .gemini/skills → $SKILLS_DIR"
fi

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

log "done [antigravity] — linked: $linked, skipped: $skipped"
[ "$linked" -gt 0 ] && echo "total [antigravity]: $linked skills linked" || true

# ── everything-claude-code skills (link all) ──────────────────────────────────
ECC_DIR="$HOME/.claude/skills-cache/everything-claude-code"
if [ ! -d "$ECC_DIR/skills" ]; then
  log "everything-claude-code not cached — skip (run skills-fetch first)"
else
  ecc_linked=0
  ecc_skipped=0
  while IFS= read -r skill_dir; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    dst="$SKILLS_DIR/$skill_name"

    if [ -L "$dst" ] && [ ! -e "$dst" ]; then
      rm "$dst"
      log "  [ecc] $skill_name — removed broken symlink"
    fi

    if [ -e "$dst" ]; then
      log "  [ecc] $skill_name — already linked, skip"
      ecc_skipped=$((ecc_skipped + 1))
    else
      ln -sf "$skill_dir" "$dst"
      log "  [ecc] $skill_name — linked"
      ecc_linked=$((ecc_linked + 1))
    fi
  done < <(find "$ECC_DIR/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)

  log "done [ecc] — linked: $ecc_linked, skipped: $ecc_skipped"
  [ "$ecc_linked" -gt 0 ] && echo "total [ecc]: $ecc_linked skills linked" || true
fi
