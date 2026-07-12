#!/usr/bin/env bash
# ledger.sh — the conductor's safe primitives for the (single-writer) ledger.
#   ledger.sh init <slug>          create a feature ledger, set it active
#   ledger.sh product-init [name]  create the product ledger
#   ledger.sh tail [n]             show the last n lines of the active ledger
#   ledger.sh log "<msg>"          append a timestamped line under ## log
#   ledger.sh freeze <section>     stamp a section frozen+agreed (intent|plan)
#   ledger.sh revise <section> "why"  re-open a frozen section (append a revision marker)
#   ledger.sh close [--abandoned|--superseded]  roll up into product.md, clear CURRENT
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../gates/lib.sh"
ROOT="$(cd "$HERE/.." && pwd)"

cmd="${1:-help}"; shift || true
case "$cmd" in
  init)
    slug="${1:?usage: ledger.sh init <slug>}"; dir="$(ca_dir)/$slug"; mkdir -p "$dir"
    [ -f "$dir/ledger.md" ] || sed "s/<feature>/$slug/g" "$ROOT/templates/ledger.template.md" > "$dir/ledger.md"
    [ -f "$dir/evidence.jsonl" ] || : > "$dir/evidence.jsonl"
    echo "$slug" > "$(ca_dir)/CURRENT"
    echo "active feature: $slug  ($dir/ledger.md)" ;;
  product-init)
    name="${1:-$(basename "$(ca_root)")}"; prod="$(ca_product)"; mkdir -p "$(ca_dir)"
    [ -f "$prod" ] || sed "s/<name>/$name/g" "$ROOT/templates/product.template.md" > "$prod"
    echo "product ledger: $prod" ;;
  tail)
    tail -n "${1:-30}" "$(ca_ledger)" ;;
  log)
    msg="${1:?usage: ledger.sh log \"<msg>\"}"; printf -- '- @%s %s\n' "$(date -u +%FT%TZ)" "$msg" >> "$(ca_ledger)"
    echo "logged." ;;
  freeze)
    sec="${1:?usage: ledger.sh freeze <section>}"; l="$(ca_ledger)"; ts="$(date -u +%FT%TZ)"; tmp="$(mktemp)"
    awk -v h="$sec" -v ts="$ts" '
      /^## / { if(inhdr){ print "> frozen: agreed @" ts; inhdr=0 } if($0 ~ "^## "h){ inhdr=1 } }
      { print }
      END { if(inhdr) print "> frozen: agreed @" ts }
    ' "$l" > "$tmp" && mv "$tmp" "$l"
    echo "frozen: $sec" ;;
  revise)
    # Re-open a frozen section: append a revision marker at its end. framed? (and
    # any freeze gate) checks the LAST marker — a revision after a freeze re-opens
    # the gate until the user re-agrees and the conductor re-freezes.
    sec="${1:?usage: ledger.sh revise <section> \"<reason>\"}"; reason="${2:-}"
    l="$(ca_ledger)"; ts="$(date -u +%FT%TZ)"; tmp="$(mktemp)"
    awk -v h="$sec" -v ts="$ts" -v r="$reason" '
      /^## / { if(inhdr){ print "> revision @" ts ": " r; inhdr=0 } if($0 ~ "^## "h){ inhdr=1 } }
      { print }
      END { if(inhdr) print "> revision @" ts ": " r }
    ' "$l" > "$tmp" && mv "$tmp" "$l"
    echo "revised: $sec (re-freeze after the user re-agrees)" ;;
  close)
    # Roll the feature up into product.md and clear CURRENT. A learnings stub is
    # written even for an abandoned feature (v4 loses these). The conductor, as
    # the single writer, fills the placeholders before/after calling this.
    mode="${1:-}"; slug="$(ca_current)"; prod="$(ca_product)"; dir="$(ca_feature_dir "$slug")"; ts="$(date -u +%FT%TZ)"
    [ -n "$slug" ] || { echo "no active feature to close" >&2; exit 1; }
    [ -f "$prod" ] || sed "s/<name>/$(basename "$(ca_root)")/g" "$ROOT/templates/product.template.md" > "$prod"
    status=closed; case "$mode" in --abandoned) status=abandoned ;; --superseded) status=superseded ;; "" ) status=shipped ;; esac
    {
      printf '\n### %s — %s @%s\n' "$slug" "$status" "$ts"
      printf -- '- summary: <one line — what this feature did>\n'
      printf -- '- learnings: <what this taught us — fuel for the next intent>\n'
      [ "$status" = shipped ] && printf -- '- deployment: <what is live, where, version>\n'
    } >> "$prod"
    : > "$(ca_dir)/CURRENT"
    if [ "$status" = abandoned ] && [ -d "$dir" ]; then
      mv "$dir" "${dir%/}.abandoned" 2>/dev/null && echo "moved $slug → ${slug}.abandoned"
    fi
    echo "closed: $slug ($status) → rolled into $prod; CURRENT cleared" ;;
  *)
    echo "usage: ledger.sh init|product-init|tail|log|freeze|revise|close" ;;
esac
