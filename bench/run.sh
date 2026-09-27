#!/usr/bin/env bash
# bench/run.sh — run benchmark tasks with native Claude Code and/or the plugin,
# then score each phase against hidden acceptance tests.
#
#   bench/run.sh <task|all> [--arm native|plugin|both] [--reps N] [--model M]
#                           [--label L] [--work DIR]
#
# Each run gets a fresh git repo OUTSIDE this repository (default
# /tmp/ca-bench/<timestamp>-<label>), seeded from tasks/<task>/seed if present.
# Phases run as separate headless sessions (a change request arrives later, like
# real maintenance). The plugin arm loads a snapshot of the plugin that excludes
# bench/, via --plugin-dir, exactly as a user install would.
#
# Output: <work>/<task>/<arm>-r<rep>/run.json (+ raw claude JSON per phase).
# Aggregate with bench/report.py <work>.
#
# Headless sessions use --permission-mode bypassPermissions inside the scratch
# repo only. As root, the Claude CLI additionally requires IS_SANDBOX=1.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

TARGET="${1:-}"; shift || true
[ -n "$TARGET" ] || { echo "usage: run.sh <task|all> [--arm native|plugin|both] [--reps N] [--model M] [--label L] [--work DIR]"; exit 64; }
ARM=both; REPS=1; MODEL=""; LABEL="run"; WORK=""
while [ $# -gt 0 ]; do
  case "$1" in
    --arm) ARM="$2"; shift 2 ;;
    --reps) REPS="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --label) LABEL="$2"; shift 2 ;;
    --work) WORK="$2"; shift 2 ;;
    *) echo "unknown option: $1"; exit 64 ;;
  esac
done
case "$ARM" in native|plugin|both) ;; *) echo "bad --arm"; exit 64 ;; esac
command -v claude >/dev/null || { echo "claude CLI not found"; exit 1; }

WORK="${WORK:-${BENCH_WORK:-/tmp/ca-bench}/$(date -u +%Y%m%dT%H%M%SZ)-$LABEL}"
mkdir -p "$WORK"

# Plugin snapshot: what a user would install, minus the benchmark itself.
SNAP="$WORK/plugin"
if [ "$ARM" != native ] && [ ! -d "$SNAP" ]; then
  mkdir -p "$SNAP"
  tar -C "$ROOT" --exclude=./bench --exclude=./evals/results --exclude=./.git -cf - . | tar -C "$SNAP" -xf -
  git -C "$ROOT" rev-parse --short HEAD > "$SNAP/.bench-source-head" 2>/dev/null || true
  git -C "$ROOT" diff --quiet 2>/dev/null || echo "dirty" >> "$SNAP/.bench-source-head"
fi

FOOTER='

---
This is a non-interactive session: I cannot answer questions or approve anything later, so these are my answers in advance, from me, the user. I agree to any reasonable interpretation of the request above; where something is unspecified, choose sensibly and list your assumptions at the end. You may commit to this local git repository (do not push or deploy). Finish the whole request in this session.'

