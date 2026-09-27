#!/usr/bin/env bash
# designed? — conditional. Applies only when intent is tagged `touches: ui`.
#
# Passes when BOTH hold:
#   1. the human's verdict verifies NOW — design-verdict.json is approved, has
#      zero open comments, and its design_sha matches design.html byte-for-byte;
#   2. a green kind=design evidence entry exists (the designer recorded it).
#
# The gate re-verifies the verdict itself instead of trusting whatever command
# was recorded as kind=design: `record.sh "true" design` is not an approval.
#
# Approval binds to the look-contract (design.html), NOT to the source tree.
# Building the approved design necessarily changes source; if approval were
# tree-bound, the first build would re-open this gate and the arc could never
# reach proven?. Conformance of the build to the approved design is review's job.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
GATE_NAME=designed
intent="$(ledger_section "$(ca_ledger)" intent | strip_comments)"
# Match ui anywhere in the touches value list (`touches: api, ui`), not only as
# the first value — anchored to the touches line so prose can't trip it.
echo "$intent" | grep -qiE '^[[:space:]]*touches:.*\bui\b' || gate_result n/a "no ui"

# The user may decline visual review in their own words (ledger.sh waive design).
waiver="$(echo "$intent" | grep -E '^> waived: design @.*user said: ".+"' | tail -1)"
[ -z "$waiver" ] || gate_result pass "user waived visual review: ${waiver#*user said: }"

dir="$(ca_feature_dir)"
[ -f "$dir/design.html" ] \
  || gate_result block "no design.html look-contract — dispatch design to write it and drive the surface"
reason="$(verify_design_verdict "$dir" design.html design_sha)"
[ -z "$reason" ] \
  || gate_result block "ui not approved on the surface: $reason"

ev="$(ca_evidence)"
[ -f "$ev" ] && grep '"kind":"design"' "$ev" | grep -q '"exit":0' \
  || gate_result block "approved on the surface but no design verdict recorded — record it (kind=design)"

gate_result pass "design.html approved on the surface and unchanged since sign-off"
