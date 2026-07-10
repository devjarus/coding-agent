#!/usr/bin/env bash
# record.sh — the ONLY writer of evidence.jsonl.
# Runs a command, captures reality (exit, output hash, tree sha), appends one
# evidence entry, then exits with the command's own exit code.
#
#   record.sh "<command>" [kind]
#     kind = test | deploy | design | observe | run   (default: run)
#
# The proven? gate only honors kind=test bound to the current tree, so a hollow
# `record.sh "echo ok"` cannot satisfy proof.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../gates/lib.sh"

cmd="${1:?usage: record.sh \"<command>\" [kind]}"
kind="${2:-run}"

ev="$(ca_evidence)"
[ -n "$(ca_current)" ] || { echo "no active feature — run: ledger.sh init <slug>" >&2; exit 64; }
mkdir -p "$(dirname "$ev")"; [ -f "$ev" ] || : > "$ev"

tmp="$(mktemp)"
bash -c "$cmd" > "$tmp" 2>&1
exit_code=$?

stdout_sha="$(shasum -a 256 "$tmp" | cut -d' ' -f1)"
tree_sha="$(ca_tree_sha)"
ts="$(date -u +%FT%TZ)"
id=$(( $(wc -l < "$ev" 2>/dev/null || echo 0) + 1 ))

printf '{"id":%d,"kind":"%s","cmd":%s,"exit":%d,"stdout_sha":"%s","tree_sha":"%s","at":"%s"}\n' \
  "$id" "$kind" "$(json_str "$cmd")" "$exit_code" "$stdout_sha" "$tree_sha" "$ts" >> "$ev"

echo "▶ evidence #$id  kind=$kind  exit=$exit_code  tree=${tree_sha:0:8}"
cat "$tmp"; rm -f "$tmp"
exit "$exit_code"
