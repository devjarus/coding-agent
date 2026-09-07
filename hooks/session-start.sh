#!/usr/bin/env bash
# SessionStart hook — two jobs:
#   1. Data safety: make sure `.coding-agent/` is gitignored BEFORE anything
#      writes there. An un-ignored ledger gets swept into a `git add` and then
#      erased by a later `git reset --hard` / `git clean`, taking the intent,
#      the evidence and the audit trail with it. This preflight is non-skippable.
#   2. Inject resume state so a fresh context re-enters the loop at the first
#      unmet gate (design doc §4.1), including any interrupted feature stack.
set -uo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ca="$root/.coding-agent"

# --- 1. gitignore preflight (runs even with no active feature) ---------------
if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
  gi="$root/.gitignore"
  if ! grep -qE '^\.coding-agent/?$' "$gi" 2>/dev/null; then
    { [ -s "$gi" ] && [ -n "$(tail -c1 "$gi" 2>/dev/null)" ] && echo
      echo "# coding-agent runtime state — never track"
      echo ".coding-agent/"; } >> "$gi"
  fi
fi

# --- 2. resume state --------------------------------------------------------
[ -f "$ca/CURRENT" ] || { printf '{}\n'; exit 0; }
# CURRENT is a stack: the LAST line is the active feature; earlier lines are
# features it interrupted (ledger.sh init pushes, close pops).
slug="$(grep -v '^[[:space:]]*$' "$ca/CURRENT" 2>/dev/null | tail -1 | tr -d '[:space:]')"
ledger="$ca/$slug/ledger.md"
# Inject only for a genuine feature ledger at `.coding-agent/<slug>/`.
# No ledger means there is nothing to resume, so the hook stays silent.
[ -n "$slug" ] && [ -f "$ledger" ] || { printf '{}\n'; exit 0; }

ctx="coding-agent — active feature: $slug"
paused="$(grep -v '^[[:space:]]*$' "$ca/CURRENT" | sed '$d' | tr '\n' ' ')"
[ -n "$paused" ] && ctx="$ctx"$'\n'"interrupted, resume after close: $paused"
ctx="$ctx"$'\n\n'"$(tail -n 24 "$ledger")"
printf '%s' "$ctx" | python3 -c \
  'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":sys.stdin.read()}}))'
