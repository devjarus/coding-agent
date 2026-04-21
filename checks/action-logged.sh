#!/usr/bin/env bash
# action-logged — invariant check. Verifies every Orchestrator-significant
# action since session start has a corresponding line in session.md action log.
# Usage: ./checks/action-logged.sh [repo_root] [expected_event]
# expected_event = the most recent event the orchestrator claims to have logged
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

NAME="action-logged"
REPO="${1:-$PWD}"
EXPECTED="${2:-}"

SESSION="$REPO/.coding-agent/session.md"
[[ -f "$SESSION" ]] || { emit_fail "$NAME" "session.md missing"; exit 1; }

# session.md must have an "## Action Log" section
if ! grep -qF "## Action Log" "$SESSION"; then
  emit_fail "$NAME" "session.md missing ## Action Log section"
  exit 1
fi

# If a specific event was expected, verify it's the latest
if [[ -n "$EXPECTED" ]]; then
  last=$(awk '/^## Action Log/{found=1; next} found && NF>0' "$SESSION" | tail -1)
  if [[ "$last" != *"$EXPECTED"* ]]; then
    emit_fail "$NAME" "expected '$EXPECTED' as latest log entry; got: $last"
    exit 1
  fi
fi

emit_pass "$NAME"
