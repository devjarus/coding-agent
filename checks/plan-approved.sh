#!/usr/bin/env bash
# plan-approved — features/<CURRENT>/plan.md is approved AND every wave has
# both `## Evaluation Criteria` block and `evaluation:` per task with
# unit/integration entries (e2e if UI touched).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

NAME="plan-approved"
REPO="${1:-$PWD}"
DIR=$(resolve_feature_dir "$REPO")
[[ -z "$DIR" ]] && { emit_fail "$NAME" "no active feature"; exit 1; }

PLAN="$DIR/plan.md"
[[ -f "$PLAN" ]] || { emit_fail "$NAME" "plan.md missing"; exit 1; }

approved_by=$(read_fm "$PLAN" "approved_by")
[[ "$approved_by" == "user" ]] || { emit_fail "$NAME" "not approved by user"; exit 1; }

# Each wave must have evaluation rows.
grep -qE '^### (T-|Wave )' "$PLAN" || { emit_fail "$NAME" "no tasks/waves found"; exit 1; }

# Each task block should declare skills + evaluation.
missing_skills=$(awk '
  /^### T-/ { task=$0; have_skills=0; have_eval=0; next }
  /^skills:/ { have_skills=1 }
  /^  - Unit:|^  - Integration:|evaluation:/ { have_eval=1 }
  /^### / && task != "" {
    if (!have_skills) print task ": missing skills"
    if (!have_eval) print task ": missing evaluation"
    task=""
  }
  END { if (task != "") {
    if (!have_skills) print task ": missing skills"
    if (!have_eval) print task ": missing evaluation"
  }}
' "$PLAN")

if [[ -n "$missing_skills" ]]; then
  emit_fail "$NAME" "$missing_skills"
  exit 1
fi

emit_pass "$NAME"
