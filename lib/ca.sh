#!/usr/bin/env bash
# ca — the delivery loop's mechanics in one command, so the model spends turns
# on judgment instead of bookkeeping. Every subcommand is a thin composition of
# ledger.sh, record.sh, and the gates; none of them loosens a gate.
#
#   ca next                                   run the gates in order; print status + the next action
#   ca start <slug> [--lane quick|standard|deep] [--interrupting "<why>"] [--answer "<user's words>" < frame.md]
#                                             open a feature (product ledger too), record lane + base commit;
#                                             with --answer, also frame + freeze from stdin in the same call
#   ca frame --answer "<user's words>" < frame.md
#                                             replace ## intent and ## plan from stdin, then freeze
#   ca prove                                  record every declared tier's frozen test command
#   ca verdict                                record the review verdict for review.md at this tree
#   ca waive design --answer "<user's words>" the user declined visual review; designed? honours it
#   ca commit -m "<message>" -- <paths...>    stage exactly these paths, clean?, commit (pre-commit gate re-checks)
#   ca close --summary "..." --learnings "..." [--deployment "..."] [--abandoned|--superseded]
#
# frame.md holds the two sections, starting with "## intent" and "## plan".
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$ROOT/gates/lib.sh"
L="$ROOT/lib/ledger.sh"
R="$ROOT/lib/record.sh"
GATES="framed architected designed proven reviewed clean shipped observed"
cd "$(ca_root)" || exit 1

die() { echo "ca: $*" >&2; exit 64; }
gate_line() { bash "$ROOT/gates/$1.sh" 2>/dev/null | head -1; }
field() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2],""))' "$1" "$2" 2>/dev/null; }
attributable_changes() { git status --porcelain --untracked-files=all 2>/dev/null | grep -v '\.coding-agent/' || true; }

route() { # gate reason lane -> one line of advice
  local g="$1" why="$2" lane="$3"
  case "$g" in
    framed)
      if [ "$lane" = deep ]; then echo "dispatch planner (kind=frame); show the user; then: ca frame --answer \"<their words>\" < frame.md"
      else echo "write ## intent + ## plan yourself, show them, then: ca frame --answer \"<the user's words>\" < frame.md"; fi ;;
    architected) echo "dispatch planner (kind=architect); append the ADR to product.md ## decisions; one-way door needs user agreed: \"...\"" ;;
    designed)
      case "$why" in *"no design.html"*|*"not approved"*) echo "dispatch designer to drive the review surface — or, if the user declined visual review: ca waive design --answer \"<their words>\"" ;;
                     *) echo "dispatch designer to record the verdict (kind=design)" ;; esac ;;
    proven) echo "build/fix until the frozen commands pass, then: ca prove (a red tier twice with no new evidence → diagnostician)" ;;
    reviewed)
      case "$why" in
        *"no review.md"*) echo "dispatch reviewer (developer kind=review, read-only, aggregate) on the diff, then: ca verdict" ;;
        *"blocking finding"*) echo "fix the - [blocking] findings in review.md, then re-dispatch review and ca verdict" ;;
        *"no verdict"*) echo "ca verdict" ;;
        *"quick lane"*) echo "the change outgrew the quick lane — dispatch a reviewer (then ca verdict)" ;;
        *) echo "repair review.md, then: ca verdict" ;;
      esac ;;
    clean) echo "strip the flagged lines, re-stage, re-run (never commit past clean?)" ;;
    shipped) echo "dispatch deployer (kind=ship) with the declared deploy command" ;;
    observed) echo "dispatch deployer (kind=observe); unhealthy → ledger.sh rollback, then diagnostician" ;;
  esac
}

