#!/usr/bin/env bash
# designed? — conditional. Applies only when intent is tagged `touches: ui`.
# Passes when a design verdict (kind=design, exit 0) is bound to the current tree.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
GATE_NAME=designed
intent="$(ledger_section "$(ca_ledger)" intent | strip_comments)"
# Match ui anywhere in the touches value list (`touches: api, ui`), not only as
# the first value — anchored to the touches line so prose can't trip it.
echo "$intent" | grep -qiE '^[[:space:]]*touches:.*\bui\b' || gate_result n/a "no ui"
evidence_match design >/dev/null \
  && gate_result pass "design approved on the surface at current tree" \
  || gate_result block "ui not approved — drive the design surface (kind=design)"
