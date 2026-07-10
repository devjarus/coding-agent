#!/usr/bin/env bash
# observed? — conditional. Applies only when intent is tagged `deploys: yes`.
# Passes when a post-deploy observation (kind=observe, exit 0) is recorded.
# On failure the conductor routes to rollback + diagnose (design doc §7).
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
GATE_NAME=observed
intent="$(ledger_section "$(ca_ledger)" intent | strip_comments)"
echo "$intent" | grep -qi 'deploys: *yes' || gate_result n/a "no deploy required"
ev="$(ca_evidence)"
{ [ -f "$ev" ] && grep '"kind":"observe"' "$ev" | grep -q '"exit":0'; } \
  && gate_result pass "post-deploy health recorded" \
  || gate_result block "no healthy post-deploy observation (kind=observe)"