show_next() { # [--brief] — the gate table (unless --brief) and the NEXT action
    local brief="${1:-}" slug lane first="" first_reason="" out st why
    slug="$(ca_current)"
    [ -n "$slug" ] && [ -f "$(ca_ledger)" ] || { echo "no active feature — for a change, run: ca start <slug> --lane quick|standard|deep"; return 0; }
    lane="$(intent_value lane)"; lane="${lane:-standard}"
    [ "$brief" = --brief ] || echo "feature: $slug   lane: $lane"
    for g in $GATES; do
      out="$(gate_line "$g")"; st="$(field "$out" status)"; why="$(field "$out" reason)"
      [ "$brief" = --brief ] || printf '  %-12s %-6s %s\n' "$g?" "${st:-error}" "$why"
      if [ -z "$first" ] && [ "$st" != pass ] && [ "$st" != "n/a" ]; then
        # clean? is n/a until something is staged; it is not the next step on its own.
        first="$g"; first_reason="$why"
      fi
    done
    if [ -n "$first" ]; then
      echo "NEXT: $first? — $(route "$first" "$first_reason" "$lane")"
    elif [ -n "$(attributable_changes)" ]; then
      echo "NEXT: commit — ca commit -m \"<message>\" -- <the changed paths you verified>"
    else
      echo "NEXT: close — ca close --summary \"<what shipped>\" --learnings \"<what the next feature should know>\""
    fi
}

