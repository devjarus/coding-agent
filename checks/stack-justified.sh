#!/usr/bin/env bash
# stack-justified — spec.md ## Tech Stack documents tradeoffs: every data row
# fills the Alternatives column with either a real alternative OR an explicit
# "sole option — <reason>". Enforces deliberateness (you considered tradeoffs),
# not variety. Fires after draft, before the user-approval prompt.
#
# Column order from spec.template.md: | Area | Chosen | Alternatives | Why |
# Usage: ./checks/stack-justified.sh [repo_root]   exits 0 ok / 1 fail, JSON stdout.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

NAME="stack-justified"
REPO="${1:-$PWD}"
DIR=$(resolve_feature_dir "$REPO")
[[ -z "$DIR" ]] && { emit_fail "$NAME" "no active feature"; exit 1; }

SPEC="$DIR/spec.md"
[[ -f "$SPEC" ]] || { emit_fail "$NAME" "spec.md missing"; exit 1; }

grep -qF "## Tech Stack" "$SPEC" || { emit_fail "$NAME" "missing ## Tech Stack section"; exit 1; }

result=$(awk '
  /^## Tech Stack[[:space:]]*$/ { in_sec=1; next }
  in_sec && /^## / { in_sec=0 }
  in_sec && /^\|/ {
    if ($0 ~ /^\|[[:space:]]*-+/) next            # separator row
    n=split($0, f, "|")
    chosen=f[3]; alt=f[4]; area=f[2]
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", chosen)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", alt)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", area)
    if (chosen=="Chosen") next                    # header row
    if (chosen=="") next                          # blank/template row
    data++
    if (alt=="") print "BAD\t" (area=="" ? "(unnamed row)" : area)
  }
  END { print "DATA\t" data+0 }
' "$SPEC")

data=$(printf '%s\n' "$result" | awk -F'\t' '$1=="DATA"{print $2}')
bad=$(printf '%s\n' "$result" | awk -F'\t' '$1=="BAD"{print $2}' | paste -sd';' - | sed 's/;/; /g')

if [[ "${data:-0}" -eq 0 ]]; then
  emit_fail "$NAME" "## Tech Stack has no entries — declare the chosen stack with tradeoffs"
  exit 1
fi
if [[ -n "$bad" ]]; then
  emit_fail "$NAME" "Tech Stack rows missing Alternatives (give an alternative, or write 'sole option — <reason>'): $bad"
  exit 1
fi

emit_pass "$NAME"
