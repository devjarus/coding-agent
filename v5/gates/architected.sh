#!/usr/bin/env bash
# architected? — conditional. Applies only when intent is tagged
# `consequential: yes`. Passes when an ADR for this feature exists in the
# product ledger's ## decisions section.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
GATE_NAME=architected
intent="$(ledger_section "$(ca_ledger)" intent | strip_comments)"
echo "$intent" | grep -qi 'consequential: *yes' || gate_result n/a "routine change"
slug="$(ca_current)"
ledger_section "$(ca_product)" decisions | grep -qi "$slug" \
  && gate_result pass "ADR recorded for $slug" \
  || gate_result block "consequential change needs an ADR in product.md ## decisions"
