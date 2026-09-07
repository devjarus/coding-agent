#!/usr/bin/env bash
# shipped? — conditional. Applies only when intent is tagged `deploys: yes`.
# Passes when a deploy (kind=deploy, exit 0) is bound to the current tree.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
GATE_NAME=shipped
intent="$(ledger_section "$(ca_ledger)" intent | strip_comments)"
echo "$intent" | grep -qiE '^[[:space:]]*deploys:[[:space:]]*yes\b' || gate_result n/a "no deploy required"
evidence_match deploy >/dev/null \
  && gate_result pass "deployed + healthy at current tree" \
  || gate_result block "not deployed at current tree (kind=deploy)"
