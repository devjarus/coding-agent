#!/usr/bin/env bash
# architected? — conditional. Applies only when intent is tagged
# `consequential: yes`. Passes when an ADR for this feature exists in the
# product ledger's ## decisions section.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
GATE_NAME=architected
intent="$(ledger_section "$(ca_ledger)" intent | strip_comments)"
echo "$intent" | grep -qiE '^[[:space:]]*consequential:[[:space:]]*yes\b' || gate_result n/a "routine change"
slug="$(ca_current)"
# strip_comments so the template's commented-out ADR example (which contains the
# literal "feature: <slug>") can't false-pass; the real ADR carries "feature: <slug>"
# as a live line under a "### ADR — <slug> —" heading.
ledger_section "$(ca_product)" decisions | strip_comments | grep -qi "$slug" \
  && gate_result pass "ADR recorded for $slug" \
  || gate_result block "consequential change needs an ADR in product.md ## decisions"
