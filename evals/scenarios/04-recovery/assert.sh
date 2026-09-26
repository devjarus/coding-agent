#!/usr/bin/env bash
# 04-recovery — after a mid-arc session death, a fresh session must finish the
# SAME feature from the ledger: one feature dir, one intent, completed arc.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" && pwd)/lib.sh"

# exactly one feature (phase B resumed; it did not re-init a second ledger)
ev_assert "exactly one feature dir" sh -c '
  n=$(ls -d .coding-agent/*/ 2>/dev/null | grep -v abandoned | wc -l | tr -d " ")
  echo "feature dirs: $n"; test "$n" -eq 1'
ev_assert "single intent freeze history"       sh -c 'test "$(grep -c "^## intent" "$(ls .coding-agent/*/ledger.md | head -1)")" -eq 1'

# the arc completed across the boundary
ev_assert "deliverable exists"                 test -f count.sh
ev_assert "green test at final tree"           ev_evidence_has test 0 "$(ev_tree_sha)"
ev_assert "review verdict recorded"            ev_evidence_has review 0
ev_assert "feature closed (CURRENT empty)"     test -z "$(ev_current)"
ev_assert "rolled up into product.md"          grep -qE '^### .+ — (shipped|closed) @' "$(ev_product)"
ev_assert "evidence well-formed"               ev_evidence_wellformed

ev_assert "coordinator state never committed"  ev_state_never_committed

ev_summary
