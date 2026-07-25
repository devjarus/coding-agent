#!/usr/bin/env bash
# record.sh — the ONLY writer of evidence.jsonl.
# Runs a command, captures reality (exit, output hash, tree sha), appends one
# evidence entry, then exits with the command's own exit code.
#
#   record.sh "<command>" [kind] [tier]
#     kind = test | deploy | design | observe | review | run   (default: run)
#     tier = the verification tier this run covers (default: default)
#            e.g. typecheck | unit | integration | e2e — must match one of the
#            names the intent's `tiers:` line declares, or proven? won't see it.
#
# The proven? gate only honors kind=test bound to the current tree, so a hollow
# `record.sh "echo ok"` cannot satisfy proof — and it requires EVERY declared
# tier, so one self-chosen green command cannot stand in for the suite.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../gates/lib.sh"

cmd="${1:?usage: record.sh \"<command>\" [kind] [tier]}"
kind="${2:-run}"
tier="${3:-default}"

# Guard the taxonomy: gates read evidence kinds, so a worker recording its
# *dispatch* kind (build, prove, ship, diagnose, frame, architect) instead of an
# evidence kind would silently never satisfy any gate. Only evidence kinds pass.
case "$kind" in
  test|deploy|design|observe|review|run) ;;
  *) echo "record.sh: invalid kind '$kind' (allowed: test deploy design observe review run — did you pass a dispatch kind like 'prove'/'build'/'ship'?)" >&2; exit 64 ;;
esac

# Tier is a bare token so gates can match it exactly; reject anything that would
# not survive a `grep '"tier":"<t>"'` round-trip.
case "$tier" in
  *[!A-Za-z0-9_-]*|"") echo "record.sh: invalid tier '$tier' (use a bare token: unit, e2e, typecheck, integration)" >&2; exit 64 ;;
esac

ev="$(ca_evidence)"
[ -n "$(ca_current)" ] || { echo "no active feature — run: ledger.sh init <slug>" >&2; exit 64; }
mkdir -p "$(dirname "$ev")"; [ -f "$ev" ] || : > "$ev"

tmp="$(mktemp)"
bash -c "$cmd" > "$tmp" 2>&1
exit_code=$?

stdout_sha="$(shasum -a 256 "$tmp" | cut -d' ' -f1)"
tree_sha="$(ca_tree_sha)"
head_sha="$(git rev-parse HEAD 2>/dev/null || echo "")"
ts="$(date -u +%FT%TZ)"
id=$(( $(wc -l < "$ev" 2>/dev/null || echo 0) + 1 ))

printf '{"id":%d,"kind":"%s","tier":"%s","cmd":%s,"exit":%d,"stdout_sha":"%s","tree_sha":"%s","head":"%s","at":"%s"}\n' \
  "$id" "$kind" "$tier" "$(json_str "$cmd")" "$exit_code" "$stdout_sha" "$tree_sha" "$head_sha" "$ts" >> "$ev"

echo "▶ evidence #$id  kind=$kind  tier=$tier  exit=$exit_code  tree=${tree_sha:0:8}"
cat "$tmp"; rm -f "$tmp"
exit "$exit_code"
