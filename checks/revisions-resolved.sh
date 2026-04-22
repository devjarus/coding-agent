#!/usr/bin/env bash
# revisions-resolved — work.md has no pending Plan Revisions.
# Blocks dispatch of next wave when a pending revision exists.
#
# Matches any common status-line formatting:
#   Status: pending                          (bare)
#   - Status: pending user decision          (bulleted, prose detail)
#   - **Status:** pending                    (bulleted + markdown bold)
#   **Status**: pending                      (bold key, colon outside)
# The regex strips markdown bold markers first, then matches.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

NAME="revisions-resolved"
REPO="${1:-$PWD}"
DIR=$(resolve_feature_dir "$REPO")
[[ -z "$DIR" ]] && { emit_pass "$NAME"; exit 0; }

WORK="$DIR/work.md"
[[ -f "$WORK" ]] || { emit_pass "$NAME"; exit 0; }

# Strip **bold** markers, then grep for any line matching Status: pending.
# Works for bulleted + bold + prose-detail variants.
if sed 's/\*\*//g' "$WORK" | grep -qE '^[[:space:]]*[-*]?[[:space:]]*Status:[[:space:]]+pending\b'; then
  emit_fail "$NAME" "work.md has unresolved 'Status: pending' revision"
  exit 1
fi

emit_pass "$NAME"
