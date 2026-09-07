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
# The proven? gate only honors kind=test bound to the current tree and record.sh
# accepts a test command only when it exactly matches the frozen intent's
# `test-command-<tier>:` line. A worker cannot relabel `true` as e2e proof.
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

if [ "$kind" = test ]; then
  approved_cmd="$(declared_test_command "$tier")"
  [ -n "$approved_cmd" ] || {
    echo "record.sh: intent has no test-command-$tier entry; revise and re-freeze the intent before proving this tier" >&2
    exit 64
  }
  [ "$cmd" = "$approved_cmd" ] || {
    echo "record.sh: command does not match frozen test-command-$tier" >&2
    echo "  approved: $approved_cmd" >&2
    echo "  received: $cmd" >&2
    exit 64
  }
fi

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

# Evidence lives in a shared worktree and prove workers may finish concurrently.
# Serialize only id allocation + append so ids stay unique and a JSON line is
# never interleaved. mkdir is atomic and portable across macOS/Linux.
lockdir="${ev}.lock"
acquired=0
attempt=0
while [ "$attempt" -lt 200 ]; do
  if mkdir "$lockdir" 2>/dev/null; then
    printf '%s\n' "$$" > "$lockdir/pid"
    acquired=1
    break
  fi
  if [ -f "$lockdir/pid" ]; then
    owner="$(cat "$lockdir/pid" 2>/dev/null || echo '')"
    if [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; then
      rm -f "$lockdir/pid" 2>/dev/null || true
      rmdir "$lockdir" 2>/dev/null || true
    fi
  fi
  attempt=$((attempt + 1))
  sleep 0.05
done
[ "$acquired" -eq 1 ] || { rm -f "$tmp"; echo "record.sh: timed out waiting for evidence append lock" >&2; exit 75; }
cleanup_lock() { rm -f "$lockdir/pid" 2>/dev/null || true; rmdir "$lockdir" 2>/dev/null || true; }
trap cleanup_lock EXIT HUP INT TERM

id=$(( $(wc -l < "$ev" 2>/dev/null || echo 0) + 1 ))

printf '{"id":%d,"kind":"%s","tier":"%s","cmd":%s,"exit":%d,"stdout_sha":"%s","tree_sha":"%s","head":"%s","at":"%s"}\n' \
  "$id" "$kind" "$tier" "$(json_str "$cmd")" "$exit_code" "$stdout_sha" "$tree_sha" "$head_sha" "$ts" >> "$ev"

cleanup_lock
trap - EXIT HUP INT TERM

echo "▶ evidence #$id  kind=$kind  tier=$tier  exit=$exit_code  tree=${tree_sha:0:8}"
cat "$tmp"; rm -f "$tmp"
exit "$exit_code"
