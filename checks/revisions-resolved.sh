#!/usr/bin/env bash
# revisions-resolved — work.md has no `Status: pending` Plan Revisions.
# Blocks dispatch of next wave when a pending revision exists.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

NAME="revisions-resolved"
REPO="${1:-$PWD}"
DIR=$(resolve_feature_dir "$REPO")
[[ -z "$DIR" ]] && { emit_pass "$NAME"; exit 0; }

WORK="$DIR/work.md"
[[ -f "$WORK" ]] || { emit_pass "$NAME"; exit 0; }

if grep -qE '^Status:[[:space:]]+pending' "$WORK"; then
  emit_fail "$NAME" "work.md has unresolved 'Status: pending' revision"
  exit 1
fi

emit_pass "$NAME"
