#!/usr/bin/env bash
# ── sources.sh — external skills/agents registry management ──

# shellcheck source=./common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

CACHE_DIR="$HOME/.claude/skills-cache"
REPOS_DIR="$CACHE_DIR/repos"
STATE_FILE="$CACHE_DIR/state.json"
SOURCES_FILE="$PLUGIN_DIR/sources.json"

# ── Helpers ──────────────────────────────────────────────

# Ensure cache directories exist
_ensure_cache() {
  mkdir -p "$REPOS_DIR"
  [ -f "$STATE_FILE" ] || echo '{"repos":{}}' > "$STATE_FILE"
}

# Get source field from sources.json
# Usage: _source_field <name> <field>
_source_field() {
  local name="$1" field="$2"
  _NAME="$name" _FIELD="$field" _SOURCES_FILE="$SOURCES_FILE" python3 -c "
import json, os, sys
name = os.environ['_NAME']
field = os.environ['_FIELD']
with open(os.environ['_SOURCES_FILE']) as f:
    data = json.load(f)
for s in data['sources']:
    if s['name'] == name:
        print(s.get(field, ''))
        sys.exit(0)
sys.exit(1)
"
}

# Get repo directory name from URL
# https://github.com/user/repo-name -> repo-name
_repo_dirname() {
  local repo_url="$1"
  basename "$repo_url" .git
}

# Resolve full path to a source's repo in cache
repo_dir() {
  local name="$1"
  local repo_url
  repo_url="$(_source_field "$name" "repo")"
  echo "$REPOS_DIR/$(_repo_dirname "$repo_url")"
}

# Check if a source needs syncing (stale check)
_is_stale() {
  local name="$1"
  local interval_hours
  interval_hours="$(_source_field "$name" "sync_interval_hours")"
  [ -z "$interval_hours" ] && interval_hours=24

  _NAME="$name" _INTERVAL_HOURS="$interval_hours" _STATE_FILE="$STATE_FILE" python3 -c "
import json, os, sys
from datetime import datetime, timezone, timedelta

name = os.environ['_NAME']
interval_hours = int(os.environ['_INTERVAL_HOURS'])

state_path = os.environ['_STATE_FILE']
if not os.path.exists(state_path):
    sys.exit(0)  # Never synced = stale

with open(state_path) as f:
    state = json.load(f)

repo = state.get('repos', {}).get(name, {})
last_sync = repo.get('last_sync', '')
if not last_sync:
    sys.exit(0)  # Never synced = stale

last = datetime.fromisoformat(last_sync)
if last.tzinfo is None:
    last = last.replace(tzinfo=timezone.utc)
now = datetime.now(timezone.utc)
if now - last > timedelta(hours=interval_hours):
    sys.exit(0)  # Stale
sys.exit(1)  # Fresh
"
}

# Update state.json with sync timestamp
_update_state() {
  local name="$1" repo_path="$2"
  local commit
  commit=$(git -C "$repo_path" rev-parse --short HEAD 2>/dev/null || echo "unknown")

  _NAME="$name" _COMMIT="$commit" _REPO_PATH="$repo_path" _STATE_FILE="$STATE_FILE" python3 -c "
import json, os
from datetime import datetime, timezone

name = os.environ['_NAME']
commit = os.environ['_COMMIT']
repo_path = os.environ['_REPO_PATH']

with open(os.environ['_STATE_FILE']) as f:
    state = json.load(f)

state.setdefault('repos', {})[name] = {
    'last_sync': datetime.now(timezone.utc).isoformat(),
    'commit': commit,
    'path': repo_path
}

with open(os.environ['_STATE_FILE'], 'w') as f:
    json.dump(state, f, indent=2)
"
}

# ── Source Management ────────────────────────────────────

source_clone() {
  local name="$1"
  local repo_url branch dest

  repo_url="$(_source_field "$name" "repo")" || { fail "Source '$name' not found"; return 1; }
  branch="$(_source_field "$name" "branch")"
  [ -z "$branch" ] && branch="main"
  dest="$REPOS_DIR/$(_repo_dirname "$repo_url")"

  if [ -d "$dest/.git" ]; then
    info "$name — already cloned"
    return 0
  fi

  _ensure_cache
  info "Cloning $name ($repo_url)..."
  if git clone --depth 1 --branch "$branch" "$repo_url" "$dest" 2>&1; then
    _update_state "$name" "$dest"
    ok "$name — cloned"
  else
    fail "$name — clone failed"
    return 1
  fi
}

