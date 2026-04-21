#!/usr/bin/env bash
# active-feature-consistent — CURRENT is empty OR points to a feature dir
# whose artifacts are in active/draft state. If it points to a fully-archived
# dir, that's a stale CURRENT (close-out failed to clear) — orchestrator
# should self-repair by clearing CURRENT.
#
# Usage: ./checks/active-feature-consistent.sh [repo_root]
# Exits 0 if ok, 1 if not. Emits JSON to stdout.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

NAME="active-feature-consistent"
REPO="${1:-$PWD}"
CURRENT_FILE="$REPO/.coding-agent/CURRENT"

if [[ ! -f "$CURRENT_FILE" ]]; then
  emit_pass "$NAME"; exit 0
fi

slug=$(tr -d '[:space:]' < "$CURRENT_FILE")
if [[ -z "$slug" ]]; then
  emit_pass "$NAME"; exit 0
fi

feature_dir="$REPO/.coding-agent/features/$slug"
if [[ ! -d "$feature_dir" ]]; then
  emit_fail "$NAME" "CURRENT points to '$slug' but features/$slug/ does not exist"
  exit 1
fi

# Check whether at least one artifact in the dir is non-archived.
# If everything is archived, CURRENT is stale.
non_archived=0
while IFS= read -r -d '' file; do
  state=$(read_fm "$file" "state")
  if [[ "$state" != "archived" && -n "$state" ]]; then
    non_archived=1
    break
  fi
done < <(find "$feature_dir" -maxdepth 1 -name "*.md" -print0)

if [[ "$non_archived" -eq 0 ]]; then
  emit_fail "$NAME" "CURRENT='$slug' but all artifacts are archived; close-out should have cleared CURRENT"
  exit 1
fi

emit_pass "$NAME"
