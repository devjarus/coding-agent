#!/usr/bin/env bash
# observed? — conditional. Applies only when intent is tagged `deploys: yes`.
# Passes when a post-deploy observation (kind=observe, exit 0) is recorded.
# On failure the conductor routes to rollback + diagnose (design doc §7).
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
GATE_NAME=observed
intent="$(ledger_section "$(ca_ledger)" intent | strip_comments)"
echo "$intent" | grep -qiE '^[[:space:]]*deploys:[[:space:]]*yes\b' || gate_result n/a "no deploy required"
# Tree-bind like shipped?/designed?: a healthy observation from an earlier tree
# must not satisfy the gate after the code moved. evidence_match requires
# kind=observe, exit 0, AND the current tree_sha.
evidence_match observe >/dev/null \
  && gate_result pass "post-deploy health recorded at current tree" \
  || gate_result block "no healthy post-deploy observation at current tree (kind=observe)"
