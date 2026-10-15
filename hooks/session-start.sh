#!/usr/bin/env bash
# SessionStart hook — three jobs:
#   1. Data safety: make sure `.coding-agent/` is gitignored BEFORE anything
#      writes there. An un-ignored ledger gets swept into a `git add` and then
#      erased by a later `git reset --hard` / `git clean`, taking the intent,
#      the evidence and the audit trail with it. This preflight is non-skippable.
#   2. Refresh the git pre-commit gate in projects already using the runtime.
#   3. Inject the agreed conventions (every session, bounded) and resume state,
#      so a fresh context re-enters the loop at the first unmet gate, including
#      any interrupted feature stack.
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

# --- 2. refresh the commit gate where the runtime is in use ----------------
# ledger.sh init installs it; re-installing here re-points the shim at this
# plugin copy after an update. Projects that never opened a ledger are untouched.
gate_note=""
if [ -d "$ca" ]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/gates/lib.sh"
  st="$(cd "$root" && ca_install_commit_gate)"
  case "$st" in skipped:*) gate_note="commit gate not installed (${st#skipped: }) — run gates before every commit yourself" ;; esac
fi

# --- 3. conventions + resume state ------------------------------------------
emit() { printf '%s' "$1" | python3 -c \
  'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":sys.stdin.read()}}))'; exit 0; }
# The agreed conventions are the one part of product memory every session
# needs before it writes code, so they are injected even with no active
# feature. Bounded: one line per rule, capped at 3 KB.
conv="$(ledger_section "$ca/product.md" conventions 2>/dev/null | strip_comments | grep '^- ' | head -c 3000)"
[ -n "$conv" ] && conv="coding-agent — agreed conventions (each enforced by its test; only the user's words change one):"$'\n'"$conv"
[ -n "$gate_note" ] && conv="${conv:+$conv$'\n'}coding-agent: $gate_note"
[ -f "$ca/CURRENT" ] || { [ -n "$conv" ] && emit "$conv"; printf '{}\n'; exit 0; }
# CURRENT is a stack: the LAST line is the active feature; earlier lines are
# features it interrupted (ledger.sh init pushes, close pops).
slug="$(grep -v '^[[:space:]]*$' "$ca/CURRENT" 2>/dev/null | tail -1 | tr -d '[:space:]')"
ledger="$ca/$slug/ledger.md"
# Inject only for a genuine feature ledger at `.coding-agent/<slug>/`.
# No ledger means there is nothing to resume, so the hook stays silent.
[ -n "$slug" ] && [ -f "$ledger" ] || { [ -n "$conv" ] && emit "$conv"; printf '{}\n'; exit 0; }

ctx="coding-agent — active feature: $slug"
paused="$(grep -v '^[[:space:]]*$' "$ca/CURRENT" | sed '$d' | tr '\n' ' ')"
[ -n "$paused" ] && ctx="$ctx"$'\n'"interrupted, resume after close: $paused"
[ -n "$conv" ] && ctx="$ctx"$'\n\n'"$conv"
ctx="$ctx"$'\n\n'"$(tail -n 24 "$ledger")"
emit "$ctx"
