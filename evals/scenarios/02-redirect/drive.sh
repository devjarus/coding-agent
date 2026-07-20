#!/usr/bin/env bash
# 02-redirect driver — two phases: build the feature, then change the
# requirement mid-feature. Tests that the conductor uses the redirect
# mechanics (ledger.sh revise → re-freeze) instead of hand-editing history.
set -uo pipefail
command -v claude >/dev/null 2>&1 || { echo "claude CLI not found"; exit 1; }
margs=()
[ -n "${EV_MODEL:-}" ] && margs+=(--model "$EV_MODEL")

# phase 1: the original feature
claude -p "$(cat "$EV_RENDERED_PROMPT")" \
  --permission-mode bypassPermissions --output-format json \
  "${margs[@]+"${margs[@]}"}" \
  > "$EV_RESULT_DIR/claude-output.json" 2> "$EV_RESULT_DIR/claude-stderr.log" || true

# phase 2: the requirement changes (fresh session, resumes from the ledger)
claude -p "You are the conductor defined at $EV_PLUGIN_ROOT/v5/agents/conductor.md — a prior session worked this project; re-enter your loop from the ledger (step 1).

REQUIREMENT CHANGE (from the user): greet.sh must now print 'hello <name>!' with a trailing exclamation mark. This changes the agreed intent — handle it per your Requirements-shift / redirect rules (ledger.sh revise, then re-freeze; eval-mode: treat this message as the user's re-agreement). Update the code and test, get proven?/reviewed? green again, commit, then close the feature." \
  --permission-mode bypassPermissions --output-format json \
  "${margs[@]+"${margs[@]}"}" \
  > "$EV_RESULT_DIR/claude-output-phase2.json" 2>> "$EV_RESULT_DIR/claude-stderr.log" || true
