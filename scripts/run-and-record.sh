#!/usr/bin/env bash
# run-and-record.sh — run the project's verification and record the RESULT as a
# measured artifact. Test counts / pass-fail are then READ from a file, never
# typed from memory. This is the mechanical kill for fabricated "verified / N
# tests" narration: the numbers in work.md and commit messages come from THIS
# file, tied to a git tree hash, so a number that was never measured cannot be
# typed.
#
# MULTI-TIER (the core gate). A feature is "done" only when EVERY declared tier
# is green — not when one self-chosen command exits 0. Real-world failures
# (schema drift, dead live-paths, browser/e2e/server tier breakage) hide behind
# a green unit run. So this records EACH tier and sets `all_green` true only
# when all of them pass. The single-command form still works (one tier named
# "verify"), so legacy callers and auto-detect are unchanged.
#
# Usage:
#   run-and-record.sh <repo_root>                                   # auto-detect, 1 tier
#   run-and-record.sh <repo_root> "<verify_cmd>"                    # explicit, 1 tier named "verify"
#   run-and-record.sh <repo_root> --tier unit="npm test" \         # N named tiers — ALL must pass
#                                 --tier typecheck="npm run typecheck" \
#                                 --tier e2e="npm run test:e2e"
#     A tier spec is name=cmd, split on the FIRST '='. Declare the tiers your
#     task's plan.md evaluation block names (unit / integration / e2e / build).
#
# Writes <repo>/.coding-agent/last-verify.json:
#   { "ok": bool,              # == all_green (aggregate) — legacy consumers read this
#     "all_green": bool,       # true ⟺ every tier exit 0
#     "exit_code": N,          # 0 ⟺ all_green, else 1
#     "command": "...",        # tier names joined (or the single command)
#     "failing_tiers": [...],  # names of tiers that were red
#     "tiers": [ {"name","ok","exit_code","tests":{passed,failed},"raw_tail"} ],
#     "tree": "<git tree sha>",
#     "tests": {"passed": N|null, "failed": N|null},   # summed across tiers
#     "raw_tail": "...",       # tail of the FIRST failing tier (what broke)
#     "ran_at": "<iso>" }
# `tree` is the content hash of all tracked+new source (excluding .coding-agent),
# computed in a throwaway index so the real index is untouched. The commit-msg
# hook compares it to the staged tree to reject a commit whose verification
# doesn't match what's actually being committed.
#
# Exit code: 0 when all_green, else 1. The recorded file is the source of truth;
# this script never interprets pass/fail beyond "every declared tier exited 0".

set -uo pipefail
REPO="${1:-$PWD}"
shift 2>/dev/null || true

cd "$REPO" 2>/dev/null || { echo '{"ok":false,"reason":"not a directory"}'; exit 2; }

# ── collect tiers (name → cmd), preserving order ────────────────────
tier_names=()
tier_cmds=()
if [[ "${1:-}" == --tier* ]]; then
  # multi-tier form: one or more `--tier name=cmd`
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tier)
        spec="${2:-}"; shift 2 2>/dev/null || shift $#
        ;;
      --tier=*)
        spec="${1#--tier=}"; shift
        ;;
      *)
        shift; continue
        ;;
    esac
    [[ -z "$spec" || "$spec" != *=* ]] && continue
    tier_names+=("${spec%%=*}")
    tier_cmds+=("${spec#*=}")
  done
else
  # single-tier form: explicit cmd, or auto-detect
  VERIFY_CMD="${1:-}"
  if [[ -z "$VERIFY_CMD" ]]; then
    if [[ -f package.json ]] && grep -q '"test"[[:space:]]*:' package.json; then
      VERIFY_CMD="npm test"
    elif { [[ -f pyproject.toml ]] || [[ -f pytest.ini ]] || [[ -d tests ]]; } && command -v pytest >/dev/null 2>&1; then
      VERIFY_CMD="pytest"
    elif [[ -f go.mod ]]; then
      VERIFY_CMD="go test ./..."
    elif [[ -f Cargo.toml ]]; then
      VERIFY_CMD="cargo test"
    else
      echo '{"ok":false,"reason":"no verify command detected — pass one explicitly: run-and-record.sh <repo> \"<cmd>\" (or --tier name=cmd ...)"}'
      exit 2
    fi
  fi
  tier_names+=("verify")
  tier_cmds+=("$VERIFY_CMD")
fi