run_one() { # task arm rep
  local task="$1" arm="$2" rep="$3"
  local tdir="$HERE/tasks/$task" rdir="$WORK/$task/$arm-r$rep" proj
  proj="$rdir/project"
  mkdir -p "$proj"
  ( cd "$proj" && git init -q && git config user.email bench@local && git config user.name bench
    [ -d "$tdir/seed" ] && cp -R "$tdir/seed/." .
    [ -n "$(ls -A . | grep -v '^.git$')" ] || echo "# $task" > README.md
    git add -A && git commit -qm init )

  local budget timeout phases
  budget="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["budget_usd"])' "$tdir/task.json")"
  timeout="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["timeout_s"])' "$tdir/task.json")"
  phases="$(python3 -c 'import json,sys; print(" ".join(json.load(open(sys.argv[1]))["phases"]))' "$tdir/task.json")"

  local margs=()
  [ -n "$MODEL" ] && margs+=(--model "$MODEL")
  [ "$arm" = plugin ] && margs+=(--plugin-dir "$SNAP")

  echo "▶ $task · $arm · rep $rep  ($rdir)"
  for ph in $phases; do
    local n="${ph%.md}" t0 t1 rc
    t0=$(date +%s)
    ( cd "$proj" && timeout "$timeout" claude -p "$(cat "$tdir/$ph")$FOOTER" \
        --permission-mode bypassPermissions --output-format json \
        --max-budget-usd "$budget" "${margs[@]}" \
        > "$rdir/$n.claude.json" 2> "$rdir/$n.stderr.log" )
    rc=$?
    t1=$(date +%s)
    # Keep exactly what this phase delivered, so a later rescore (when hidden
    # suites grow) measures the same state instead of guessing from commits.
    mkdir -p "$rdir/$n.snapshot"
    tar -C "$proj" --exclude=./.git --exclude=./.coding-agent --exclude='__pycache__' -cf - . | tar -C "$rdir/$n.snapshot" -xf -
    python3 "$HERE/score.py" "$tdir" "$proj" "$ph" > "$rdir/$n.score.json"
    python3 - "$rdir" "$n" "$rc" "$((t1 - t0))" <<'PY'
import json, sys, os
rdir, n, rc, wall = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
try:
    c = json.load(open(os.path.join(rdir, n + ".claude.json")))
except Exception:
    c = {}
s = json.load(open(os.path.join(rdir, n + ".score.json")))
row = {"phase": n, "exit": rc, "timed_out": rc == 124, "wall_s": wall,
       "cost_usd": c.get("total_cost_usd"), "turns": c.get("num_turns"),
       "is_error": c.get("is_error"), "subtype": c.get("subtype"),
       "models": {m: round(v.get("costUSD", 0), 4) for m, v in (c.get("modelUsage") or {}).items()},
       "passed": s["passed"], "total": s["total"], "rate": s["rate"], "score_error": s.get("error")}
with open(os.path.join(rdir, n + ".row.json"), "w") as f:
    json.dump(row, f)
print("   %-7s %3d/%-3d hidden  $%-6s %4ss  turns=%s%s" % (
    n, row["passed"], row["total"], row["cost_usd"], wall, row["turns"],
    "  TIMEOUT" if row["timed_out"] else ("  ERROR:%s" % row["subtype"] if row["is_error"] else "")))
PY
  done

  python3 - "$rdir" "$task" "$arm" "$rep" "$tdir/task.json" "$proj" <<'PY'
import glob, json, os, subprocess, sys
rdir, task, arm, rep, tj, proj = sys.argv[1:7]
meta = json.load(open(tj))
rows = [json.load(open(os.path.join(rdir, p[:-3] + ".row.json"))) for p in meta["phases"]]
def git(*a):
    return subprocess.run(["git", "-C", proj] + list(a), capture_output=True, text=True).stdout
root = git("rev-list", "--max-parents=0", "HEAD").split()[-1]
commits = [c for c in git("rev-list", "HEAD").split() if c != root]
dirty = [l for l in git("status", "--porcelain").splitlines() if ".coding-agent" not in l]
gated = None
ev = glob.glob(os.path.join(proj, ".coding-agent", "*", "evidence.jsonl"))
if arm == "plugin":
    entries = []
    for f in ev:
        entries += [json.loads(l) for l in open(f) if l.strip()]
    heads = {e.get("head") for e in entries if e.get("kind") == "run" and e.get("tier") == "commit" and e.get("exit") == 0}
    gated = sum(1 for c in commits if git("rev-parse", c + "^").strip() in heads)
run = {"task": task, "tier": meta["tier"], "arm": arm, "rep": int(rep), "phases": rows,
       "quality": round(sum(r["rate"] for r in rows) / len(rows), 4),
       "cost_usd": round(sum(r["cost_usd"] or 0 for r in rows), 4),
       "wall_s": sum(r["wall_s"] for r in rows),
       "turns": sum(r["turns"] or 0 for r in rows),
       "commits": len(commits), "gated_commits": gated, "uncommitted_files": len(dirty),
       "plugin_source": open(os.path.join(os.path.dirname(os.path.dirname(rdir)), "plugin", ".bench-source-head")).read().split() if arm == "plugin" else None}
json.dump(run, open(os.path.join(rdir, "run.json"), "w"), indent=2)
print("   ⇒ quality %.0f%%  cost $%.2f  wall %ss  commits %d%s" % (
    100 * run["quality"], run["cost_usd"], run["wall_s"], run["commits"],
    "" if gated is None else "  gated %d/%d" % (gated, len(commits))))
PY
}

if [ "$TARGET" = all ]; then
  TASKS="$(ls "$HERE/tasks")"
else
  [ -d "$HERE/tasks/$TARGET" ] || { echo "no such task: $TARGET"; exit 64; }
  TASKS="$TARGET"
fi
ARMS="$ARM"; [ "$ARM" = both ] && ARMS="native plugin"

for task in $TASKS; do
  for rep in $(seq 1 "$REPS"); do
    for arm in $ARMS; do
      run_one "$task" "$arm" "$rep"
    done
  done
done
echo "work: $WORK"