source_pull() {
  local name="$1"
  local dest
  dest="$(repo_dir "$name")"

  if [ ! -d "$dest/.git" ]; then
    source_clone "$name"
    return $?
  fi

  info "Pulling $name..."
  if git -C "$dest" pull --depth 1 --ff-only 2>&1; then
    _update_state "$name" "$dest"
    ok "$name — updated"
  else
    warn "$name — pull failed, using cached version"
  fi
}

source_sync() {
  local target="${1:-}"
  local auto_mode="${2:-false}"
  local did_sync=false

  if [ "$target" = "--all" ] || [ -z "$target" ]; then
    # Sync all sources
    local names
    names=$(_SOURCES_FILE="$SOURCES_FILE" python3 -c "
import json, os
with open(os.environ['_SOURCES_FILE']) as f:
    data = json.load(f)
for s in data['sources']:
    print(s['name'])
")
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      if [ "$auto_mode" = "true" ]; then
        if ! _is_stale "$name"; then
          continue
        fi
        local auto_sync
        auto_sync="$(_source_field "$name" "auto_sync")"
        [ "$auto_sync" != "True" ] && [ "$auto_sync" != "true" ] && continue
      fi
      source_pull "$name"
      did_sync=true
    done <<< "$names"
  else
    if [ "$auto_mode" = "true" ] && ! _is_stale "$target"; then
      return 0
    fi
    source_pull "$target"
    did_sync=true
  fi

  # Rebuild index after sync
  if [ "$did_sync" = "true" ]; then
    import_build_index
  fi
}

source_add() {
  local repo_url="$1" name="${2:-}"

  # Auto-derive name from URL if not provided
  if [ -z "$name" ]; then
    name="$(_repo_dirname "$repo_url")"
  fi

  # Check if source already exists
  if _source_field "$name" "repo" >/dev/null 2>&1; then
    fail "Source '$name' already exists"
    return 1
  fi

  _NAME="$name" _REPO_URL="$repo_url" _SOURCES_FILE="$SOURCES_FILE" python3 -c "
import json, os

name = os.environ['_NAME']
repo_url = os.environ['_REPO_URL']

with open(os.environ['_SOURCES_FILE']) as f:
    data = json.load(f)

data['sources'].append({
    'name': name,
    'repo': repo_url,
    'branch': 'main',
    'auto_sync': True,
    'sync_interval_hours': 24
})

with open(os.environ['_SOURCES_FILE'], 'w') as f:
    json.dump(data, f, indent=2)
"
  ok "Source '$name' added ($repo_url)"
}

source_remove() {
  local name="$1"

  _NAME="$name" _SOURCES_FILE="$SOURCES_FILE" python3 -c "
import json, os

name = os.environ['_NAME']

with open(os.environ['_SOURCES_FILE']) as f:
    data = json.load(f)

data['sources'] = [s for s in data['sources'] if s['name'] != name]

with open(os.environ['_SOURCES_FILE'], 'w') as f:
    json.dump(data, f, indent=2)
"
  ok "Source '$name' removed"
}

source_list() {
  printf "\n${BOLD}Registered sources:${RESET}\n\n"

  _SOURCES_FILE="$SOURCES_FILE" _STATE_FILE="$STATE_FILE" python3 -c "
import json, os

with open(os.environ['_SOURCES_FILE']) as f:
    data = json.load(f)

state = {}
state_file = os.environ['_STATE_FILE']
if os.path.exists(state_file):
    with open(state_file) as f:
        state = json.load(f).get('repos', {})

for s in data['sources']:
    name = s['name']
    repo = s['repo']
    sync_info = state.get(name, {})
    last_sync = sync_info.get('last_sync', 'never')
    commit = sync_info.get('commit', '-')
    auto = 'auto' if s.get('auto_sync') else 'manual'
    print(f'  {name:<20} {repo}')
    print(f'  {\"\":<20} last sync: {last_sync[:19]}  commit: {commit}  [{auto}]')
    print()
"
}

# ── Import Management ────────────────────────────────────

# Read manifest field
_manifest_file() {
  echo "${PROJECT_DIR:-.}/.skills-manifest.json"
}

_ensure_manifest() {
  local manifest
  manifest="$(_manifest_file)"
  if [ ! -f "$manifest" ]; then
    echo '{"targets":["claude"],"imports":[]}' > "$manifest"
    info "Created $manifest"
  fi
}

# Get targets from manifest
_get_targets() {
  local manifest
  manifest="$(_manifest_file)"
  _MANIFEST="$manifest" python3 -c "
import json, os
with open(os.environ['_MANIFEST']) as f:
    data = json.load(f)
for t in data.get('targets', ['claude']):
    print(t)
"
}

import_link() {
  local source="$1" type="$2" name="$3" as_name="${4:-$3}"
  local project_dir="${PROJECT_DIR:-.}"
  local src_repo_dir

  src_repo_dir="$(repo_dir "$source")" || { fail "Source '$source' not found"; return 1; }

  # Validate source path exists
  local src_path="$src_repo_dir/${type}s/$name"
  if [ ! -e "$src_path" ]; then
    fail "Not found: $source:${type}s/$name"
    info "Available ${type}s:"
    ls "$src_repo_dir/${type}s/" 2>/dev/null | head -20 || info "  (none)"
    return 1
  fi

  _ensure_manifest

  # Create symlinks for each target
  while IFS= read -r target; do
    [ -z "$target" ] && continue
    local target_dir="$project_dir/.$target/${type}s"
    mkdir -p "$target_dir"
    local link_path="$target_dir/$as_name"

    if [ -L "$link_path" ]; then
      rm "$link_path"
    fi
    ln -sf "$src_path" "$link_path"
    ok ".$target/${type}s/$as_name -> $src_path"
  done < <(_get_targets)

  # Update manifest
  _MANIFEST_PATH="$(_manifest_file)" _SOURCE="$source" _TYPE="$type" _NAME="$name" _AS_NAME="$as_name" python3 -c "
import json, os

manifest_path = os.environ['_MANIFEST_PATH']
source = os.environ['_SOURCE']
type_ = os.environ['_TYPE']
name = os.environ['_NAME']
as_name = os.environ['_AS_NAME']

with open(manifest_path) as f:
    data = json.load(f)

# Remove existing import with same as_name
data['imports'] = [i for i in data['imports']
                   if not (i.get('as', i['name']) == as_name and i['type'] == type_)]

entry = {
    'source': source,
    'type': type_,
    'name': name
}
if as_name != name:
    entry['as'] = as_name

data['imports'].append(entry)

with open(manifest_path, 'w') as f:
    json.dump(data, f, indent=2)
"
}

import_unlink() {
  local name="$1"
  local project_dir="${PROJECT_DIR:-.}"

  _ensure_manifest

  # Find the import in manifest to get type
  local type
  type=$(_MANIFEST_PATH="$(_manifest_file)" _NAME="$name" python3 -c "
import json, os
name = os.environ['_NAME']
with open(os.environ['_MANIFEST_PATH']) as f:
    data = json.load(f)
for i in data['imports']:
    if i.get('as', i['name']) == name:
        print(i['type'])
        break
" 2>/dev/null)

  if [ -z "$type" ]; then
    fail "'$name' not found in manifest"
    return 1
  fi

  # Remove symlinks from all targets
  while IFS= read -r target; do
    [ -z "$target" ] && continue
    local link_path="$project_dir/.$target/${type}s/$name"
    if [ -L "$link_path" ]; then
      rm "$link_path"
      ok "Removed .$target/${type}s/$name"
    fi
  done < <(_get_targets)

  # Remove from manifest
  _MANIFEST_PATH="$(_manifest_file)" _NAME="$name" python3 -c "
import json, os

manifest_path = os.environ['_MANIFEST_PATH']
name = os.environ['_NAME']

with open(manifest_path) as f:
    data = json.load(f)

data['imports'] = [i for i in data['imports'] if i.get('as', i['name']) != name]

with open(manifest_path, 'w') as f:
    json.dump(data, f, indent=2)
"
}

import_sync() {
  local project_dir="${PROJECT_DIR:-.}"
  local manifest
  manifest="$(_manifest_file)"

  if [ ! -f "$manifest" ]; then
    warn "No .skills-manifest.json found"
    return 1
  fi

  info "Syncing imports from manifest..."

  local broken=0
  while IFS='|' read -r source type name as_name; do
    import_link "$source" "$type" "$name" "$as_name" || broken=$((broken + 1))
  done < <(_MANIFEST="$manifest" python3 -c "
import json, os
with open(os.environ['_MANIFEST']) as f:
    data = json.load(f)
for i in data['imports']:
    as_name = i.get('as', i['name'])
    print(f\"{i['source']}|{i['type']}|{i['name']}|{as_name}\")
")

  if [ "$broken" -gt 0 ]; then
    warn "$broken imports had issues"
  else
    ok "All imports synced"
  fi
}

import_set_targets() {
  local targets="$1"
  _ensure_manifest

  _MANIFEST_PATH="$(_manifest_file)" _TARGETS="$targets" python3 -c "
import json, os

manifest_path = os.environ['_MANIFEST_PATH']
targets = os.environ['_TARGETS']

with open(manifest_path) as f:
    data = json.load(f)

data['targets'] = targets.split(',')

with open(manifest_path, 'w') as f:
    json.dump(data, f, indent=2)
"
  ok "Targets set: $targets"
}

import_list() {
  local source="${1:-}"

  if [ -z "$source" ]; then
    # List from all sources
    local names
    names=$(_SOURCES_FILE="$SOURCES_FILE" python3 -c "
import json, os
with open(os.environ['_SOURCES_FILE']) as f:
    data = json.load(f)
for s in data['sources']:
    print(s['name'])
")
    while IFS= read -r name; do
      [ -z "$name" ] && continue
      import_list "$name"
    done <<< "$names"
    return
  fi

  local src_dir
  src_dir="$(repo_dir "$source")" || { fail "Source '$source' not found"; return 1; }

  if [ ! -d "$src_dir" ]; then
    warn "Source '$source' not cloned yet. Run: skynet source sync $source"
    return 1
  fi

  printf "\n${BOLD}[$source] Skills:${RESET}\n"
  if [ -d "$src_dir/skills" ]; then
    for d in "$src_dir/skills"/*/; do
      [ -d "$d" ] || continue
      printf "  %s\n" "$(basename "$d")"
    done | sort | head -50
    local total
    total=$(find "$src_dir/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    printf "  ${CYAN}(%s total)${RESET}\n" "$total"
  else
    printf "  ${YELLOW}(none)${RESET}\n"
  fi

  printf "\n${BOLD}[$source] Agents:${RESET}\n"
  if [ -d "$src_dir/agents" ]; then
    for d in "$src_dir/agents"/*/; do
      [ -d "$d" ] || continue
      printf "  %s\n" "$(basename "$d")"
    done | sort | head -50
    local total
    total=$(find "$src_dir/agents" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    printf "  ${CYAN}(%s total)${RESET}\n" "$total"
  else
    printf "  ${YELLOW}(none)${RESET}\n"
  fi
}

import_search() {
  local query="$1"

  printf "\n${BOLD}Searching for '%s'...${RESET}\n" "$query"

  # Use index file if available for fast search
  local index_file="$CACHE_DIR/index.txt"
  if [ -f "$index_file" ]; then
    grep -i "$query" "$index_file" | while IFS= read -r line; do
      local type="${line%% *}"
      local rest="${line#* }"
      if [ "$type" = "skill" ]; then
        printf "  ${GREEN}%s${RESET}  %s\n" "$type" "$rest"
      else
        printf "  ${CYAN}%s${RESET}  %s\n" "$type" "$rest"
      fi
    done
    return
  fi

  # Fallback: scan directories (no index built yet)
  _QUERY="$query" _SOURCES_FILE="$SOURCES_FILE" _REPOS_DIR="$REPOS_DIR" python3 -c "
import json, os, re, sys

query = os.environ['_QUERY'].lower()
sources_file = os.environ['_SOURCES_FILE']
repos_dir = os.environ['_REPOS_DIR']

with open(sources_file) as f:
    sources = json.load(f)['sources']

for s in sources:
    name = s['name']
    repo_name = os.path.basename(s['repo'].rstrip('/').removesuffix('.git'))
    src_dir = os.path.join(repos_dir, repo_name)
    if not os.path.isdir(src_dir):
        continue

    for item_type in ['skills', 'agents']:
        type_dir = os.path.join(src_dir, item_type)
        if not os.path.isdir(type_dir):
            continue
        for entry in sorted(os.listdir(type_dir)):
            entry_path = os.path.join(type_dir, entry)
            if not os.path.isdir(entry_path):
                continue

            desc = ''
            skill_file = os.path.join(entry_path, 'SKILL.md')
            if os.path.isfile(skill_file):
                try:
                    with open(skill_file) as f:
                        text = f.read(2000)
                    m = re.search(r'^description:\s*[\"\']*(.+?)[\"\']*\s*$', text, re.MULTILINE)
                    if m:
                        desc = m.group(1)[:80]
                except:
                    pass

            searchable = f'{entry} {desc}'.lower()
            if query in searchable:
                label = 'skill' if item_type == 'skills' else 'agent'
                if desc:
                    print(f'{label}|{name}:{entry}|{desc}')
                else:
                    print(f'{label}|{name}:{entry}|')
" | while IFS='|' read -r type ref desc; do
    if [ "$type" = "skill" ]; then
      if [ -n "$desc" ]; then
        printf "  ${GREEN}%s${RESET}  %s — %s\n" "$type" "$ref" "$desc"
      else
        printf "  ${GREEN}%s${RESET}  %s\n" "$type" "$ref"
      fi
    else
      if [ -n "$desc" ]; then
        printf "  ${CYAN}%s${RESET}  %s — %s\n" "$type" "$ref" "$desc"
      else
        printf "  ${CYAN}%s${RESET}  %s\n" "$type" "$ref"
      fi
    fi
  done
}

# Build compact index of all skills/agents
# Output: ~/.claude/skills-cache/index.txt
import_build_index() {
  local index_file="$CACHE_DIR/index.txt"
  _ensure_cache

  info "Building skill index..."

  _SOURCES_FILE="$SOURCES_FILE" _REPOS_DIR="$REPOS_DIR" _INDEX_FILE="$index_file" python3 -c "
import json, os, re

sources_file = os.environ['_SOURCES_FILE']
repos_dir = os.environ['_REPOS_DIR']
index_file = os.environ['_INDEX_FILE']

with open(sources_file) as f:
    sources = json.load(f)['sources']

lines = []
for s in sources:
    name = s['name']
    repo_name = os.path.basename(s['repo'].rstrip('/').removesuffix('.git'))
    src_dir = os.path.join(repos_dir, repo_name)
    if not os.path.isdir(src_dir):
        continue

    for item_type in ['skills', 'agents']:
        type_dir = os.path.join(src_dir, item_type)
        if not os.path.isdir(type_dir):
            continue
        label = 'skill' if item_type == 'skills' else 'agent'
        for entry in sorted(os.listdir(type_dir)):
            entry_path = os.path.join(type_dir, entry)
            if not os.path.isdir(entry_path):
                continue
            desc = ''
            skill_file = os.path.join(entry_path, 'SKILL.md')
            if os.path.isfile(skill_file):
                try:
                    with open(skill_file) as f:
                        text = f.read(2000)
                    m = re.search(r'^description:\s*[\"\']*(.+?)[\"\']*\s*$', text, re.MULTILINE)
                    if m:
                        desc = m.group(1)[:80]
                except:
                    pass
            if desc:
                lines.append(f'{label}  {name}:{entry} — {desc}')
            else:
                lines.append(f'{label}  {name}:{entry}')

with open(index_file, 'w') as f:
    f.write('\n'.join(lines) + '\n')

print(len(lines))
"
  local count
  count=$(wc -l < "$index_file" | tr -d ' ')
  ok "Index built: $count entries → $index_file"
}
