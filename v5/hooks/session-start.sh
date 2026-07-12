#!/usr/bin/env bash
# SessionStart hook — inject resume state so a fresh context re-enters the loop
# at the first unmet gate (design doc §4.1). Reads the active feature + ledger tail.
set -uo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ca="$root/.coding-agent"
[ -f "$ca/CURRENT" ] || { printf '{}\n'; exit 0; }
slug="$(tr -d '[:space:]' < "$ca/CURRENT")"
ledger="$ca/$slug/ledger.md"
# Inject only for a genuine v5 feature. v5 keeps ledgers at .coding-agent/<slug>/;
# v4 uses .coding-agent/features/<slug>/ and shares the same CURRENT file, so
# without this guard a v4 project would get a bogus v5 banner. No v5 ledger → no-op.
[ -n "$slug" ] && [ -f "$ledger" ] || { printf '{}\n'; exit 0; }
ctx="coding-agent v5 — active feature: $slug"$'\n\n'"$(tail -n 24 "$ledger")"
printf '%s' "$ctx" | python3 -c \
  'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":sys.stdin.read()}}))'
