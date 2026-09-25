#!/usr/bin/env bash
# ledger.sh — the conductor's safe primitives for the (single-writer) ledger.
#   ledger.sh init <slug>          create a feature ledger, set it active,
#                                  and install the git pre-commit gate
#   ledger.sh product-init [name]  create the product ledger
#   ledger.sh tail [n]             show the last n lines of the active ledger
#   ledger.sh log "<msg>"          append a timestamped line under ## log
#   ledger.sh freeze intent        stamp the agreed frame with the user's reply
#   ledger.sh revise <section> "why"  re-open a frozen section (append a revision marker)
#   ledger.sh close [--abandoned|--superseded]  roll up into product.md, clear CURRENT
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../gates/lib.sh"
ROOT="$(cd "$HERE/.." && pwd)"

cmd="${1:-help}"; shift || true
case "$cmd" in
  init)
    # CURRENT is a STACK, one slug per line, active = last. A hotfix that
    # interrupts a feature pushes; close pops back. Without this an incident
    # silently repoints CURRENT and the interrupted work loses its place —
    # the state survives on disk but nothing remembers to return to it.
    slug="${1:?usage: ledger.sh init <slug> [--interrupting \"<why>\"]}"; shift || true
    why=""
    while [ $# -gt 0 ]; do case "$1" in --interrupting) why="${2:-}"; shift 2 ;; *) shift ;; esac; done
    dir="$(ca_dir)/$slug"; mkdir -p "$dir"
    [ -f "$dir/ledger.md" ] || sed "s/<feature>/$slug/g" "$ROOT/templates/ledger.template.md" > "$dir/ledger.md"
    [ -f "$dir/evidence.jsonl" ] || : > "$dir/evidence.jsonl"
    cur="$(ca_dir)/CURRENT"; prev="$(ca_current)"
    if [ -n "$prev" ] && [ "$prev" != "$slug" ]; then
      # Mark the ledger being pushed off so the log says why you left it.
      pl="$(ca_ledger "$prev")"
      [ -f "$pl" ] && printf -- '- @%s interrupted by %s%s\n' \
        "$(date -u +%FT%TZ)" "$slug" "${why:+ — $why}" >> "$pl"
      printf '%s\n' "$slug" >> "$cur"
      echo "active feature: $slug  ($dir/ledger.md)  [interrupted: $prev]"
    else
      printf '%s\n' "$slug" > "$cur"
      echo "active feature: $slug  ($dir/ledger.md)"
    fi
    # The commit wall: from here on a commit cannot land past an unmet gate.
    echo "commit gate: $(ca_install_commit_gate "$ROOT")" ;;
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
    # A freeze asserts the USER agreed. Requiring their verbatim reply is what
    # stops the conductor from stamping its own consent: the marker now carries
    # the answer it was granted on, so "agreed" is a quotable fact rather than a
    # line the writer wrote about itself. If a cheaper path exists, it gets
    # taken — so do not leave one.
    sec="${1:?usage: ledger.sh freeze <section> --answer \"<what the user replied>\"}"; shift || true
    answer=""
    while [ $# -gt 0 ]; do
      case "$1" in --answer) answer="${2:-}"; shift 2 ;; *) shift ;; esac
    done
    [ -n "$answer" ] || { echo "ledger.sh freeze: --answer \"<what the user replied>\" is required." >&2
      echo "  Ask via AskUserQuestion first, then paste back what they actually said." >&2
      echo "  A freeze with no recorded answer is a forged approval; framed? will reject it." >&2; exit 64; }
    # One line, quoted, no newlines — the marker must stay greppable.
    answer="$(printf '%s' "$answer" | tr '\n' ' ' | cut -c1-200)"
    l="$(ca_ledger)"; ts="$(date -u +%FT%TZ)"; tmp="$(mktemp)"
    awk -v h="$sec" -v ts="$ts" -v a="$answer" '
      /^## / { if(inhdr){ print "> frozen: agreed @" ts " — user said: \"" a "\""; inhdr=0 } if($0 ~ "^## "h){ inhdr=1 } }
      { print }
      END { if(inhdr) print "> frozen: agreed @" ts " — user said: \"" a "\"" }
    ' "$l" > "$tmp" && mv "$tmp" "$l"
    echo "frozen: $sec (agreement recorded)" ;;
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
  incident)
    # Ad-hoc entry for a production failure. The arc always starts at framed?,
    # which means an incident would otherwise wait on a drafted-and-agreed intent
    # before anyone may reproduce it. But an incident already HAS its intent, and
    # it is already evidence: "make this red run green". So build the intent from
    # the failing entry instead of dispatching a planner for it.
    #
    #   ledger.sh incident <slug> --from <feature> --evidence <id>
    #
    # The user still agrees (freeze --answer) — shipping a fix to production is
    # a change like any other. What this skips is the round-trip, not the consent.
    slug="${1:?usage: ledger.sh incident <slug> --from <feature> --evidence <id>}"; shift || true
    src=""; eid=""
    while [ $# -gt 0 ]; do
      case "$1" in --from) src="${2:-}"; shift 2 ;; --evidence) eid="${2:-}"; shift 2 ;; *) shift ;; esac
    done
    [ -n "$src" ] && [ -n "$eid" ] || { echo "usage: ledger.sh incident <slug> --from <feature> --evidence <id>" >&2; exit 64; }
    srcev="$(ca_feature_dir "$src")/evidence.jsonl"
    [ -f "$srcev" ] || { echo "no evidence file for feature '$src'" >&2; exit 64; }
    line="$(python3 - "$srcev" "$eid" <<'PY'
