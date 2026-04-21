#!/usr/bin/env bash
# intent-approved — features/<CURRENT>/intent.md exists and has approved_by: user.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

NAME="intent-approved"
REPO="${1:-$PWD}"
DIR=$(resolve_feature_dir "$REPO")
[[ -z "$DIR" ]] && { emit_fail "$NAME" "no active feature (CURRENT empty)"; exit 1; }

INTENT="$DIR/intent.md"
[[ -f "$INTENT" ]] || { emit_fail "$NAME" "intent.md missing"; exit 1; }

approved_by=$(read_fm "$INTENT" "approved_by")
if [[ "$approved_by" != "user" ]]; then
  emit_fail "$NAME" "intent.md not approved by user (approved_by=$approved_by)"
  exit 1
fi

emit_pass "$NAME"
