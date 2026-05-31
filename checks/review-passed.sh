#!/usr/bin/env bash
# review-passed — the commit gate requires a real evaluator verdict.
#
# close-out.md declares "Entry: review.md Status: PASS", but that was only prose.
# This makes it deterministic: a commit cannot proceed unless the evaluator wrote
# a review.md whose `## Status` is PASS. Since review.md is the evaluator's
# artifact (a different actor that runs the real build + test suite), this blocks
# the orchestrator from self-certifying a wave with its own typecheck shortcut —
# the exact failure where `tsc -b` "passed" while the build was broken.
#
# Usage: review-passed.sh <repo_root> [<slug>]
#   slug is explicit because the commit gate runs after close-out clears CURRENT;
#   falls back to CURRENT when not given (close-out-entry use).
# Exit 0 + {"ok":true} when review.md Status is PASS. Exit 1 otherwise.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

NAME="review-passed"
REPO="${1:-$PWD}"
SLUG="${2:-}"

if [[ -n "$SLUG" ]]; then
  DIR="$REPO/.coding-agent/features/$SLUG"
else
  DIR=$(resolve_feature_dir "$REPO")
fi
[[ -n "$DIR" && -d "$DIR" ]] || { emit_fail "$NAME" "no feature dir resolved — pass <repo> <slug>"; exit 1; }

REVIEW="$DIR/review.md"
[[ -f "$REVIEW" ]] || { emit_fail "$NAME" "review.md missing — no evaluator review exists. A commit requires a passing review (build + tests run by the evaluator), not the orchestrator's own check."; exit 1; }

# Read the value of the ## Status section. Accept canonical form
# ("## Status\nPASS") and inline form ("## Status: PASS"). The unfilled template
# value "PASS | FAIL" must NOT pass — only an exact PASS verdict counts.
status=$(awk '
  /^##[[:space:]]+Status[[:space:]]*:/ { line=$0; sub(/^[^:]*:[[:space:]]*/,"",line); print line; exit }
  /^##[[:space:]]+Status[[:space:]]*$/ { f=1; next }
  f && NF { print; exit }
' "$REVIEW" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

status_uc=$(printf '%s' "$status" | tr '[:lower:]' '[:upper:]')

if [[ "$status_uc" == "PASS" ]]; then
  emit_pass "$NAME"
  exit 0
fi

if [[ -z "$status" ]]; then
  emit_fail "$NAME" "review.md has no ## Status verdict"
else
  emit_fail "$NAME" "review.md Status is '$status' (not PASS) — fix the findings and re-review before commit"
fi
exit 1
