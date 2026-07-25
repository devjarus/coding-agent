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
  "> frozen: agreed @"*)
    # The marker must carry the user's verbatim reply. Agreement is the one
    # claim the conductor would otherwise make about itself — requiring the
    # quote makes it evidence, and `ledger.sh freeze` refuses to write one
    # without it.
    echo "$last_marker" | grep -q 'user said: "..*"' \
      && gate_result pass "intent frozen + user-agreed" \
      || gate_result block "freeze marker carries no recorded user reply — re-freeze with ledger.sh freeze intent --answer \"<what they said>\"" ;;
  "> revision @"*)       gate_result block "intent revised after freeze — re-agree (ledger.sh freeze intent --answer ...)" ;;
  *)                     gate_result block "intent not yet agreed (ledger.sh freeze intent --answer ...)" ;;
esac
