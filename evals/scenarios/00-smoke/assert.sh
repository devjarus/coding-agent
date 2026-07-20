#!/usr/bin/env bash
# 00-smoke — script-only (no model). Walks the full 8-gate arc with the real
# plugin scripts and asserts every gate reaches its correct state. This is the
# always-runnable CI baseline: if this fails, the plugin machinery itself broke.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" && pwd)/lib.sh"
L="$EV_PLUGIN_ROOT/v5/lib/ledger.sh"
R="$EV_PLUGIN_ROOT/v5/lib/record.sh"

# ── simulate a conductor-driven arc, entirely with the shipped scripts ──────
bash "$L" product-init smoke >/dev/null
bash "$L" init smoke-feature >/dev/null
python3 - <<'PY'
p = ".coding-agent/smoke-feature/ledger.md"
s = open(p).read()
s = s.replace("goal:", "goal: smoke the arc\ntouches: api", 1)
open(p, "w").write(s)
PY

ev_assert "framed? blocks before freeze"      test "$(ev_gate framed)" = block
bash "$L" freeze intent >/dev/null
ev_assert "framed? passes after freeze"       test "$(ev_gate framed)" = pass
ev_assert "architected? n/a (routine)"        test "$(ev_gate architected)" = n/a
ev_assert "designed? n/a (no ui)"             test "$(ev_gate designed)" = n/a

# hollow proof must NOT satisfy proven?
bash "$R" "echo ok" run >/dev/null
ev_assert "proven? rejects kind=run"          test "$(ev_gate proven)" = block

# build + prove
cat > thing.sh <<'S'
echo "thing"
S
cat > thing.test.sh <<'S'
[ "$(bash thing.sh)" = "thing" ]
S
bash "$R" "bash thing.test.sh" test >/dev/null
ev_assert "proven? passes on real test"       test "$(ev_gate proven)" = pass

# review
mkdir -p .coding-agent/smoke-feature
printf '# review\n- [advisory] fine\n' > .coding-agent/smoke-feature/review.md
bash "$R" "test \$(grep -c '^- \[blocking\]' .coding-agent/smoke-feature/review.md) -eq 0" review >/dev/null
ev_assert "reviewed? passes on clean verdict" test "$(ev_gate reviewed)" = pass

# commit — evidence must SURVIVE it (the T1.4 invariant)
git add -A && git commit -qm "smoke feature"
ev_assert "proven? survives the commit"       test "$(ev_gate proven)" = pass
ev_assert "reviewed? survives the commit"     test "$(ev_gate reviewed)" = pass
ev_assert "shipped? n/a (no deploy)"          test "$(ev_gate shipped)" = n/a
ev_assert "observed? n/a (no deploy)"         test "$(ev_gate observed)" = n/a

# redirect mechanics
bash "$L" revise intent "smoke revision" >/dev/null
ev_assert "revise re-opens framed?"           test "$(ev_gate framed)" = block
bash "$L" freeze intent >/dev/null
ev_assert "re-freeze closes framed?"          test "$(ev_gate framed)" = pass

# record.sh taxonomy guard
if bash "$R" "true" prove >/dev/null 2>&1; then bad=0; else bad=$?; fi
ev_assert "record.sh rejects dispatch kinds"  test "$bad" -eq 64

# close
bash "$L" close >/dev/null
ev_assert "close clears CURRENT"              test -z "$(ev_current)"
ev_assert "close rolls into product.md"       grep -q "smoke-feature — shipped" "$(ev_product)"
ev_assert "evidence is well-formed"           ev_evidence_wellformed

ev_summary
