#!/usr/bin/env bash
# framed? — intent exists and is user-agreed (frozen). Always applies.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
GATE_NAME=framed
l="$(ca_ledger)"
[ -f "$l" ] || gate_result block "no ledger for active feature"
sec="$(ledger_section "$l" intent | strip_comments)"
[ -n "$(echo "$sec" | tr -d '[:space:]')" ] || gate_result block "intent is empty"
# The LAST agreement marker wins: freeze stamps "> frozen: agreed @", revise
# stamps "> revision @". A revision after the last freeze re-opens the gate until
# the user re-agrees and the conductor re-freezes. Anchored to the blockquote so
# the frame template's placeholder text can't false-pass.
last_marker="$(echo "$sec" | grep -E '^> (frozen: agreed|revision) @' | tail -1)"
case "$last_marker" in
  "> frozen: agreed @"*) gate_result pass "intent frozen + agreed" ;;
  "> revision @"*)       gate_result block "intent revised after freeze — re-agree (ledger.sh freeze intent)" ;;
  *)                     gate_result block "intent not yet agreed (ledger.sh freeze intent)" ;;
esac