import json,sys
for l in open(sys.argv[1]):
    if not l.strip(): continue
    d=json.loads(l)
    if str(d.get("id"))==sys.argv[2]:
        if d.get("exit")==0:
            sys.exit("evidence #%s is green (exit 0) — an incident frame needs a FAILING run" % sys.argv[2])
        print("%s\t%s\t%s" % (d.get("cmd",""), d.get("kind",""), d.get("tier","default"))); break
else: sys.exit("no evidence #%s in feature '%s'" % (sys.argv[2], sys.argv[1]))
PY
)" || exit 64
    cmd="$(printf '%s' "$line" | cut -f1)"; ekind="$(printf '%s' "$line" | cut -f2)"; etier="$(printf '%s' "$line" | cut -f3)"
    "$0" init "$slug" --interrupting "incident: $src #$eid failing" >/dev/null
    l="$(ca_ledger "$slug")"; tmp="$(mktemp)"
    awk -v c="$cmd" -v k="$ekind" -v t="$etier" -v s="$src" -v e="$eid" '
      /^## intent/ { print; print ""
        print "goal: restore " s " — `" c "` is failing in production"
        print "incident: " s " #" e "  (kind=" k ", tier=" t ")"
        print "tiers: " t
        print "test-command-" t ": " c
        print "touches: api"
        print ""
        print "scope: the smallest change that turns the failing command green; nothing else"
        print "non-goals: refactors, adjacent cleanups, anything the outage did not force"
        print ""
        print "acceptance:"
        print "- [ ] `" c "` exits 0 at the current tree"
        print "- [ ] the cause is named in the ledger, not just the symptom"
        print ""
        skip=1; next }
      skip && /^## / { skip=0 }
      skip { next }
      /^## plan/ { print
        print "1. Reproduce `" c "` and isolate the cause."
        print "2. Implement the smallest fix that restores the failing behavior."
        print "3. Run the identical reproduction and every declared tier, then review the diff."
        plan_skip=1; next }
      plan_skip && /^## / { plan_skip=0 }
      plan_skip { next }
      { print }' "$l" > "$tmp" && mv "$tmp" "$l"
    echo "incident ledger: $slug (from $src #$eid)"
    echo "  intent pre-filled from the failing run — confirm with the user, then:"
    echo "  ledger.sh freeze intent --answer \"<what they said>\"" ;;
  rollback)
    # The last KNOWN-HEALTHY release: a green deploy that a green observe later
    # confirmed at the same tree. Both halves matter — "it deployed" is the
    # attempt, "it was healthy" is the claim. Prints the target so the conductor
    # can order the revert; --dry-run is the default because rolling production
    # back is the user's call, not a script's.
    ev="$(ca_evidence)"
    [ -f "$ev" ] || { echo "no evidence for the active feature" >&2; exit 1; }
    target="$(python3 - "$ev" <<'PY'
import json,sys
rows=[json.loads(l) for l in open(sys.argv[1]) if l.strip()]
healthy=[]
for d in rows:
    if d.get("kind")=="deploy" and d.get("exit")==0:
        if any(o.get("kind")=="observe" and o.get("exit")==0
               and o.get("tree_sha")==d.get("tree_sha") and o["id"]>d["id"] for o in rows):
            healthy.append(d)
