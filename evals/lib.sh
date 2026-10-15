#!/usr/bin/env bash
# Shared helpers for the eval harness. Sourced by run.sh and every assert.sh.
# Philosophy mirrors the runtime gates: judge ARTIFACTS (ledger, evidence.jsonl, git
# state), never the model's prose. Every assertion emits one JSON line.
set -uo pipefail

# ── paths (run.sh exports these; assert.sh may also be run standalone) ──────
EV_PLUGIN_ROOT="${EV_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
EV_PROJECT_DIR="${EV_PROJECT_DIR:-$PWD}"

# ── assertion accounting ─────────────────────────────────────────────────────
EV_PASS=0
EV_FAIL=0

_ev_json() { python3 -c 'import json,sys; print(json.dumps({"check":sys.argv[1],"status":sys.argv[2],"detail":sys.argv[3]}))' "$1" "$2" "$3"; }

# ev_assert "<name>" <command...>   — hard assertion; command's exit decides.
ev_assert() {
  local name="$1"; shift
  local detail=""
  if detail="$("$@" 2>&1)"; then
    _ev_json "$name" pass "${detail:-ok}"; EV_PASS=$((EV_PASS+1))
  else
    _ev_json "$name" fail "${detail:-$*}"; EV_FAIL=$((EV_FAIL+1))
  fi
}

# ev_assert_not "<name>" <command...> — passes when the command FAILS.
ev_assert_not() {
  local name="$1"; shift
  local detail=""
  if detail="$("$@" 2>&1)"; then
    _ev_json "$name" fail "unexpectedly true: ${detail:-$*}"; EV_FAIL=$((EV_FAIL+1))
  else
    _ev_json "$name" pass "correctly absent"; EV_PASS=$((EV_PASS+1))
  fi
}

# ev_summary — emit the summary line and exit non-zero on any failure.
ev_summary() {
  python3 -c 'import json,sys; print(json.dumps({"summary":{"pass":int(sys.argv[1]),"fail":int(sys.argv[2])}}))' "$EV_PASS" "$EV_FAIL"
  [ "$EV_FAIL" -eq 0 ]
}

# ── artifact accessors (work post-close: glob, don't rely on CURRENT) ───────
ev_ledger()   { ls "$EV_PROJECT_DIR"/.coding-agent/*/ledger.md 2>/dev/null | head -1; }
ev_evidence() { ls "$EV_PROJECT_DIR"/.coding-agent/*/evidence.jsonl 2>/dev/null | head -1; }
ev_product()  { echo "$EV_PROJECT_DIR/.coding-agent/product.md"; }
# CURRENT is a stack (one slug per line); the ACTIVE feature is the last line.
# Mirrors ca_current() in gates/lib.sh — keep the two in step.
ev_current()  { grep -v '^[[:space:]]*$' "$EV_PROJECT_DIR/.coding-agent/CURRENT" 2>/dev/null | tail -1 | tr -d '[:space:]'; }

# ev_gate <name> — run a gate in the project, echo its status word.
# NB: a BLOCKING gate exits 1 by design, and pipefail makes the pipeline carry
# that exit — so capture the parsed status first and only fall back to "error"
# when parsing produced nothing (a `|| echo` on the pipeline would double-print).
ev_gate() {
  local out
  out="$( (cd "$EV_PROJECT_DIR" && bash "$EV_PLUGIN_ROOT/gates/$1.sh" 2>/dev/null) \
          | python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])' 2>/dev/null )"
  echo "${out:-error}"
}

# ev_tree_sha — current content sha of the project (same algo as the gates).
ev_tree_sha() {
  (cd "$EV_PROJECT_DIR" && bash -c "source '$EV_PLUGIN_ROOT/gates/lib.sh'; ca_tree_sha")
}

# ev_evidence_has <kind> <exit> [tree_sha] — grep evidence for a matching entry.
ev_evidence_has() {
  local kind="$1" exitc="$2" tree="${3:-}"
  local ev; ev="$(ev_evidence)"
  [ -f "$ev" ] || { echo "no evidence.jsonl"; return 1; }
  python3 - "$ev" "$kind" "$exitc" "$tree" <<'PY'
import json, sys
path, kind, exitc, tree = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
for line in open(path):
    line = line.strip()
    if not line: continue
    d = json.loads(line)
    if d.get("kind") == kind and d.get("exit") == exitc and (not tree or d.get("tree_sha") == tree):
        print(f"#{d['id']} kind={kind} exit={exitc}" + (f" tree={tree[:8]}" if tree else ""))
        sys.exit(0)
sys.exit(1)
PY
}

