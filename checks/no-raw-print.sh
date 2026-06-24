#!/usr/bin/env bash
# no-raw-print — production source files do not use console.log / print() etc.
# Tests and scripts/ are exempt.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

NAME="no-raw-print"
REPO="${1:-$PWD}"

# Files to scan: take from arg list (after repo) or default to git diff vs HEAD.
shift || true
files=("$@")
if [[ ${#files[@]} -eq 0 ]]; then
  while IFS= read -r f; do files+=("$f"); done < <(cd "$REPO" && git diff --name-only HEAD 2>/dev/null || true)
fi

[[ ${#files[@]} -eq 0 ]] && { emit_pass "$NAME"; exit 0; }

violations=""
for f in "${files[@]}"; do
  full="$REPO/$f"
  [[ -f "$full" ]] || continue
  case "$f" in
    test/*|tests/*|*.test.*|*.spec.*|*__tests__*|scripts/*|*.test.tsx) continue ;;
  esac
  # JS/TS console. Two-step: drop comment-only lines (first non-space chars are
  # `//` or a `*` JSDoc continuation), THEN match a real console.* call anywhere
  # on what remains. (The old single `^[^*//]*` class was a typo — `[^*/]` — that
  # exempted any line with a `/` before console, e.g. a string literal "a/b",
  # silently letting raw console calls through.) POSIX grep -E has no lookahead,
  # so comment-skip is a filter, not an inline anchor.
  if grep -vE '^[[:space:]]*(//|\*)' "$full" | grep -E 'console\.(log|error|warn|info|debug)\(' >/dev/null 2>&1; then
    violations+="$f"$'\n'
  fi
  # Python print — same two-step comment-skip shape (drop full-line `#` comments).
  case "$f" in
    *.py)
      if grep -vE '^[[:space:]]*#' "$full" | grep -E '\bprint\(' >/dev/null 2>&1; then
        violations+="$f"$'\n'
      fi
      ;;
  esac
  # Go fmt.Println
  case "$f" in
    *.go)
      if grep -nE 'fmt\.(Println|Printf|Print)\(' "$full" >/dev/null 2>&1; then
        violations+="$f"$'\n'
      fi
      ;;
  esac
done

if [[ -n "$violations" ]]; then
  emit_fail "$NAME" "raw print/console in production code: $violations"
  exit 1
fi

emit_pass "$NAME"