if healthy:
    d=healthy[-1]
    print("%s\t%s\t%s\t%s" % (d["id"], d.get("head",""), d.get("tree_sha","")[:8], d.get("at","")))
PY
)"
    [ -n "$target" ] || { echo "no known-healthy release to roll back to (need a green deploy confirmed by a green observe at the same tree)" >&2; exit 1; }
    set -- $target
    echo "rollback target: evidence #$1  head=$2  tree=$3  deployed=$4"
    echo "  to execute: dispatch the deployer with kind=rollback and this head, then record"
    echo "  the redeploy (kind=deploy) and a fresh health check (kind=observe)." ;;
  blocks)
    # Prior gate blocks for <gate>, oldest first. The two-strike ladder counts
    # strikes by reading these back rather than from working memory — a strike
    # remembered only in context does not survive a compaction, which is exactly
    # when a long-running feature needs the ladder most.
    g="${1:?usage: ledger.sh blocks <gate>}"
    grep -F "block: $g " "$(ca_ledger)" 2>/dev/null || true ;;
  close)
    # Roll the feature up into product.md and clear CURRENT (popping back to any
    # feature this one interrupted). A learnings stub is written even for an
    # abandoned feature, because an abandoned attempt is often where the
    # sharpest gotcha lives.
    #
    # The rollup is REQUIRED, not stubbed: pass --summary/--learnings (and
    # --deployment when shipped). product.md is the only durable memory across
    # features, so a placeholder rollup degrades it at exactly the rate you ship.
    mode=""; summary=""; learnings=""; deployment=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --abandoned|--superseded) mode="$1"; shift ;;
        --summary)    summary="${2:-}"; shift 2 ;;
        --learnings)  learnings="${2:-}"; shift 2 ;;
        --deployment) deployment="${2:-}"; shift 2 ;;
        *) shift ;;
      esac
    done
    slug="$(ca_current)"; prod="$(ca_product)"; dir="$(ca_feature_dir "$slug")"; ts="$(date -u +%FT%TZ)"
    [ -n "$slug" ] || { echo "no active feature to close" >&2; exit 1; }
    status=closed; case "$mode" in --abandoned) status=abandoned ;; --superseded) status=superseded ;; "" ) status=shipped ;; esac
    miss=""
    [ -n "$summary" ]   || miss="$miss --summary"
    [ -n "$learnings" ] || miss="$miss --learnings"
    [ "$status" = shipped ] && [ -z "$deployment" ] && miss="$miss --deployment"
    [ -z "$miss" ] || { echo "ledger.sh close: missing$miss" >&2
      echo "  The rollup is the product memory the next feature reads. Write it now," >&2
      echo "  from what this run actually surfaced — a placeholder is worse than nothing." >&2
      echo "  Abandoned features still owe a learning: that is usually where it is." >&2; exit 64; }
    [ -f "$prod" ] || sed "s/<name>/$(basename "$(ca_root)")/g" "$ROOT/templates/product.template.md" > "$prod"
    {
      printf '\n### %s — %s @%s\n' "$slug" "$status" "$ts"
      printf -- '- summary: %s\n' "$summary"
      printf -- '- learnings: %s\n' "$learnings"
      [ -n "$deployment" ] && printf -- '- deployment: %s\n' "$deployment"
    } >> "$prod"
    # Also file the learning where workers actually read it.
    tmp="$(mktemp)"
    awk -v l="- [$slug @$ts] $learnings" '
      /^## learnings/ { print; print l; next } { print }' "$prod" > "$tmp" && mv "$tmp" "$prod"
    # Pop the stack: back to whatever this feature interrupted, if anything.
    cur="$(ca_dir)/CURRENT"; tmp="$(mktemp)"
    grep -v '^[[:space:]]*$' "$cur" 2>/dev/null | sed '$d' > "$tmp"; mv "$tmp" "$cur"
    resumed="$(tail -1 "$cur" 2>/dev/null | tr -d '[:space:]')"
    if [ "$status" = abandoned ] && [ -d "$dir" ]; then
      mv "$dir" "${dir%/}.abandoned" 2>/dev/null && echo "moved $slug → ${slug}.abandoned"
    fi
    echo "closed: $slug ($status) → rolled into $prod"
    [ -n "$resumed" ] && echo "resumed: $resumed (this feature had interrupted it)" || echo "CURRENT cleared" ;;
  *)
    echo "usage: ledger.sh init|product-init|tail|log|freeze|revise|close" ;;
esac
