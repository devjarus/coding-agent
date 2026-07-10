#!/usr/bin/env bash
# Shared helpers for gates, record.sh, and ledger.sh.
# Source this; do not execute. Intentionally NO `set -e` (grep no-match is fine).
set -uo pipefail

ca_root()    { git rev-parse --show-toplevel 2>/dev/null || pwd; }
ca_dir()     { echo "$(ca_root)/.coding-agent"; }
ca_current() { local f="$(ca_dir)/CURRENT"; [ -f "$f" ] && tr -d '[:space:]' < "$f" || echo ""; }
ca_feature_dir() { echo "$(ca_dir)/${1:-$(ca_current)}"; }
ca_ledger()   { echo "$(ca_feature_dir "${1:-}")/ledger.md"; }
ca_evidence() { echo "$(ca_feature_dir "${1:-}")/evidence.jsonl"; }
ca_product()  { echo "$(ca_dir)/product.md"; }

# JSON-escape a string (python if present, crude fallback otherwise).
json_str() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1" 2>/dev/null \
    || printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
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

# A stable hash of the working tree state (git diff vs HEAD + untracked),
# or a content hash when not in a git repo. Never mutates the index.
ca_tree_sha() {
  if git rev-parse HEAD >/dev/null 2>&1; then
    { git rev-parse HEAD
      git diff HEAD
      git ls-files --others --exclude-standard -z -- ':(exclude).coding-agent/' \
        | xargs -0 cat 2>/dev/null
    } | shasum -a 256 | cut -d' ' -f1
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
