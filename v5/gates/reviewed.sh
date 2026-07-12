#!/usr/bin/env bash
# reviewed? — the qualitative-review gate. Exit codes catch breakage; this gate
# catches wrong-but-green code, missed acceptance criteria, and security smells
# that a passing test suite sails right past.
#
# Applies once code is proven (a passing test is bound to the current tree) —
# there is nothing to review before there is proven code, and docs-only work
# (proven? n/a) is n/a here too. Passes when a review verdict (kind=review,
# exit 0 = zero blocking findings) is bound to the current tree.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
GATE_NAME=reviewed
cur="$(ca_tree_sha)"
evidence_match test "$cur" >/dev/null || gate_result n/a "no proven code to review"
evidence_match review "$cur" >/dev/null \
  && gate_result pass "reviewed clean at current tree (${cur:0:8})" \
  || gate_result block "code not reviewed — dispatch review (kind=review)"
