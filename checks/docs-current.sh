#!/usr/bin/env bash
# docs-current — close-out gate ensuring the repo's human-facing README.md
# describes the actual app, not a framework scaffold. Fails if README.md is
# missing, still matches a known scaffold fingerprint (Vite / CRA / Next /
# Astro / SvelteKit), or is byte-identical to the version first committed while
# real source work has since landed. Catches the "shipped a repo whose front
# page is still 'This template provides a minimal setup'" failure.
#
# Usage: docs-current.sh <repo_root>
# Full close-out only; touch-up / micro skip it (they don't establish docs).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

NAME="docs-current"
REPO="${1:-$PWD}"
README="$REPO/README.md"

# 1. README must exist.
if [[ ! -f "$README" ]]; then
  emit_fail "$NAME" "README.md missing at repo root — generate a real one (see project-docs skill) before close-out"
  exit 1
fi

# 2. Scaffold fingerprints. Any match = the boilerplate was never replaced.
#    Keep in sync with skills/practices/project-docs/SKILL.md § Replace scaffold READMEs.
FINGERPRINTS=(
  "This template provides a minimal setup"          # Vite (React/Vue/etc.)
  "Currently, two official plugins are available"   # Vite React
  "Getting Started with Create React App"           # CRA
  "bootstrapped with [\`create-next-app\`]"          # Next.js
  "bootstrapped with \`create-next-app\`"            # Next.js (no link)
  "npm create svelte@latest"                        # SvelteKit
  "npm create astro@latest"                         # Astro
  "Welcome to your new Astro project"               # Astro
  "Everything you need to know is in the README"    # Astro placeholder
)
for fp in "${FINGERPRINTS[@]}"; do
  if grep -qF "$fp" "$README" 2>/dev/null; then
    emit_fail "$NAME" "README.md still contains scaffold boilerplate (\"$fp\") — replace it with a real project README before close-out"
    exit 1
  fi
done

# 3. Git staleness: README byte-identical to its first committed version while
#    >= 3 source commits landed since. Catches a scaffold README that doesn't
#    match a known fingerprint but was simply never touched. Skipped when git
#    is unavailable or README isn't tracked yet (fingerprint check above still ran).
if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
  add_commit="$(git -C "$REPO" log --diff-filter=A --format=%H -- README.md 2>/dev/null | tail -1)"
  if [[ -n "$add_commit" ]]; then
    first_blob="$(git -C "$REPO" rev-parse "$add_commit:README.md" 2>/dev/null || echo "")"
    head_blob="$(git -C "$REPO" rev-parse "HEAD:README.md" 2>/dev/null || echo "")"
    if [[ -n "$first_blob" && "$first_blob" == "$head_blob" ]]; then
      # README never changed since it was added. Count source commits since then,
      # excluding README itself, docs, and coordinator state.
      src_commits="$(git -C "$REPO" rev-list --count "$add_commit..HEAD" -- . \
        ':(exclude)README.md' ':(exclude).coding-agent' ':(exclude)docs' 2>/dev/null || echo 0)"
      if [[ "${src_commits:-0}" -ge 3 ]]; then
        emit_fail "$NAME" "README.md is unchanged since it was first committed while $src_commits source commits landed — likely stale scaffold; refresh it before close-out"
        exit 1
      fi
    fi
  fi
fi

emit_pass "$NAME"
