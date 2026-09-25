#!/usr/bin/env bash
# clean? — the staged diff carries no coordinator state, no obvious secrets, and
# no raw debug prints. Applies when a commit is imminent.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
GATE_NAME=clean
diff="$(git diff --cached 2>/dev/null || true)"
[ -n "$diff" ] || gate_result n/a "nothing staged"
# .coding-agent/ is gitignored, but `git add -f` or an explicit path still stages
# it. Tracked coordinator state is erased by the next `git reset --hard` /
# `git clean`, taking the ledger and evidence with it — never let it through.
staged_state="$(git diff --cached --name-only 2>/dev/null | grep -E '(^|/)\.coding-agent/' | head -3 | tr '\n' ' ')"
[ -z "$staged_state" ] \
  || gate_result block "coordinator state is staged (${staged_state% }) — git restore --staged .coding-agent"
if echo "$diff" | grep -Eiq '^\+.*(api[_-]?key|secret|password|passwd|token|private[_-]?key)["'"'"' ]*[:=]'; then
  gate_result block "possible secret in staged diff"
fi
if echo "$diff" | grep -Eq '^\+[[:space:]]*(console\.log|print\(|fmt\.Println|debugger|binding\.pry)'; then
  gate_result block "raw debug print in staged diff"
fi
gate_result pass "no coordinator state, secrets, or debug prints staged"
