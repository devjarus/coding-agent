#!/usr/bin/env bash
# clean? — the staged diff carries no obvious secrets and no raw debug prints.
# Applies when a commit is imminent.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
GATE_NAME=clean
diff="$(git diff --cached 2>/dev/null || true)"
[ -n "$diff" ] || gate_result n/a "nothing staged"
if echo "$diff" | grep -Eiq '^\+.*(api[_-]?key|secret|password|passwd|token|private[_-]?key)["'"'"' ]*[:=]'; then
  gate_result block "possible secret in staged diff"
fi
if echo "$diff" | grep -Eq '^\+[[:space:]]*(console\.log|print\(|fmt\.Println|debugger|binding\.pry)'; then
  gate_result block "raw debug print in staged diff"
fi
gate_result pass "no secrets or debug prints staged"
