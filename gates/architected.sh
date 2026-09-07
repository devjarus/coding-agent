#!/usr/bin/env bash
# architected? — conditional. Applies only when intent is tagged
# `consequential: yes`. Passes when a live (non-superseded) ADR for this feature
# exists in the product ledger's ## decisions section, and — when that ADR names
# a one-way door — when the user's agreement to it is recorded.
#
# ADRs are matched on the canonical `feature: <slug>` anchor, not the heading
# text, so retitling a decision cannot orphan it from its feature.
#
# Supersession matters on a long-lived product: `## decisions` is append-only
# and grows for the life of the repo, so an ADR that a later decision reversed
# must stop reading as current. The conductor marks the loser `superseded-by:`
# rather than deleting it — the history stays readable, the gate stops counting it.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
GATE_NAME=architected

intent="$(ledger_section "$(ca_ledger)" intent | strip_comments)"
echo "$intent" | grep -qiE '^[[:space:]]*consequential:[[:space:]]*yes\b' || gate_result n/a "routine change"
slug="$(ca_current)"

# Split ## decisions into ADR blocks; keep the ones anchored to this feature
# that are not superseded. strip_comments first so the template's commented-out
# example (which contains a literal `feature: <slug>`) cannot false-pass.
adr="$(ledger_section "$(ca_product)" decisions | strip_comments | awk -v s="$slug" '
  function flush() { if (keep && !dead) printf "%s", buf; buf=""; keep=0; dead=0 }
  /^### ADR/                                              { flush() }
                                                          { buf = buf $0 "\n" }
  $0 ~ "^[[:space:]]*feature:[[:space:]]*" s "[[:space:]]*$" { keep=1 }
  /^[[:space:]]*superseded-by:[[:space:]]*[^[:space:]]/     { dead=1 }
  END { flush() }')"

[ -n "$(echo "$adr" | tr -d '[:space:]')" ] \
  || gate_result block "consequential change needs a live ADR in product.md ## decisions with a 'feature: $slug' line"

# A one-way door is the most expensive mistake available, so it needs the user's
# recorded agreement — same rule as framed?, for the same reason: the writer of
# the record must not also be the source of the consent.
if echo "$adr" | grep -qiE '^[[:space:]]*(one-way door\?|door:)[[:space:]]*(yes|one-way)'; then
  echo "$adr" | grep -q 'user agreed: "..*"' \
    || gate_result block "ADR names a one-way door — ask the user, then add: user agreed: \"<what they said>\""
fi

gate_result pass "live ADR recorded for $slug"
