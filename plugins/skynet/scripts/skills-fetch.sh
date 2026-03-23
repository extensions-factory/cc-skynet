#!/usr/bin/env bash
# Fetch or update all skills/agents repositories
set -euo pipefail

LOG="$HOME/.claude/logs/skynet-skills.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date '+%H:%M:%S')] [skills-fetch] $*" | tee -a "$LOG"; }

# ── Repo 1: antigravity-awesome-skills ────────────────────────────────────────
ANTIGRAVITY_DIR="$HOME/.claude/skills-cache/antigravity-awesome-skills"
ANTIGRAVITY_REPO="https://github.com/sickn33/antigravity-awesome-skills"

log "start — antigravity"
if [ -d "$ANTIGRAVITY_DIR/.git" ]; then
  log "repo exists, pulling..."
  if git -C "$ANTIGRAVITY_DIR" pull --quiet 2>/dev/null; then
    log "updated: $(git -C "$ANTIGRAVITY_DIR" rev-parse --short HEAD)"
  else
    log "WARN: pull failed (network issue?) — using cached version"
    echo "WARNING: antigravity update failed, using cached version" >&2
  fi
else
  log "cloning $ANTIGRAVITY_REPO..."
  if git clone --depth=1 --quiet "$ANTIGRAVITY_REPO" "$ANTIGRAVITY_DIR"; then
    log "cloned: $(git -C "$ANTIGRAVITY_DIR" rev-parse --short HEAD)"
  else
    log "ERROR: clone failed — check network and repo URL"
    echo "ERROR: failed to clone antigravity skills repo" >&2
    exit 1
  fi
fi

ag_count=$(find "$ANTIGRAVITY_DIR/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
ag_categories=$(jq -r '.[].category' "$ANTIGRAVITY_DIR/skills_index.json" 2>/dev/null | sort -u | tr '\n' ' ')
valid=$(find "$ANTIGRAVITY_DIR/skills" -name "SKILL.md" -maxdepth 2 2>/dev/null | wc -l | tr -d ' ')
[ "$valid" -lt 10 ] && { log "WARN: only $valid SKILL.md files — verify repo integrity"; echo "WARNING: antigravity repo may be incomplete" >&2; }
log "antigravity: $ag_count skills, categories: $ag_categories"

# ── Repo 2: everything-claude-code ────────────────────────────────────────────
ECC_DIR="$HOME/.claude/skills-cache/everything-claude-code"
ECC_REPO="https://github.com/affaan-m/everything-claude-code"

log "start — everything-claude-code"
if [ -d "$ECC_DIR/.git" ]; then
  log "repo exists, pulling..."
  if git -C "$ECC_DIR" pull --quiet 2>/dev/null; then
    log "updated: $(git -C "$ECC_DIR" rev-parse --short HEAD)"
  else
    log "WARN: pull failed (network issue?) — using cached version"
    echo "WARNING: everything-claude-code update failed, using cached version" >&2
  fi
else
  log "cloning $ECC_REPO..."
  if git clone --depth=1 --quiet "$ECC_REPO" "$ECC_DIR"; then
    log "cloned: $(git -C "$ECC_DIR" rev-parse --short HEAD)"
  else
    log "ERROR: clone failed — check network and repo URL"
    echo "ERROR: failed to clone everything-claude-code repo" >&2
    exit 1
  fi
fi

ecc_skills=$(find "$ECC_DIR/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
ecc_agents=$(find "$ECC_DIR/agents" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
log "everything-claude-code: $ecc_skills skills, $ecc_agents agents"

# ── Summary ───────────────────────────────────────────────────────────────────
echo "antigravity: $ag_count skills | categories: $ag_categories"
echo "everything-claude-code: $ecc_skills skills, $ecc_agents agents"
