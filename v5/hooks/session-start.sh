#!/usr/bin/env bash
# SessionStart hook — inject resume state so a fresh context re-enters the loop
# at the first unmet gate (design doc §4.1). Reads the active feature + ledger tail.
set -uo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ca="$root/.coding-agent"
[ -f "$ca/CURRENT" ] || { printf '{}\n'; exit 0; }
slug="$(tr -d '[:space:]' < "$ca/CURRENT")"
ledger="$ca/$slug/ledger.md"
ctx="coding-agent v5 — active feature: $slug"
[ -f "$ledger" ] && ctx="$ctx"$'\n\n'"$(tail -n 24 "$ledger")"
printf '%s' "$ctx" | python3 -c \
  'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":sys.stdin.read()}}))'
