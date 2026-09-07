#!/usr/bin/env bash
# Eval runner — set up a scratch project, drive a session, assert on artifacts.
#
#   evals/run.sh <scenario|all> [options]
#
#   Options:
#     --manual        don't invoke claude; print the prompt, you drive an
#                     interactive session in the scratch project, press Enter
#                     when done, and the harness asserts.
#     --model <m>     pass --model to claude (headless mode).
#     --keep          keep the scratch project even on pass (default: kept on
#                     fail, removed on pass).
#     --installed     assume the plugin is installed (registered agents); omits
#                     the inline-worker fallback addendum from prompts.
#
# Results land in evals/results/<timestamp>/<scenario>/:
#   project/           the scratch repo the session ran in (if kept)
#   prompt.rendered.md the exact prompt used
#   claude-output.json headless session output (usage, cost) when available
#   report.json        assertions + metrics
#
# Headless sessions run with --permission-mode bypassPermissions INSIDE the
# scratch project only. Don't point this at a real project.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export EV_PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"

SCENARIO="${1:-}"; shift || true
[ -n "$SCENARIO" ] || { echo "usage: run.sh <scenario|all> [--manual] [--model m] [--keep] [--installed]"; exit 64; }

MANUAL=0; KEEP=0; INSTALLED=0; MODEL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --manual) MANUAL=1; shift ;;
    --keep) KEEP=1; shift ;;
    --installed) INSTALLED=1; shift ;;
    --model) MODEL="${2:?--model needs a value}"; shift 2 ;;
    *) echo "unknown option: $1"; exit 64 ;;
  esac
done

TS="$(date -u +%Y%m%dT%H%M%SZ)"
RESULTS_ROOT="$HERE/results/$TS"

run_one() {
  local name="$1"
  local sdir="$HERE/scenarios/$name"
  [ -d "$sdir" ] || { echo "no such scenario: $name"; return 64; }

  local rdir="$RESULTS_ROOT/$name"
  local proj="$rdir/project"
  mkdir -p "$proj"
  export EV_PROJECT_DIR="$proj"

  echo "══════════════════════════════════════════════════"
  echo "  $name"
  echo "══════════════════════════════════════════════════"

  # 1. scratch project: fresh git repo, optional scenario seed
  ( cd "$proj" && git init -q && git config user.email eval@local && git config user.name eval \
    && echo "# eval scratch — $name" > README.md && git add -A && git commit -qm init )
  [ -f "$sdir/setup.sh" ] && ( cd "$proj" && bash "$sdir/setup.sh" )

  # 2. drive the session (skipped for script-only scenarios)
  local t0 t1
  t0=$(date +%s)
  if [ -f "$sdir/prompt.md" ]; then
    # render: substitute placeholders; append eval-mode addendum
    local rendered="$rdir/prompt.rendered.md"
    sed -e "s|{{PLUGIN_ROOT}}|$EV_PLUGIN_ROOT|g" -e "s|{{SCENARIO_DIR}}|$sdir|g" "$sdir/prompt.md" > "$rendered"
    if [ "$INSTALLED" -eq 0 ]; then
      cat >> "$rendered" <<'ADDENDUM'

---
EVAL-MODE NOTE: if `Task` dispatch with a registered `subagent_type` is unavailable in
this session, perform that worker's role INLINE, following the corresponding
agent file under the plugin root's `agents/` — the gates and evidence rules
still apply exactly. Do not skip recording evidence because dispatch was inline.
ADDENDUM
    fi

    if [ "$MANUAL" -eq 1 ]; then
      echo ""
      echo "MANUAL MODE — drive this yourself:"
      echo "  1. cd $proj"
      echo "  2. start claude and paste the prompt from: $rendered"
      echo "  3. drive to completion, then return here"
      printf "Press Enter when the session is done... "
      read -r _
    elif [ -f "$sdir/drive.sh" ]; then
      # scenario-specific driver (multi-phase sessions, injected turns, ...)
      ( cd "$proj" && EV_RENDERED_PROMPT="$rendered" EV_RESULT_DIR="$rdir" EV_MODEL="$MODEL" bash "$sdir/drive.sh" )
    else
      command -v claude >/dev/null 2>&1 || { echo "claude CLI not found — use --manual"; return 1; }
      local margs=()
      [ -n "$MODEL" ] && margs+=(--model "$MODEL")
      local turns; turns="$(grep -E '^MAX_TURNS=' "$sdir/meta.env" 2>/dev/null | cut -d= -f2 || true)"
      [ -n "$turns" ] && margs+=(--max-turns "$turns")
      ( cd "$proj" && claude -p "$(cat "$rendered")" \
          --permission-mode bypassPermissions --output-format json \
          "${margs[@]+"${margs[@]}"}" \
          > "$rdir/claude-output.json" 2> "$rdir/claude-stderr.log" ) || true
    fi
  fi
  t1=$(date +%s)

  # A model runner/API failure is not a product assertion failure. Detect it
  # before inspecting artifacts so expired auth, quota, or transport errors are
  # reported as infrastructure errors rather than a wall of misleading misses.
  local runner_error=""
  if [ "$MANUAL" -eq 0 ] && [ -f "$sdir/prompt.md" ]; then
    runner_error="$(python3 - "$rdir" <<'PY'
import glob, json, os, sys
for path in sorted(glob.glob(os.path.join(sys.argv[1], "claude-output*.json"))):
    try:
        data = json.load(open(path))
    except (OSError, ValueError) as exc:
        print(f"{os.path.basename(path)}: invalid runner output ({exc})")
        continue
    if data.get("is_error"):
        print(f"{os.path.basename(path)}: {data.get('result') or data.get('terminal_reason') or 'model runner failed'}")
PY
)"
  fi
  if [ -n "$runner_error" ]; then
    python3 - "$name" "$((t1-t0))" "$runner_error" > "$rdir/report.json" <<'PY'
