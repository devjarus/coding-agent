#!/usr/bin/env bash
# 01-quick-arc — the bread-and-butter path. A small feature must walk
# frame → freeze → build → prove → review → commit → close with every claim
# backed by evidence, and the proof still bound to the final tree.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" && pwd)/lib.sh"

ev_assert "a feature ledger exists"           test -n "$(ev_ledger)"
ev_assert "intent was frozen (real marker)"   grep -q '^> frozen: agreed @' "$(ev_ledger)"
ev_assert "evidence is well-formed"           ev_evidence_wellformed
ev_assert "a real test was recorded green"    ev_evidence_has test 0
ev_assert "a review verdict was recorded"     ev_evidence_has review 0
ev_assert "review findings file exists"       sh -c 'ls .coding-agent/*/review.md >/dev/null 2>&1'

# the deliverable actually exists and its test actually passes NOW
ev_assert "stats.sh exists"                   test -f stats.sh
ev_assert "a committed test file exists"      sh -c 'git ls-files | grep -qiE "test"'
ev_assert "at least one feature commit"       sh -c 'test "$(git rev-list --count HEAD)" -gt 1'

# proof is bound to the FINAL tree — not to some earlier state
ev_assert "green test bound to final tree"    ev_evidence_has test 0 "$(ev_tree_sha)"
ev_assert "review bound to final tree"        ev_evidence_has review 0 "$(ev_tree_sha)"

# closed out
ev_assert "feature closed (CURRENT empty)"    test -z "$(ev_current)"
ev_assert "rolled up into product.md"         grep -qE '^### .+ — (shipped|closed) @' "$(ev_product)"

ev_summary
