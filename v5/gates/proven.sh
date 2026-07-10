#!/usr/bin/env bash
# proven? — the load-bearing gate. Passes only when a TEST run (kind=test,
# exit 0) is bound to the CURRENT tree sha. Requiring kind=test is what gives
# the gate teeth: a hollow `record.sh "echo ok"` (kind=run) cannot satisfy it,
# and a pass against stale code is rejected because the tree sha won't match.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
GATE_NAME=proven
ev="$(ca_evidence)"
[ -f "$ev" ] || gate_result block "no evidence recorded — run tests via record.sh \"<test cmd>\" test"
cur="$(ca_tree_sha)"
evidence_match test "$cur" >/dev/null \
  && gate_result pass "tests passed at current tree (${cur:0:8})" \
  || gate_result block "no passing test bound to current tree (${cur:0:8})"
