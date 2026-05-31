#!/usr/bin/env bash
# tests-actually-committed — ground-truth gate against fabricated progress.
#
# Ties a "wave complete" / commit claim to the git working tree. A wave cannot
# ADVANCE, and a commit cannot proceed, unless the artifacts the Implementor
# claimed it wrote actually exist on disk and the working tree shows real change.
#
# This is the safeguard the validator surfaces as a phantom reference. It runs
# in TWO modes (project-agnostic — no language/test-runner assumptions):
#
#   wave  (default): invoked by the orchestrator BEFORE it logs `dispatch-returned`
#                    and BEFORE it advances to the next wave. Asserts that the
#                    files listed in work.md § Tasks for the just-returned wave
#                    are tracked-or-modified in git, i.e. real work landed.
#
#   commit:          invoked at the commit gate, BEFORE the diff is shown for
#                    approval. Asserts `git` sees staged-or-unstaged changes
#                    (the diff cannot be empty if a feature was implemented).
#
# Usage:
#   tests-actually-committed.sh <repo_root> wave   <path1> [path2 ...]
#   tests-actually-committed.sh <repo_root> commit
#
# In `wave` mode the orchestrator passes the artifacts_written paths from the
# Implementor's return: block as the trailing args (verbatim — derive, don't
# re-type). The check verifies the CLAIM against ground truth.
#
# Exit 0 + {"ok":true}   when ground truth backs the claim.
# Exit 1 + {"ok":false}  when the claim is fabricated (empty tree / missing files).
#         A non-zero exit MUST block the orchestrator: do not log dispatch-returned,
#         do not mark the wave complete, do not commit.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

NAME="tests-actually-committed"
REPO="${1:-$PWD}"
MODE="${2:-wave}"
shift 2 2>/dev/null || shift $# 2>/dev/null || true

cd "$REPO" 2>/dev/null || { emit_fail "$NAME" "not a directory: $REPO"; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { emit_fail "$NAME" "not a git repository: $REPO"; exit 1; }

# ── commit mode: the working set cannot be empty ────────────────────
# Catches the incident's terminal symptom: orchestrator narrates five commits
# with test counts while `git commit` reports "nothing to commit, clean tree".
if [[ "$MODE" == "commit" ]]; then
  # Exclude .coding-agent/ — coordinator-state churn (session.md, work.md, CURRENT)
  # is NOT "real work landed". Without this, a clean SOURCE tree passes whenever
  # .coding-agent/ isn't gitignored (fresh project pre-setup) — re-enabling the
  # exact "commit against a clean tree" fabrication this check exists to stop.
  staged=$(git diff --cached --name-only -- . ':(exclude).coding-agent' 2>/dev/null)
  unstaged=$(git diff --name-only -- . ':(exclude).coding-agent' 2>/dev/null)
  untracked=$(git ls-files --others --exclude-standard -- . ':(exclude).coding-agent' 2>/dev/null)
  if [[ -z "$staged$unstaged$untracked" ]]; then
    emit_fail "$NAME" "commit claimed but no source changes — working tree clean (excluding .coding-agent/). Nothing was implemented."
    exit 1
  fi
  emit_pass "$NAME"
  exit 0
fi

# ── wave mode: the claimed artifacts must exist and be real to git ──
# The orchestrator passes artifacts_written verbatim. Empty list with a
# "complete" claim is itself a fabrication signal (the incident's root: the
# Implementor returned "repo is empty", yet the wave was marked complete).
CLAIMED=("$@")
if [[ ${#CLAIMED[@]} -eq 0 ]]; then
  emit_fail "$NAME" "wave marked complete but Implementor returned zero artifacts_written. Cannot advance on an empty return."
  exit 1
fi

missing=()
ungit=()
for f in "${CLAIMED[@]}"; do
  [[ -z "$f" ]] && continue
  # Ground truth #1: the claimed path exists on disk.
  if [[ ! -e "$REPO/$f" && ! -e "$f" ]]; then
    missing+=("$f")
    continue
  fi
  # Ground truth #2: git sees the path as CHANGED THIS CYCLE (added/modified/
  # untracked). Merely being tracked-and-unchanged does NOT count — otherwise a
  # fabricated return could name any pre-existing file (e.g. README.md) and pass.
  # The wave check runs before commit, so real new work shows in `git status`.
  rel="$f"
  if git status --porcelain -- "$rel" 2>/dev/null | grep -q .; then
    :                                                   # added/modified/untracked this cycle — real
  else
    ungit+=("$f")
  fi
done

if [[ ${#missing[@]} -gt 0 || ${#ungit[@]} -gt 0 ]]; then
  reason=""
  [[ ${#missing[@]} -gt 0 ]] && reason+="claimed artifacts not on disk: ${missing[*]}; "
  [[ ${#ungit[@]} -gt 0 ]]   && reason+="claimed artifacts not visible to git: ${ungit[*]}; "
  reason="${reason%; }"
  emit_fail "$NAME" "$reason"
  exit 1
fi

emit_pass "$NAME"
exit 0