if [[ ${#tier_names[@]} -eq 0 ]]; then
  echo '{"ok":false,"reason":"no tiers parsed — use --tier name=cmd or a bare command"}'
  exit 2
fi

# ── content hash of all source (tracked + new), .coding-agent excluded ──
# Use a throwaway index so the real index/staging is never disturbed.
tree=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  tmp_index="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/cga-idx.$$")"
  if GIT_INDEX_FILE="$tmp_index" git read-tree HEAD 2>/dev/null \
     || GIT_INDEX_FILE="$tmp_index" git read-tree --empty 2>/dev/null; then
    GIT_INDEX_FILE="$tmp_index" git add -A -- . ':(exclude).coding-agent' 2>/dev/null || true
    tree="$(GIT_INDEX_FILE="$tmp_index" git write-tree 2>/dev/null || true)"
  fi
  rm -f "$tmp_index"
fi

# ── run each tier, capture output + exit ────────────────────────────
tier_objs=()
failing=()
all_green=true
sum_passed=0; sum_failed=0; saw_count=false
first_fail_tail=""
i=0
while [[ $i -lt ${#tier_names[@]} ]]; do
  name="${tier_names[$i]}"
  cmd="${tier_cmds[$i]}"
  out="$(eval "$cmd" 2>&1)"
  code=$?
  passed="$(printf '%s\n' "$out" | grep -oiE '[0-9]+ (passed|passing)' | grep -oE '[0-9]+' | head -1)"
  failed="$(printf '%s\n' "$out" | grep -oiE '[0-9]+ (failed|failing)' | grep -oE '[0-9]+' | head -1)"
  [[ -n "$passed" ]] && { sum_passed=$((sum_passed + passed)); saw_count=true; }
  [[ -n "$failed" ]] && { sum_failed=$((sum_failed + failed)); saw_count=true; }
  raw_tail="$(printf '%s\n' "$out" | tail -20)"
  tobj="$(jq -nc \
    --arg name "$name" \
    --argjson code "$code" \
    --argjson passed "${passed:-null}" \
    --argjson failed "${failed:-null}" \
    --arg cmd "$cmd" \
    --arg raw "$raw_tail" \
    '{name:$name, ok:($code==0), exit_code:$code, command:$cmd, tests:{passed:$passed, failed:$failed}, raw_tail:$raw}')"
  tier_objs+=("$tobj")
  if [[ $code -ne 0 ]]; then
    all_green=false
    failing+=("$name")
    [[ -z "$first_fail_tail" ]] && first_fail_tail="$raw_tail"
  fi
  i=$((i + 1))
done

tiers_json="$(printf '%s\n' "${tier_objs[@]}" | jq -sc .)"
failing_json="$(printf '%s\n' ${failing[@]+"${failing[@]}"} | jq -R . | jq -sc 'map(select(length>0))')"
sum_passed_json="null"; [[ "$saw_count" == true ]] && sum_passed_json="$sum_passed"
sum_failed_json="null"; [[ "$saw_count" == true ]] && sum_failed_json="$sum_failed"
agg_code=0; [[ "$all_green" == true ]] || agg_code=1
cmd_label="$(printf '%s\n' "${tier_names[@]}" | paste -sd, - 2>/dev/null || printf '%s' "${tier_names[*]}")"
raw_label="$first_fail_tail"
[[ -z "$raw_label" ]] && raw_label="$(printf '%s' "$tiers_json" | jq -r '.[-1].raw_tail // ""')"

ran_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mkdir -p "$REPO/.coding-agent"

jq -n \
  --argjson all_green "$all_green" \
  --argjson code "$agg_code" \
  --arg cmd "$cmd_label" \
  --argjson tiers "$tiers_json" \
  --argjson failing "$failing_json" \
  --arg tree "$tree" \
  --argjson passed "$sum_passed_json" \
  --argjson failed "$sum_failed_json" \
  --arg raw "$raw_label" \
  --arg ran_at "$ran_at" \
  '{ok:$all_green, all_green:$all_green, exit_code:$code, command:$cmd, failing_tiers:$failing, tiers:$tiers, tree:$tree, tests:{passed:$passed, failed:$failed}, raw_tail:$raw, ran_at:$ran_at}' \
  > "$REPO/.coding-agent/last-verify.json"

if [[ "$all_green" == true ]]; then
  echo "verify: ALL ${#tier_names[@]} tier(s) green ($cmd_label) passed=$sum_passed_json tree=${tree:0:12} → .coding-agent/last-verify.json"
else
  echo "verify: RED — failing tier(s): ${failing[*]} (of: $cmd_label) tree=${tree:0:12} → .coding-agent/last-verify.json"
fi
exit $agg_code
