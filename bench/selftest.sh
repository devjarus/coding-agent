#!/usr/bin/env bash
# bench/selftest.sh — zero-cost check that the benchmark itself is sound.
# For every task: the reference implementation must pass 100% of each phase's
# hidden tests, and the starting state (seed or empty repo) must NOT pass them,
# so a hidden suite can neither penalize a correct solution nor reward no work.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
for tdir in "$HERE"/tasks/*/; do
  task="$(basename "$tdir")"
  phases="$(python3 -c 'import json,sys; print(" ".join(json.load(open(sys.argv[1]))["phases"]))' "$tdir/task.json")"
  ref="$(mktemp -d)"; cp -R "$tdir/reference/." "$ref/"
  start="$(mktemp -d)"; [ -d "$tdir/seed" ] && cp -R "$tdir/seed/." "$start/"
  for ph in $phases; do
    r="$(python3 "$HERE/score.py" "$tdir" "$ref" "$ph")"
    s="$(python3 "$HERE/score.py" "$tdir" "$start" "$ph")"
    rp="$(echo "$r" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("%d/%d" % (d["passed"], d["total"]))')"
    sp="$(echo "$s" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("%d/%d" % (d["passed"], d["total"]))')"
    rok="$(echo "$r" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(int(d["total"] > 0 and d["passed"] == d["total"]))')"
    sok="$(echo "$s" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(int(d["passed"] < d["total"]))')"
    mark="✓"; { [ "$rok" = 1 ] && [ "$sok" = 1 ]; } || { mark="✗"; fail=1; }
    printf '  %s %-26s %-10s reference %-7s start %s\n' "$mark" "$task" "${ph%.md}" "$rp" "$sp"
    [ "$rok" = 1 ] || echo "$r" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("      failing:", [f for s in d["suites"].values() for f in (s.get("failed") or [])], d.get("error") or "")'
  done
  rm -rf "$ref" "$start"
done
[ "$fail" -eq 0 ] && echo "bench selftest: PASSED" || { echo "bench selftest: FAILED"; exit 1; }
