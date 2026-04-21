#!/usr/bin/env bash
# ui-evidence — for UI projects, features/<CURRENT>/screenshots/ has named PNGs
# AND review.md mentions a Screenshots section. Skipped for non-UI projects.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

NAME="ui-evidence"
REPO="${1:-$PWD}"

ui=$(detect_ui "$REPO")
if [[ -z "$ui" ]]; then
  emit_pass "$NAME"; exit 0
fi

DIR=$(resolve_feature_dir "$REPO")
[[ -z "$DIR" ]] && { emit_fail "$NAME" "UI project but no active feature"; exit 1; }

SHOTS="$DIR/screenshots"
if [[ ! -d "$SHOTS" ]]; then
  emit_fail "$NAME" "UI project but screenshots/ missing"
  exit 1
fi

count=$(find "$SHOTS" -maxdepth 1 -name "*.png" | wc -l | tr -d '[:space:]')
if [[ "$count" -lt 1 ]]; then
  emit_fail "$NAME" "screenshots/ contains no PNGs"
  exit 1
fi

# Reject anonymous filenames like screenshot1.png / screen.png
bad=$(find "$SHOTS" -maxdepth 1 -name "*.png" | grep -E '/(screenshot|image|page)[0-9]*\.png$' || true)
if [[ -n "$bad" ]]; then
  emit_fail "$NAME" "screenshots have non-descriptive names: $bad"
  exit 1
fi

REVIEW="$DIR/review.md"
if [[ -f "$REVIEW" ]] && ! grep -qF "## Screenshots" "$REVIEW"; then
  emit_fail "$NAME" "review.md missing ## Screenshots section"
  exit 1
fi

emit_pass "$NAME"