import json, sys
print(json.dumps({"scenario": sys.argv[1], "verdict": "error",
                  "duration_s": int(sys.argv[2]), "summary": {"pass": 0, "fail": 0},
                  "checks": [], "runner_error": sys.argv[3]}, indent=2))
PY
    printf '\n  verdict: ERROR   (model runner unavailable, %ss)\n' "$((t1-t0))"
    printf '   %s\n' "$runner_error"
    return 2
  fi

  # 3. assert on artifacts → report.json
  local raw="$rdir/assertions.jsonl"
  ( cd "$proj" && bash "$sdir/assert.sh" ) > "$raw" 2> "$rdir/assert-stderr.log"
  local verdict=$?

  ( cd "$proj" && source "$HERE/lib.sh" && ev_metrics ) > "$rdir/metrics.json" 2>/dev/null || echo '{}' > "$rdir/metrics.json"
  python3 - "$raw" "$rdir/metrics.json" "$name" "$((t1-t0))" "$verdict" > "$rdir/report.json" <<'PY'
import json, sys
raw, metrics_f, name, dur, verdict = sys.argv[1:6]
checks, summary = [], {}
for line in open(raw):
    line = line.strip()
    if not line: continue
    d = json.loads(line)
    if "summary" in d: summary = d["summary"]
    else: checks.append(d)
report = {"scenario": name, "verdict": "pass" if int(verdict) == 0 else "fail",
          "duration_s": int(dur), "summary": summary, "checks": checks,
          "metrics": json.load(open(metrics_f))}
print(json.dumps(report, indent=2))
PY

  # 4. console summary
  python3 - "$rdir/report.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
print(f"\n  verdict: {r['verdict'].upper()}   ({r['summary'].get('pass',0)} pass / {r['summary'].get('fail',0)} fail, {r['duration_s']}s)")
for c in r["checks"]:
    mark = "✔" if c["status"] == "pass" else "✘"
    print(f"   {mark} {c['check']}: {c['detail']}")
PY

  # 5. cleanup
  if [ "$verdict" -eq 0 ] && [ "$KEEP" -eq 0 ]; then rm -rf "$proj"; fi
  return "$verdict"
}

overall=0
if [ "$SCENARIO" = "all" ]; then
  for d in "$HERE"/scenarios/*/; do
    run_one "$(basename "$d")" || overall=1
  done
else
  run_one "$SCENARIO" || overall=1
fi

echo ""
echo "results: $RESULTS_ROOT"
exit "$overall"
