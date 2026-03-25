#!/usr/bin/env bash
# Symlink skills matching project categories to .claude/skills/
# Reads categories from .claude/skynet.json, resolves via skills_index.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/log-common.sh"

CACHE_DIR="$HOME/.claude/skills-cache/antigravity-awesome-skills"
INDEX="$CACHE_DIR/skills_index.json"
PROJECT_CONFIG=".claude/skynet.json"
SKILLS_DIR=".claude/skills"
skynet_init_log

log() {
  skynet_log "skills-link" "$*"
}

ensure_mirror_link() {
  local mirror="$1"
  local target="../$SKILLS_DIR"

  mkdir -p "$(dirname "$mirror")"

  if [ -L "$mirror" ] && [ ! -e "$mirror" ]; then
    rm "$mirror"
    log "removed broken $mirror symlink"
  fi

  if [ -L "$mirror" ]; then
    local current_target
    current_target=$(readlink "$mirror" 2>/dev/null || true)
    if [ "$current_target" = "$target" ]; then
      log "$mirror already points to $target"
      return 0
    fi
    rm "$mirror"
    log "relinked $mirror from $current_target to $target"
  elif [ -e "$mirror" ]; then
    if [ -d "$mirror" ] && [ -z "$(find "$mirror" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
      rmdir "$mirror"
      log "removed empty directory at $mirror before linking"
    else
      log "cannot link $mirror because it already exists and is not a replaceable symlink"
      echo "skip: $mirror exists and is not a symlink" >&2
      return 0
    fi
  fi

  ln -snf "$target" "$mirror"
  log "linked $mirror -> $target"
  echo "linked: $mirror -> $target"
}

log "start — cwd: $(pwd)"

# ── Skills mirrors ───────────────────────────────────────────────────────────
# Symlink .gemini/skills and .codex/skills → .claude/skills so all CLIs see the same skills
for mirror in ".gemini/skills" ".codex/skills"; do
  ensure_mirror_link "$mirror"
done

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
  log "everything-claude-code not cached — skip (run external-libs-fetch first)"
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
