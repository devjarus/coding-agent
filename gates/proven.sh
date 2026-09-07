#!/usr/bin/env bash
# proven? — the load-bearing gate. Passes only when EVERY verification tier the
# intent declares has a green test run (kind=test, exit 0) bound to the CURRENT
# tree sha.
#
# Three things give this gate teeth:
#   1. kind=test + exact intent command — record.sh rejects a test command that
#      does not match the frozen `test-command-<tier>:` contract.
#   2. tree binding — a pass against stale code is rejected, so any later edit
#      necessarily re-opens the gate.
#   3. every declared tier — one self-chosen green command cannot stand in for
#      the suite. A green unit run while browser/e2e tiers are stale is a false
#      pass, so tier completeness stays structural rather than narrative.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
GATE_NAME=proven

ev="$(ca_evidence)"
[ -f "$ev" ] || gate_result block "no evidence recorded — run tests via record.sh \"<test cmd>\" test <tier>"

tiers="$(declared_tiers)"
[ -n "$tiers" ] || gate_result block "intent declares no verification tiers — add a \`tiers:\` line (e.g. \`tiers: unit, e2e\`) and re-freeze"

# A user-facing surface is not proven by unit tests. The intent must declare an e2e tier,
# and that tier must go green like any other (three dogfood incidents shipped
# unit-green features whose live path was never wired).
if intent_touches ui && ! echo "$tiers" | grep -qx 'e2e'; then
  gate_result block "intent touches ui — declare an \`e2e\` tier that drives the live path (unit green is not a reachable feature)"
fi

cur="$(ca_tree_sha)"
missing=""
missing_commands=""
while IFS= read -r t; do
  [ -n "$t" ] || continue
  [ -n "$(declared_test_command "$t")" ] || missing_commands="$missing_commands $t"
  evidence_match_tier test "$t" "$cur" >/dev/null || missing="$missing $t"
done <<< "$tiers"

[ -z "$missing_commands" ] \
  || gate_result block "intent has no test-command-<tier> contract for tier(s):$missing_commands — revise and re-freeze"

[ -z "$missing" ] \
  && gate_result pass "all declared tiers green at current tree (${cur:0:8}): $(echo "$tiers" | tr '\n' ' ')" \
  || gate_result block "no passing test at current tree (${cur:0:8}) for tier(s):$missing"
