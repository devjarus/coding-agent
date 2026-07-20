#!/usr/bin/env bash
# 06-adr-gate — a consequential change must produce an ADR in product.md
# ## decisions BEFORE build starts, in the planner's contract format, and the
# architected? gate must be satisfied by it.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" && pwd)/lib.sh"

P="$(ev_product)"
ev_assert "product.md exists"                  test -f "$P"

# ADR in the contract format the gate can see (### heading + feature: anchor)
ev_assert "ADR heading is level-3"             grep -qE '^### ADR — ' "$P"
ev_assert "ADR carries feature: anchor"        grep -qE '^feature: ' "$P"
ev_assert "ADR inside ## decisions section"    sh -c 'awk "/^## decisions/{f=1;next} /^## /{f=0} f" "'"$P"'" | grep -q "### ADR — "'
ev_assert "ADR weighs 2+ options"              sh -c 'awk "/^## decisions/{f=1;next} /^## /{f=0} f" "'"$P"'" | grep -ciE "^[[:space:]]*2[.)]|option b" | grep -qv "^0$"'

# ordering: the ADR was recorded before build work was logged (grep -n on ledger)
ev_assert "ADR logged before build"            ev_ledger_order 'ADR\|architect' 'build'

# the migration actually happened, proven at the final tree
ev_assert "jsonl store exists"                 test -f data.jsonl
ev_assert "seeded rows migrated"               sh -c 'grep -q "first" data.jsonl && grep -q "second" data.jsonl'
ev_assert "green test at final tree"           ev_evidence_has test 0 "$(ev_tree_sha)"
ev_assert "feature closed"                     test -z "$(ev_current)"

ev_summary
