#!/usr/bin/env bash
# Shared helpers for gates, record.sh, and ledger.sh.
# Source this; do not execute. Intentionally NO `set -e` (grep no-match is fine).
set -uo pipefail

# The MAIN worktree root — where the single .coding-agent/ ledger lives. Uses
# --git-common-dir (shared by all linked worktrees) so a `build` worker running
# in an isolated worktree records evidence into the main repo's evidence.jsonl,
# which the conductor's gates read. Falls back to show-toplevel, then pwd.
ca_root() {
  local cdir
  if cdir="$(git rev-parse --git-common-dir 2>/dev/null)" && [ -n "$cdir" ]; then
    cdir="$(cd "$cdir" 2>/dev/null && pwd)"   # absolutize (can be relative ".git")
    case "$cdir" in */.git) echo "${cdir%/.git}" ; return ;; esac
  fi
  git rev-parse --show-toplevel 2>/dev/null || pwd
}
ca_dir()     { echo "$(ca_root)/.coding-agent"; }
# CURRENT is a stack (one slug per line); the ACTIVE feature is the last line.
# Earlier lines are features the active one interrupted, resumed on close.
ca_current() {
  local f="$(ca_dir)/CURRENT"
  [ -f "$f" ] || { echo ""; return; }
  grep -v '^[[:space:]]*$' "$f" 2>/dev/null | tail -1 | tr -d '[:space:]'
}
ca_feature_dir() { echo "$(ca_dir)/${1:-$(ca_current)}"; }
ca_ledger()   { echo "$(ca_feature_dir "${1:-}")/ledger.md"; }
ca_evidence() { echo "$(ca_feature_dir "${1:-}")/evidence.jsonl"; }
ca_product()  { echo "$(ca_dir)/product.md"; }

# JSON-escape a string (python if present, crude fallback otherwise).
json_str() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1" 2>/dev/null \
    || printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
}

# Validate one artifact against the browser design-review verdict. A present
# verdict is strict: malformed JSON, open comments, a missing digest, or changed
# bytes all return a reason. The caller treats any non-empty reason as failure.
verify_design_verdict() { # feature_dir artifact_file verdict_key
  local dir="$1" artifact="$2" key="$3" vfile="$1/design-verdict.json"
  [ -f "$vfile" ] || { echo "no design-verdict.json"; return 0; }
  command -v python3 >/dev/null 2>&1 || {
    echo "python3 is required for strict design-verdict verification"; return 0;
  }
  python3 - "$vfile" "$dir/$artifact" "$artifact" "$key" <<'PY'
import hashlib, json, os, sys
vfile, path, artifact, key = sys.argv[1:]
try:
    with open(vfile, encoding="utf-8") as f:
        verdict = json.load(f)
except (OSError, ValueError) as exc:
    print("cannot parse design-verdict.json: %s" % exc)
    raise SystemExit(0)
if verdict.get("verdict") != "approved":
    print("design-verdict.json is not approved")
    raise SystemExit(0)
if verdict.get("comments_open") != 0:
    print("design-verdict.json is missing a zero-open-comments proof")
    raise SystemExit(0)
recorded = verdict.get(key)
if not isinstance(recorded, str) or len(recorded) != 64:
    print("design-verdict.json is missing a valid %s for %s" % (key, artifact))
    raise SystemExit(0)
if not os.path.isfile(path):
    print("approved artifact is missing: %s" % artifact)
    raise SystemExit(0)
h = hashlib.sha256()
with open(path, "rb") as f:
    for chunk in iter(lambda: f.read(65536), b""):
        h.update(chunk)
actual = h.hexdigest()
if recorded != actual:
    print("%s changed after approval (verdict %s, current %s)" %
          (artifact, recorded[:8], actual[:8]))
PY
}

# Emit a gate verdict as one JSON line and set the exit code.
# Usage: GATE_NAME=foo ; gate_result pass|block|n/a "reason"
gate_result() {
  local status="$1" reason="${2:-}"
  printf '{"gate":"%s","status":"%s","reason":%s}\n' "${GATE_NAME:-?}" "$status" "$(json_str "$reason")"
  case "$status" in pass|n/a) exit 0 ;; *) exit 1 ;; esac
}

