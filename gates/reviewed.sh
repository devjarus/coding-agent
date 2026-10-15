#!/usr/bin/env bash
# reviewed? — the qualitative-review gate. Exit codes catch breakage; this gate
# catches wrong-but-green code, missed acceptance criteria, and security smells
# that a passing test suite sails right past.
#
# Applies once code is proven at this tree — there is nothing to review before
# there is proven code, and docs-only work (proven? n/a) is n/a here too.
#
# Two conditions, not one. The evidence entry proves a verdict was *recorded*
# against this tree; the artifact check proves that verdict was computed over a
# review file the gate can actually read. Without the second, the whole gate
# rests on a Markdown convention documented in one agent prompt — a worker
# writing `* [blocking]` instead of `- [blocking]` would record a green verdict
# with defects sitting on the page.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
GATE_NAME=reviewed

cur="$(ca_tree_sha)"
evidence_match test "$cur" >/dev/null || gate_result n/a "no proven code to review"

# Quick lane: a small, low-risk change is carried by proof + clean? + the commit
# wall alone. "Small" is measured, not declared, so the lane can't be used to
# dodge review on a large or risky change.
if [ "$(intent_value lane)" = quick ] && [ ! -f "$(ca_feature_dir)/review.md" ]; then
  intent_touches ui && gate_result block "quick lane cannot skip review for a ui change — dispatch a reviewer"
  ledger_section "$(ca_ledger)" intent | strip_comments | grep -qiE '^[[:space:]]*(consequential|deploys):[[:space:]]*yes' \
    && gate_result block "quick lane cannot skip review for a consequential or deployed change — dispatch a reviewer"
  base="$(intent_value base)"
  git rev-parse -q --verify "${base:-none}^{commit}" >/dev/null \
    || gate_result block "quick lane has no recorded base commit — dispatch a reviewer"
  n="$(ca_change_size "$base")"
  [ "$n" -le "$QUICK_LANE_MAX_LINES" ] \
    && gate_result pass "quick lane: small change ($n lines since ${base:0:8}), carried by proof + clean? + commit wall" \
    || gate_result block "change is $n lines — beyond the quick lane ($QUICK_LANE_MAX_LINES); dispatch a reviewer"
fi

review="$(ca_feature_dir)/review.md"
[ -f "$review" ] || gate_result block "no review.md — dispatch review (kind=review)"

# The artifact must be shaped like the template, or its finding count is a lie.
grep -q '^## findings' "$review" \
  || gate_result block "review.md has no '## findings' section — write it from templates/review.template.md"

# An unfilled template is not a review. Placeholders survive only when nobody
# did the work, so reject them rather than reading zero findings as "clean".
if strip_comments < "$review" | grep -qE '<[a-z][a-z -]+>'; then
  gate_result block "review.md still has unfilled <placeholders> — that is the template, not a review"
fi

body="$(awk '/^## findings/{f=1;next} /^## /{f=0} f' "$review" | strip_comments)"
blocking="$(echo "$body" | grep -c '^- \[blocking\]' || true)"

# Catch findings written in a shape the verdict command cannot count: any
# mention of [blocking]/[advisory] in the findings section that is not a
# flush-left "- " bullet is a malformed finding, not a clean review.
malformed="$(echo "$body" | grep -E '\[(blocking|advisory)\]' | grep -cvE '^- \[(blocking|advisory)\] ' || true)"
[ "$malformed" -eq 0 ] \
  || gate_result block "review.md has $malformed malformed finding line(s) — findings must be flush-left '- [blocking]' / '- [advisory]' or the gate cannot see them"

[ "$blocking" -eq 0 ] \
  || gate_result block "$blocking blocking finding(s) in review.md — dispatch a scoped build, then re-review"

evidence_match review "$cur" >/dev/null \
  && gate_result pass "reviewed clean at current tree (${cur:0:8}), 0 blocking findings" \
  || gate_result block "review.md is clean but no verdict recorded at this tree — record it (kind=review)"
