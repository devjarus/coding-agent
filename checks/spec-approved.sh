#!/usr/bin/env bash
# spec-approved — features/<CURRENT>/spec.md is approved by user AND
# contains required sections: ## Tech Stack, ## Test Infrastructure, ## Requirements.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

NAME="spec-approved"
REPO="${1:-$PWD}"
DIR=$(resolve_feature_dir "$REPO")
[[ -z "$DIR" ]] && { emit_fail "$NAME" "no active feature"; exit 1; }

SPEC="$DIR/spec.md"
[[ -f "$SPEC" ]] || { emit_fail "$NAME" "spec.md missing"; exit 1; }

approved_by=$(read_fm "$SPEC" "approved_by")
[[ "$approved_by" == "user" ]] || { emit_fail "$NAME" "not approved by user"; exit 1; }

for section in "## Tech Stack" "## Test Infrastructure" "## Requirements"; do
  grep -qF "$section" "$SPEC" || { emit_fail "$NAME" "missing required section: $section"; exit 1; }
done

emit_pass "$NAME"