# Print the body of a markdown section "## <name> ..." up to the next "## ".
ledger_section() { # file name
  [ -f "$1" ] || return 0
  awk -v h="$2" '
    $0 ~ "^## "h {f=1; next}
    /^## / {f=0}
    f {print}
  ' "$1"
}

# Strip HTML comment blocks so gates never match example/instruction text in
# templates. Frozen markers are blockquotes (> ...), not comments, so they survive.
strip_comments() { perl -0777 -pe 's/<!--.*?-->//gs' 2>/dev/null || sed '/<!--/,/-->/d'; }

# A stable hash of the working-tree CONTENT (tracked + untracked, excluding
# .coding-agent/), or a content hash when not in a git repo. Never mutates the
# index.
#
# Content-only by design: hashing `rev-parse HEAD` + `git diff HEAD` rotates the
# sha on a byte-identical commit (HEAD moves, the diff empties), which silently
# invalidates every tree-bound proof across the natural prove → commit → ship
# walk. Per-file digests over `ls-files -co` are invariant across both `git add`
# and `git commit` and still change on any real edit or rename (the path rides
# in each shasum line). The while-loop (vs `xargs`) is hang-safe on empty input
# and skips staged-but-deleted paths.
ca_tree_sha() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files -co --exclude-standard -z -- ':(exclude).coding-agent/' \
      | sort -z \
      | while IFS= read -r -d '' f; do [ -f "$f" ] && shasum -a 256 "$f"; done \
      | shasum -a 256 | cut -d' ' -f1
  else
    find "$(ca_root)" -type f -not -path '*/.git/*' -not -path '*/.coding-agent/*' -print0 2>/dev/null \
      | sort -z | xargs -0 cat 2>/dev/null | shasum -a 256 | cut -d' ' -f1
  fi
}

# Latest evidence line matching a kind, exit 0, and the current tree sha.
evidence_match() { # kind  [tree_sha]
  local ev kind tree
  ev="$(ca_evidence)"; kind="$1"; tree="${2:-$(ca_tree_sha)}"
  [ -f "$ev" ] || return 1
  grep "\"kind\":\"$kind\"" "$ev" | grep '"exit":0' | grep "\"tree_sha\":\"$tree\"" | tail -1
}

# Same, but also pinned to a named tier. This is what makes `proven?` unable to
# accept one self-chosen command as proof of a multi-tier suite: a green `unit`
# entry cannot stand in for a missing `e2e` one: a green unit run while
# browser/e2e tiers are stale is a false pass.
evidence_match_tier() { # kind tier [tree_sha]
  local ev kind tier tree
  ev="$(ca_evidence)"; kind="$1"; tier="$2"; tree="${3:-$(ca_tree_sha)}"
  [ -f "$ev" ] || return 1
  grep "\"kind\":\"$kind\"" "$ev" | grep "\"tier\":\"$tier\"" | grep '"exit":0' \
    | grep "\"tree_sha\":\"$tree\"" | tail -1
}

# The verification tiers the intent declares, one per line.
# Source of truth is the intent's `tiers:` line (e.g. `tiers: typecheck, unit, e2e`).
declared_tiers() {
  ledger_section "$(ca_ledger)" intent | strip_comments \
    | grep -iE '^[[:space:]]*tiers:' | head -1 \
    | sed 's/^[[:space:]]*[Tt]iers:[[:space:]]*//' \
    | tr ',' '\n' | tr -d ' \t' | grep -v '^$'
}

# The exact user-approved command for one verification tier. The planner writes
# these into the frozen intent as `test-command-<tier>: <command>`. Binding proof
# to this map prevents a worker from relabeling an arbitrary green command as a
# required tier.
declared_test_command() { # tier
  local tier="$1"
  ledger_section "$(ca_ledger)" intent | strip_comments \
    | grep -iE "^[[:space:]]*test-command-${tier}:[[:space:]]*" | head -1 \
    | sed -E "s/^[[:space:]]*test-command-${tier}:[[:space:]]*//I"
}

# True when the intent's `touches:` list contains the given surface tag.
intent_touches() { # tag
  ledger_section "$(ca_ledger)" intent | strip_comments \
    | grep -qiE "^[[:space:]]*touches:.*\b$1\b"
}
