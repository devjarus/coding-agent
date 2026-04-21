#!/usr/bin/env bash
# close-out-complete — verifies all 8 close-out steps ran:
# (1) feature dir artifacts archived, (2) learnings.md has today's entry,
# (3) CURRENT cleared, (4) session.md updated this session, (5) no draft artifacts.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

NAME="close-out-complete"
REPO="${1:-$PWD}"
SLUG="${2:-}"  # the slug that was just closed

[[ -z "$SLUG" ]] && { emit_fail "$NAME" "must pass <repo> <slug>"; exit 1; }

DIR="$REPO/.coding-agent/features/$SLUG"
[[ -d "$DIR" ]] || { emit_fail "$NAME" "features/$SLUG not found"; exit 1; }

# 1. All artifacts archived
while IFS= read -r -d '' file; do
  state=$(read_fm "$file" "state")
  [[ -z "$state" ]] && continue
  if [[ "$state" != "archived" ]]; then
    emit_fail "$NAME" "$file is state=$state (expected archived)"
    exit 1
  fi
done < <(find "$DIR" -maxdepth 1 -name "*.md" -print0)

# 2. learnings.md has today's date heading
TODAY=$(date +%Y-%m-%d)
LEARN="$REPO/.coding-agent/learnings.md"
if [[ ! -f "$LEARN" ]] || ! grep -qF "## $TODAY" "$LEARN"; then
  emit_fail "$NAME" "learnings.md missing entry for $TODAY"
  exit 1
fi

# 3. CURRENT cleared
CURRENT="$REPO/.coding-agent/CURRENT"
if [[ -f "$CURRENT" ]] && [[ -n "$(tr -d '[:space:]' < "$CURRENT")" ]]; then
  emit_fail "$NAME" "CURRENT not cleared"
  exit 1
fi

# 4. session.md updated today
SESSION="$REPO/.coding-agent/session.md"
if [[ ! -f "$SESSION" ]] || ! grep -qF "$TODAY" "$SESSION"; then
  emit_fail "$NAME" "session.md not updated today"
  exit 1
fi

# 5. No draft artifacts in feature dir
while IFS= read -r -d '' file; do
  state=$(read_fm "$file" "state")
  if [[ "$state" == "draft" ]]; then
    emit_fail "$NAME" "$file still in draft state"
    exit 1
  fi
done < <(find "$DIR" -maxdepth 1 -name "*.md" -print0)

emit_pass "$NAME"
