#!/usr/bin/env bash
# Shared helpers for check scripts. Sourced, not executed.

set -uo pipefail

# Resolve the active feature directory from .coding-agent/CURRENT.
# Echoes the absolute path or empty string if no active feature.
resolve_feature_dir() {
  local repo_root="${1:-$PWD}"
  local current_file="$repo_root/.coding-agent/CURRENT"
  [[ -f "$current_file" ]] || { echo ""; return 0; }
  local slug
  slug=$(tr -d '[:space:]' < "$current_file")
  [[ -z "$slug" ]] && { echo ""; return 0; }
  echo "$repo_root/.coding-agent/features/$slug"
}

# Read a frontmatter field from a markdown file.
# Usage: read_fm <file> <field>
# Echoes the value or empty.
read_fm() {
  local file="$1" field="$2"
  [[ -f "$file" ]] || return 1
  awk -v f="$field" '
    /^---$/ { in_fm = !in_fm; next }
    in_fm && $0 ~ "^"f":" {
      sub("^"f":[[:space:]]*", "")
      print
      exit
    }
  ' "$file"
}

# Standard check output: pass/fail with reason, JSON-friendly.
emit_pass() {
  local name="$1"
  printf '{"check":"%s","ok":true}\n' "$name"
}

emit_fail() {
  local name="$1" reason="$2"
  printf '{"check":"%s","ok":false,"reason":%s}\n' "$name" "$(printf '%s' "$reason" | jq -Rs .)"
}

# Detect if the project has a UI (web or iOS).
# Echoes "web", "ios", or "" (none).
detect_ui() {
  local repo_root="${1:-$PWD}"
  if [[ -f "$repo_root/package.json" ]] && grep -qE '"(react|vue|svelte|next|nuxt|@angular/core|astro|solid-js|preact|lit)"' "$repo_root/package.json" 2>/dev/null; then
    echo "web"
    return 0
  fi
  for dir in client web frontend apps/web packages/web; do
    [[ -d "$repo_root/$dir" ]] && { echo "web"; return 0; }
  done
  if ls "$repo_root"/*.xcodeproj "$repo_root"/*.xcworkspace 2>/dev/null | head -1 >/dev/null; then
    echo "ios"
    return 0
  fi
  echo ""
}
