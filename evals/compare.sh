#!/usr/bin/env bash
# Compare two eval runs (A/B): per-scenario verdicts + metric deltas.
#
#   evals/compare.sh <results-dir-A> <results-dir-B>
#
# Use it to compare before/after a prompt or runtime change on the same
# scenarios. A "results dir" is one evals/results/<timestamp>/ directory.
set -uo pipefail
A="${1:?usage: compare.sh <results-dir-A> <results-dir-B>}"
B="${2:?usage: compare.sh <results-dir-A> <results-dir-B>}"

python3 - "$A" "$B" <<'PY'
import json, os, sys, glob

def load(root):
    out = {}
    for rp in glob.glob(os.path.join(root, "*", "report.json")):
        r = json.load(open(rp))
        out[r["scenario"]] = r
    return out

a_root, b_root = sys.argv[1], sys.argv[2]
A, B = load(a_root), load(b_root)
names = sorted(set(A) | set(B))
if not names:
    print("no report.json found under either directory"); sys.exit(1)

print(f"{'scenario':<18} {'A':>6} {'B':>6}   {'A p/f':>7} {'B p/f':>7}   {'dur A':>6} {'dur B':>6}   evidence A → B")
print("─" * 100)
regressions = 0
for n in names:
    ra, rb = A.get(n), B.get(n)
    va = ra["verdict"] if ra else "—"
    vb = rb["verdict"] if rb else "—"
    if va == "pass" and vb == "fail": regressions += 1
    pf = lambda r: f"{r['summary'].get('pass',0)}/{r['summary'].get('fail',0)}" if r else "—"
    du = lambda r: f"{r['duration_s']}s" if r else "—"
    ev = lambda r: ",".join(f"{k}:{v}" for k, v in sorted(r["metrics"].get("evidence_by_kind", {}).items())) or "-" if r else "—"
    print(f"{n:<18} {va:>6} {vb:>6}   {pf(ra):>7} {pf(rb):>7}   {du(ra):>6} {du(rb):>6}   {ev(ra)} → {ev(rb)}")

print("─" * 100)
print(f"A: {sum(1 for r in A.values() if r['verdict']=='pass')}/{len(A)} pass    "
      f"B: {sum(1 for r in B.values() if r['verdict']=='pass')}/{len(B)} pass    "
      f"regressions (pass→fail): {regressions}")
sys.exit(1 if regressions else 0)
PY
