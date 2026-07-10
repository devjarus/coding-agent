#!/usr/bin/env bash
# ledger.sh — the conductor's safe primitives for the (single-writer) ledger.
#   ledger.sh init <slug>          create a feature ledger, set it active
#   ledger.sh product-init [name]  create the product ledger
#   ledger.sh tail [n]             show the last n lines of the active ledger
#   ledger.sh log "<msg>"          append a timestamped line under ## log
#   ledger.sh freeze <section>     stamp a section frozen+agreed (intent|plan)
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
  *)
    echo "usage: ledger.sh init|product-init|tail|log|freeze" ;;
esac