cmd="${1:-help}"; shift || true
case "$cmd" in
  next)
    show_next ;;

  start)
    slug="${1:?usage: ca start <slug> [--lane quick|standard|deep]}"; shift || true
    lane=standard; extra=(); answer=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --lane) lane="${2:-}"; shift 2 ;;
        --interrupting) extra+=(--interrupting "${2:-}"); shift 2 ;;
        --answer) answer="${2:-}"; shift 2 ;;
        *) die "unknown option: $1" ;;
      esac
    done
    case "$lane" in quick|standard|deep) ;; *) die "lane must be quick, standard, or deep" ;; esac
    [ -f "$(ca_product)" ] || bash "$L" product-init >/dev/null
    bash "$L" init "$slug" "${extra[@]}"
    base="$(git rev-parse HEAD 2>/dev/null || echo none)"
    l="$(ca_ledger)"; tmp="$(mktemp)"
    awk -v lane="$lane" -v base="$base" '/^## intent/ { print; print "lane: " lane; print "base: " base; next } { print }' "$l" > "$tmp" && mv "$tmp" "$l"
    echo "lane: $lane   base: ${base:0:12}"
    # With --answer and the frame on stdin, start + frame + freeze in one call.
    if [ -n "$answer" ]; then
      "$0" frame --answer "$answer"
    else
      show_next --brief
    fi ;;

  frame)
    answer=""
    while [ $# -gt 0 ]; do case "$1" in --answer) answer="${2:-}"; shift 2 ;; *) die "unknown option: $1" ;; esac; done
    [ -n "$answer" ] || die "frame needs --answer \"<what the user actually said>\" — agreement is recorded, never assumed"
    [ -n "$(ca_current)" ] || die "no active feature — ca start <slug> first"
    bodyf="$(mktemp)"; cat > "$bodyf"
    grep -q '^## intent' "$bodyf" && grep -q '^## plan' "$bodyf" || die "stdin must contain '## intent' and '## plan' sections"
    l="$(ca_ledger)"; keep="$(ledger_section "$l" intent | grep -E '^(lane|base):' || true)"
    python3 - "$l" "$keep" "$bodyf" <<'PY' || die "could not write the frame"
import re, sys
path, keep, bodyf = sys.argv[1], sys.argv[2], sys.argv[3]
body = open(bodyf).read()
ledger = open(path).read()
intent = re.search(r'(?ms)^## intent\n(.*?)(?=^## )', body + "\n## end\n").group(1).strip("\n")
plan = re.search(r'(?ms)^## plan\n(.*?)(?=^## )', body + "\n## end\n").group(1).strip("\n")
intent = "\n".join(l for l in intent.splitlines() if not re.match(r'(lane|base):', l))
ledger = re.sub(r'(?ms)^## intent\n.*?(?=^## )', lambda m: "## intent\n" + (keep + "\n" if keep else "") + intent + "\n\n", ledger, count=1)
ledger = re.sub(r'(?ms)^## plan\n.*?(?=^## )', lambda m: "## plan\n" + plan + "\n\n", ledger, count=1)
open(path, "w").write(ledger)
PY
    rm -f "$bodyf"
    bash "$L" freeze intent --answer "$answer"
    show_next --brief ;;

  prove)
    [ -n "$(ca_current)" ] || die "no active feature"
    tiers="$(declared_tiers)"; [ -n "$tiers" ] || die "intent declares no tiers:"
    rc=0
    while IFS= read -r t; do
      c="$(declared_test_command "$t")"
      [ -n "$c" ] || { echo "✗ $t: no test-command-$t in the frozen intent"; rc=1; continue; }
      out="$(bash "$R" "$c" test "$t" 2>&1)"; e=$?
      if [ "$e" -eq 0 ]; then echo "✓ $t  ($(echo "$out" | head -1 | sed 's/^▶ //'))"
      else rc=1; echo "✗ $t exit=$e"; echo "$out" | tail -25 | sed 's/^/    /'; fi
    done <<< "$tiers"
    [ "$rc" -eq 0 ] && show_next --brief || gate_line proven
    exit "$rc" ;;

  verdict)
    [ -n "$(ca_current)" ] || die "no active feature"
    rv=".coding-agent/$(ca_current)/review.md"
    [ -f "$(ca_feature_dir)/review.md" ] || die "no review.md — dispatch a reviewer first"
    bash "$R" "test \$(grep -c '^- \\[blocking\\]' $rv) -eq 0" review >/dev/null
    gate_line reviewed
    show_next --brief ;;

  waive)
    what="${1:-}"; shift || true
    [ "$what" = design ] || die "only 'design' can be waived"
    answer=""
    while [ $# -gt 0 ]; do case "$1" in --answer) answer="${2:-}"; shift 2 ;; *) die "unknown option: $1" ;; esac; done
    [ -n "$answer" ] || die "waive needs --answer \"<the user's words declining visual review>\""
    bash "$L" waive design --answer "$answer"
    show_next --brief ;;

  commit)
    msg=""
    while [ $# -gt 0 ]; do
      case "$1" in -m) msg="${2:-}"; shift 2 ;; --) shift; break ;; *) break ;; esac
    done
    [ -n "$msg" ] || die "commit needs -m \"<message>\""
    [ $# -gt 0 ] || die "commit needs explicit paths after -- (never a repo-wide pathspec)"
    for p in "$@"; do
      case "$p" in .|./|*'*'*|-A|--all) die "refusing repo-wide pathspec '$p' — list the attributable paths" ;; .coding-agent*) die "never stage .coding-agent/" ;; esac
    done
    git add -- "$@" || die "git add failed"
    out="$(gate_line clean)"
    [ "$(field "$out" status)" != block ] || { echo "$out"; die "clean? blocks — fix, re-stage, retry"; }
    git commit -q -m "$msg" || { echo "ca: commit refused (the pre-commit gate names the gate that blocks)" >&2; exit 1; }
    sha="$(git rev-parse --short HEAD)"
    bash "$L" log "commit $sha — $(printf '%s' "$msg" | head -1)" >/dev/null
    echo "committed $sha"
    show_next --brief ;;

  close)
    args=("$@"); has_dep=0
    for a in "${args[@]}"; do [ "$a" = --deployment ] && has_dep=1; case "$a" in --abandoned|--superseded) has_dep=1 ;; esac; done
    if [ "$has_dep" -eq 0 ] && ! ledger_section "$(ca_ledger)" intent | strip_comments | grep -qiE '^[[:space:]]*deploys:[[:space:]]*yes'; then
      args+=(--deployment "not deployed (no deploys: yes in the intent)")
    fi
    bash "$L" close "${args[@]}" ;;

  *)
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
