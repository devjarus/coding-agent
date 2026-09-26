#!/usr/bin/env bash
# 02-redirect — a mid-feature requirement change must go through the redirect
# mechanics: a `> revision @` marker re-opening framed?, then a LATER re-freeze.
# History stays append-only; the final code reflects the new requirement.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" && pwd)/lib.sh"

ev_assert "a feature ledger exists"            test -n "$(ev_ledger)"
ev_assert "revision marker recorded"           grep -q '^> revision @' "$(ev_ledger)"
# a freeze must come AFTER the revision (first-match ordering would compare the
# original freeze, which always precedes the revision)
ev_assert "revision precedes a re-freeze"      sh -c '
  l="$(ls .coding-agent/*/ledger.md | head -1)"
  r=$(grep -n "^> revision @" "$l" | head -1 | cut -d: -f1)
  f=$(grep -n "^> frozen: agreed @" "$l" | tail -1 | cut -d: -f1)
  [ -n "$r" ] && [ -n "$f" ] && [ "$f" -gt "$r" ] && echo "revision@$r < re-freeze@$f"'

# the LAST agreement marker must be a freeze (re-agreed), not a dangling revision
last_marker() { grep -E '^> (frozen: agreed|revision) @' "$(ev_ledger)" | tail -1; }
ev_assert "last marker is a freeze"            sh -c '[ -n "$(grep -E "^> (frozen: agreed|revision) @" "'"$(ev_ledger)"'" | tail -1 | grep "frozen: agreed")" ]'

# both freeze events exist (original + re-agreement) — append-only history
ev_assert "two freeze stamps (append-only)"    sh -c 'test "$(grep -c "^> frozen: agreed @" "'"$(ev_ledger)"'")" -ge 2'

# the new requirement actually landed
ev_assert "greet.sh exists"                    test -f greet.sh
ev_assert "new requirement in behavior"        sh -c 'bash greet.sh world 2>/dev/null | grep -q "hello world!"'
ev_assert "green test at final tree"           ev_evidence_has test 0 "$(ev_tree_sha)"

ev_assert "coordinator state never committed"  ev_state_never_committed

ev_summary
