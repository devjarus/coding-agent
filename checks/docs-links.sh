#!/usr/bin/env bash
# docs-links — close-out gate for the committed project documentation set
# (README / AGENTS / PRODUCT / DESIGN / docs/architecture / docs/dataflow /
# docs/index / deployment). Verifies three things the no-duplication doc
# standard depends on:
#   1. PRESENCE   — the applicable committed docs exist (DESIGN only for UI
#                   projects; deployment only when CI config exists).
#   2. CROSS-LINK — every relative Markdown link resolves to a real file, so
#                   the link-not-copy mechanic never points at nothing.
#   3. PORTABILITY — no committed doc leaks plugin-runtime state
#                   (.coding-agent/, CLAUDE_PLUGIN_ROOT, coding-agent:) or a
#                   committed secret in deployment.md. This is what lets a
#                   different agent (no plugin) use the set unchanged.
#
# Usage: docs-links.sh <repo_root>
# Full close-out only; touch-up / micro skip it.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

NAME="docs-links"
REPO="${1:-$PWD}"

fails=()

# ---- 1. Presence -----------------------------------------------------------
required=(README.md AGENTS.md PRODUCT.md docs/architecture.md docs/dataflow.md docs/index.md)
for d in "${required[@]}"; do
  [[ -f "$REPO/$d" ]] || fails+=("missing required doc: $d (see project-docs skill)")
done

# DESIGN.md only when the project has a UI.
ui="$(detect_ui "$REPO")"
if [[ -n "$ui" && ! -f "$REPO/DESIGN.md" ]]; then
  fails+=("missing DESIGN.md — project has a $ui UI, so a design system doc is required")
fi

# deployment.md only when CI config exists (otherwise it has nothing to describe yet).
if { [[ -d "$REPO/.github/workflows" ]] || [[ -f "$REPO/.gitlab-ci.yml" ]] || [[ -f "$REPO/bitbucket-pipelines.yml" ]]; } && [[ ! -f "$REPO/deployment.md" ]]; then
  fails+=("missing deployment.md — CI config exists but the deploy procedure is undocumented")
fi

# ---- collect the committed docs that actually exist ------------------------
candidates=(README.md AGENTS.md PRODUCT.md DESIGN.md deployment.md docs/architecture.md docs/dataflow.md docs/index.md)
present=()
for d in "${candidates[@]}"; do
  [[ -f "$REPO/$d" ]] && present+=("$d")
done

# ---- 2. Cross-link integrity ----------------------------------------------
# Every relative Markdown link target must resolve to a real file.
for doc in ${present[@]+"${present[@]}"}; do
  docdir="$(dirname "$REPO/$doc")"
  # Extract link targets: ](target) — strip the ]( and trailing ).
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    # Skip external + anchors-only + mail.
    case "$target" in
      http://*|https://*|mailto:*|\#*) continue ;;
    esac
    # Drop an optional link title (`[x](path "Title")`) — everything from the
    # first whitespace — then any #anchor suffix and surrounding whitespace.
    path="${target%%[[:space:]]*}"
    path="${path%%#*}"
    path="${path## }"; path="${path%% }"
    [[ -z "$path" ]] && continue
    # Resolve relative to the doc's directory.
    if [[ -e "$docdir/$path" ]]; then
      continue
    fi
    fails+=("$doc: broken cross-link → $target (target does not exist)")
  done < <(grep -oE '\]\([^)]+\)' "$REPO/$doc" 2>/dev/null | sed -E 's/^\]\(//; s/\)$//')
done

# ---- 3. Portability: no plugin-runtime leakage in committed bodies ---------
leak_patterns=('\.coding-agent' 'CLAUDE_PLUGIN_ROOT' 'coding-agent:')
for doc in ${present[@]+"${present[@]}"}; do
  for pat in "${leak_patterns[@]}"; do
    if grep -nE "$pat" "$REPO/$doc" >/dev/null 2>&1; then
      hit="$(grep -nE "$pat" "$REPO/$doc" 2>/dev/null | head -1)"
      fails+=("$doc: leaks plugin-runtime reference ('$pat') — committed docs must be portable to any agent. Line: ${hit}")
    fi
  done
done

# ---- 3b. No committed secret in deployment.md ------------------------------
# A long assigned value next to a secret-ish key = a secret that should never
# be committed. Conservative: requires a secret keyword AND a long value.
if [[ -f "$REPO/deployment.md" ]]; then
  if grep -nEi '(secret|password|api[_-]?key|token|private[_-]?key)[^=]{0,20}=[[:space:]]*["'"'"']?[A-Za-z0-9_./+-]{12,}' "$REPO/deployment.md" >/dev/null 2>&1; then
    fails+=("deployment.md: looks like it contains a committed secret value — deployment.md holds procedure, never secrets/values")
  fi
fi

# ---- verdict ---------------------------------------------------------------
if [[ ${#fails[@]} -gt 0 ]]; then
  reason="$(printf '%s; ' "${fails[@]}")"
  emit_fail "$NAME" "${reason%; }"
  exit 1
fi

emit_pass "$NAME"