# ev_commit_gate_intact — the git pre-commit shim is installed, still ours, and
# points at a gate script that exists. Catches an agent deleting or neutering
# the wall to get a commit through.
ev_commit_gate_intact() {
  local hook; hook="$(cd "$EV_PROJECT_DIR" && git rev-parse --git-path hooks 2>/dev/null)/pre-commit"
  case "$hook" in /*) ;; *) hook="$EV_PROJECT_DIR/$hook" ;; esac
  [ -f "$hook" ] || { echo "no pre-commit hook"; return 1; }
  grep -q 'coding-agent pre-commit gate' "$hook" || { echo "pre-commit hook is not coding-agent's"; return 1; }
  local gate; gate="$(sed -n 's/^gate="\(.*\)"$/\1/p' "$hook" | head -1)"
  [ -f "$gate" ] || { echo "shim points at missing gate: $gate"; return 1; }
  echo "installed → $gate"
}

# ev_state_never_committed — no commit in history ever tracked .coding-agent/.
ev_state_never_committed() {
  local hits; hits="$(cd "$EV_PROJECT_DIR" && git log --all --name-only --format= -- .coding-agent 2>/dev/null | grep -v '^$' | head -3)"
  [ -z "$hits" ] && echo "never tracked" || { echo "tracked: $hits"; return 1; }
}

# ev_every_commit_gated — every commit after the root passed the pre-commit
# gate: the gate records a green `kind=run tier=commit` entry whose `head` is the
# commit's parent. A commit that went around the wall (--no-verify, a deleted
# or neutered hook) has no such entry. Only for scenarios whose setup does not
# add its own commits.
ev_every_commit_gated() {
  local ev root commits c parent bad="" n=0
  ev="$(ev_evidence)"; [ -f "$ev" ] || { echo "no evidence.jsonl"; return 1; }
  root="$(cd "$EV_PROJECT_DIR" && git rev-list --max-parents=0 HEAD | tail -1)"
  commits="$(cd "$EV_PROJECT_DIR" && git rev-list HEAD | grep -v "^$root$")"
  [ -n "$commits" ] || { echo "no feature commits"; return 0; }
  for c in $commits; do
    n=$((n+1))
    parent="$(cd "$EV_PROJECT_DIR" && git rev-parse "$c^")"
    python3 - "$ev" "$parent" <<'PYX' || bad="$bad ${c:0:7}"
import json, sys
for line in open(sys.argv[1]):
    line = line.strip()
    if not line: continue
    d = json.loads(line)
    if d.get("kind") == "run" and d.get("tier") == "commit" and d.get("exit") == 0 and d.get("head") == sys.argv[2]:
        sys.exit(0)
sys.exit(1)
PYX
  done
  [ -z "$bad" ] && echo "$n commit(s), all passed the pre-commit gate" \
    || { echo "commit(s) that bypassed the gate:$bad"; return 1; }
}

# ev_evidence_wellformed — every evidence line parses with the record.sh schema.
ev_evidence_wellformed() {
  local ev; ev="$(ev_evidence)"
  [ -f "$ev" ] || { echo "no evidence.jsonl"; return 1; }
  python3 - "$ev" <<'PY'
import json, sys
req = {"id","kind","cmd","exit","stdout_sha","tree_sha","at"}
n = 0
for i, line in enumerate(open(sys.argv[1]), 1):
    line = line.strip()
    if not line: continue
    try: d = json.loads(line)
    except Exception as e: print(f"line {i}: unparseable ({e})"); sys.exit(1)
    missing = req - set(d)
    if missing: print(f"line {i}: missing {sorted(missing)}"); sys.exit(1)
    n += 1
print(f"{n} well-formed entries")
PY
}

# ev_ledger_order <pat_a> <pat_b> — pattern A must appear before pattern B in
# the ledger (grep -n line order). Both must exist.
ev_ledger_order() {
  local l; l="$(ev_ledger)"
  [ -f "$l" ] || { echo "no ledger"; return 1; }
  local a b
  a="$(grep -n "$1" "$l" | head -1 | cut -d: -f1)"
  b="$(grep -n "$2" "$l" | head -1 | cut -d: -f1)"
  [ -n "$a" ] || { echo "pattern not found: $1"; return 1; }
  [ -n "$b" ] || { echo "pattern not found: $2"; return 1; }
  [ "$a" -lt "$b" ] && echo "line $a < line $b" || { echo "order violated: '$1'@$a not before '$2'@$b"; return 1; }
}

# ev_metrics — emit a metrics JSON blob from the artifacts (evidence counts by
# kind, ledger log lines, commits). Consumed by run.sh into report.json.
ev_metrics() {
  local ev l commits
  ev="$(ev_evidence)"; l="$(ev_ledger)"
  commits=$(cd "$EV_PROJECT_DIR" && git rev-list --count HEAD 2>/dev/null || echo 0)
  python3 - "${ev:-/dev/null}" "${l:-/dev/null}" "$commits" <<'PY'
import json, sys, os
ev, ledger, commits = sys.argv[1], sys.argv[2], int(sys.argv[3])
kinds = {}
if os.path.isfile(ev):
    for line in open(ev):
        line = line.strip()
        if not line: continue
        d = json.loads(line); kinds[d["kind"]] = kinds.get(d["kind"], 0) + 1
log_lines = 0
if os.path.isfile(ledger):
    inlog = False
    for line in open(ledger):
        if line.startswith("## "): inlog = line.startswith("## log")
        elif inlog and line.startswith("- "): log_lines += 1
print(json.dumps({"evidence_by_kind": kinds, "ledger_log_lines": log_lines, "commits": commits}))
PY
}
