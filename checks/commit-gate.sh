#!/usr/bin/env bash
# commit-gate.sh — one serialized commit gate. Runs the deterministic commit
# checks IN ORDER and stops at the first failure, so the orchestrator calls ONE
# tool instead of hand-batching a verify → scan → tests dependency chain (the
# exact place it once parallel-batched and advanced on an uninspected result).
#
# Order (each blocks):
#   1. review-passed            — evaluator wrote review.md Status: PASS
#   2. tests-actually-committed — working tree has real source changes (commit mode)
#   3. no-secrets-staged        — no .env / keys / tokens staged
#   4. last-verify green        — .coding-agent/last-verify.json exit 0 (if present)
#
# This GATES; it does not commit. The orchestrator still shows the diff, gets
# user approval, and runs `git commit` (with the message) after this returns ok.
#
# Usage: commit-gate.sh <repo_root> <slug> [--allow-secrets]
#   --allow-secrets  skip step 3 ONLY for the explicit user override at the gate
#                    ("commit anyway — fixture/intentional"). Never a default.
#
# Exit 0 + {"ok":true,"passed":[...]}              every gate passes.
# Exit 1 + {"ok":false,"failed":"<name>","reason"} at the first failure.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

NAME="commit-gate"
REPO="${1:-$PWD}"
SLUG="${2:-}"
ALLOW_SECRETS=0
[[ "${3:-}" == "--allow-secrets" ]] && ALLOW_SECRETS=1

# Run a sub-check; on failure, surface its reason and exit immediately.
gate() {
  local label="$1"; shift
  local out rc reason
  out="$("$@" 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]]; then
    reason="$(printf '%s' "$out" | jq -r '.reason // empty' 2>/dev/null)"
    [[ -z "$reason" ]] && reason="$out"
    printf '{"check":"%s","ok":false,"failed":"%s","reason":%s}\n' \
      "$NAME" "$label" "$(printf '%s' "$reason" | jq -Rs .)"
    exit 1
  fi
}

passed=()
gate "review-passed"            bash "$SCRIPT_DIR/review-passed.sh" "$REPO" "$SLUG"
passed+=("review-passed")
gate "tests-actually-committed" bash "$SCRIPT_DIR/tests-actually-committed.sh" "$REPO" commit
passed+=("tests-actually-committed")
if [[ $ALLOW_SECRETS -eq 0 ]]; then
  gate "no-secrets-staged"      bash "$SCRIPT_DIR/no-secrets-staged.sh" "$REPO"
  passed+=("no-secrets-staged")
else
  passed+=("no-secrets-staged:overridden")
fi

# last-verify must be green if present (run-and-record should run before the gate)
VF="$REPO/.coding-agent/last-verify.json"
if [[ -f "$VF" ]] && command -v jq >/dev/null 2>&1; then
  vok="$(jq -r '.ok // false' "$VF" 2>/dev/null)"
  if [[ "$vok" != "true" ]]; then
    printf '{"check":"%s","ok":false,"failed":"last-verify","reason":"last-verify.json is red — verification did not pass; re-run run-and-record.sh"}\n' "$NAME"
    exit 1
  fi
  passed+=("last-verify")
fi

printf '{"check":"%s","ok":true,"passed":%s}\n' \
  "$NAME" "$(printf '%s\n' "${passed[@]}" | jq -R . | jq -sc .)"
exit 0
