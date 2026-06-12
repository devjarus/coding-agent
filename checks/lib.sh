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

# sha256 of a file's bytes (matches design-review-server.py's hashing).
# Echoes the hex digest, or empty if the file is missing / no hasher found.
sha256_file() {
  local file="$1"
  [[ -f "$file" ]] || { echo ""; return 0; }
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | cut -d' ' -f1
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | cut -d' ' -f1
  else
    echo ""
  fi
}

# Validate a sha-bound design-review verdict for one artifact.
# Usage: verify_design_verdict <feature_dir> <artifact_file> <verdict_key>
#   e.g. verify_design_verdict "$DIR" spec.md spec_sha
# Echoes "" when valid (or when no verdict file exists — legacy chat-approval
# path), else a human-readable failure reason. Requires jq for parsing; if jq
# is absent the verdict is treated as legacy (degrade open, like commit-msg).
verify_design_verdict() {
  local dir="$1" artifact="$2" key="$3"
  local vfile="$dir/design-verdict.json"
  [[ -f "$vfile" ]] || { echo ""; return 0; }
  command -v jq >/dev/null 2>&1 || { echo ""; return 0; }
  local verdict recorded actual
  verdict=$(jq -r '.verdict // empty' "$vfile" 2>/dev/null)
  if [[ "$verdict" != "approved" ]]; then
    echo "design-verdict.json says '$verdict' — changes were requested in the review surface, not approved"
    return 0
  fi
  recorded=$(jq -r ".$key // empty" "$vfile" 2>/dev/null)
  [[ -z "$recorded" ]] && { echo ""; return 0; }   # artifact didn't exist at verdict time
  actual=$(sha256_file "$dir/$artifact")
  [[ -z "$actual" ]] && { echo ""; return 0; }     # no hasher available — degrade open
  if [[ "$recorded" != "$actual" ]]; then
    echo "$artifact changed AFTER the sha-bound approval (verdict ${recorded:0:8}, current ${actual:0:8}) — re-run the design review"
  else
    echo ""
  fi
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
