#!/usr/bin/env bash
# 04-recovery driver — phase A is killed mid-arc (--max-turns), phase B is a
# FRESH session told only to resume. Tests the resume-as-property claim: the
# ledger + gates alone must carry the state across the session boundary.
set -uo pipefail
command -v claude >/dev/null 2>&1 || { echo "claude CLI not found"; exit 1; }
margs=()
[ -n "${EV_MODEL:-}" ] && margs+=(--model "$EV_MODEL")

# phase A: start the arc, die early (turn budget forces mid-flight death)
claude -p "$(cat "$EV_RENDERED_PROMPT")" \
  --permission-mode bypassPermissions --output-format json --max-turns 8 \
  "${margs[@]+"${margs[@]}"}" \
  > "$EV_RESULT_DIR/claude-output.json" 2> "$EV_RESULT_DIR/claude-stderr.log" || true

# capture what phase A left behind, so asserts can prove phase B built on it
cp .coding-agent/*/ledger.md "$EV_RESULT_DIR/ledger-after-phase-a.md" 2>/dev/null || true

# phase B: fresh session, resume-only instruction — no task restatement
claude -p "You are the conductor defined at $EV_PLUGIN_ROOT/agents/conductor.md.
A previous session on this project died mid-feature. Re-enter your loop at
step 1 (read the ledger tail + evidence), find the first unmet gate, and finish
the feature. Eval-mode: intent agreement and commit are pre-approved; work
until the feature is closed. Do NOT start a new feature ledger — resume the
existing one." \
  --permission-mode bypassPermissions --output-format json \
  "${margs[@]+"${margs[@]}"}" \
  > "$EV_RESULT_DIR/claude-output-phase2.json" 2>> "$EV_RESULT_DIR/claude-stderr.log" || true
