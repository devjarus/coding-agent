#!/usr/bin/env bash
# test-infra-declared — spec.md ## Test Infrastructure is actually filled in:
# at least one data row, and every row names both a Dep and a Tool (no half-filled
# rows left from the template). Fires after draft, before the user-approval prompt.
#
# Column order from spec.template.md: | Dep | Tool | Why | Source consulted |
# Usage: ./checks/test-infra-declared.sh [repo_root]   exits 0 ok / 1 fail, JSON stdout.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

NAME="test-infra-declared"
REPO="${1:-$PWD}"
DIR=$(resolve_feature_dir "$REPO")
[[ -z "$DIR" ]] && { emit_fail "$NAME" "no active feature"; exit 1; }

SPEC="$DIR/spec.md"
[[ -f "$SPEC" ]] || { emit_fail "$NAME" "spec.md missing"; exit 1; }

grep -qF "## Test Infrastructure" "$SPEC" || { emit_fail "$NAME" "missing ## Test Infrastructure section"; exit 1; }

result=$(awk '
  /^## Test Infrastructure[[:space:]]*$/ { in_sec=1; next }
  in_sec && /^## / { in_sec=0 }
  in_sec && /^\|/ {
    if ($0 ~ /^\|[[:space:]]*-+/) next            # separator row
    n=split($0, f, "|")
    dep=f[2]; tool=f[3]
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", dep)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", tool)
    if (dep=="Dep") next                          # header row
    if (dep=="") next                             # blank/template row
    data++
    if (tool=="") print "BAD\t" dep
  }
  END { print "DATA\t" data+0 }
' "$SPEC")

data=$(printf '%s\n' "$result" | awk -F'\t' '$1=="DATA"{print $2}')
bad=$(printf '%s\n' "$result" | awk -F'\t' '$1=="BAD"{print $2}' | paste -sd';' - | sed 's/;/; /g')

if [[ "${data:-0}" -eq 0 ]]; then
  emit_fail "$NAME" "## Test Infrastructure has no entries — declare a test tool per external dep"
  exit 1
fi
if [[ -n "$bad" ]]; then
  emit_fail "$NAME" "Test Infrastructure deps with no test Tool declared: $bad"
  exit 1
fi

emit_pass "$NAME"
