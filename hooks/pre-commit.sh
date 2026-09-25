#!/usr/bin/env bash
# Git pre-commit gate (installed as a shim by ca_install_commit_gate). While a
# feature is active, a commit must not land past an unmet gate: this runs the
# pre-commit prefix of the arc — framed? architected? designed? proven?
# reviewed? clean? — and refuses the commit at the first block.
#
# It is the mechanical backstop for the conductor's "never commit past a gate"
# rule, and it also catches commits whose message never claims anything. With no
# active feature it is a no-op, so ordinary commits in the repo are untouched.
# A human who deliberately commits outside the loop can use `git commit --no-verify`;
# agents must not.
set -uo pipefail
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PLUGIN_ROOT/gates/lib.sh"

slug="$(ca_current)"
[ -n "$slug" ] && [ -f "$(ca_ledger)" ] || exit 0

for g in framed architected designed proven reviewed clean; do
  out="$(bash "$PLUGIN_ROOT/gates/$g.sh" 2>/dev/null)" && continue
  reason="$(printf '%s\n' "$out" | head -1 \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("reason",""))' 2>/dev/null || printf '%s' "$out")"
  {
    echo "✗ coding-agent: commit blocked — $g? has not passed for feature '$slug'"
    echo "  $reason"
    echo "  Clear the gate, then commit. (A human committing outside the loop: git commit --no-verify)"
  } >&2
  exit 1
done
exit 0
