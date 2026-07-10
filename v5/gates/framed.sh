#!/usr/bin/env bash
# framed? — intent exists and is user-agreed (frozen). Always applies.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
GATE_NAME=framed
l="$(ca_ledger)"
[ -f "$l" ] || gate_result block "no ledger for active feature"
sec="$(ledger_section "$l" intent | strip_comments)"
[ -n "$(echo "$sec" | tr -d '[:space:]')" ] || gate_result block "intent is empty"
echo "$sec" | grep -q 'frozen: agreed @' \
  && gate_result pass "intent frozen + agreed" \
  || gate_result block "intent not yet agreed (ledger.sh freeze intent)"
