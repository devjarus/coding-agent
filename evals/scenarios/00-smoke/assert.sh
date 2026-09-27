#!/usr/bin/env bash
# 00-smoke — script-only (no model). Walks the full 8-gate arc with the real
# plugin scripts and asserts every gate reaches its correct state, then exercises
# the Phase A guarantees: staging safety, tiered proof, evidence-bound agreement,
# the review schema, rollup completeness, the feature stack, rollback, incidents.
#
# This is the always-runnable CI baseline: if it fails, the machinery itself
# broke. Nearly every assertion here corresponds to a defect that shipped once.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" && pwd)/lib.sh"
L="$EV_PLUGIN_ROOT/lib/ledger.sh"
R="$EV_PLUGIN_ROOT/lib/record.sh"
H="$EV_PLUGIN_ROOT/hooks/session-start.sh"

setintent() { # <slug> <body>
  python3 - "$1" "$2" <<'PY'
import sys, re
p = ".coding-agent/%s/ledger.md" % sys.argv[1]
s = open(p).read()
s = re.sub(r'(?ms)^## intent\n.*?(?=^## )', '## intent\n' + sys.argv[2] + '\n', s)
s = re.sub(r'(?ms)^## plan\n.*?(?=^## )', '## plan\n1. Execute the bounded smoke step.\n', s)
open(p, "w").write(s)
PY
}

# ── architecture discovery is a dialogue, not a planner-side decision ──────
ev_assert "planner can pause architecture for input" grep -q 'status: complete | needs-input' "$EV_PLUGIN_ROOT/agents/planner.md"
ev_assert "architecture questions explain consequences" grep -q 'consequence: <what this changes or trades away>' "$EV_PLUGIN_ROOT/agents/planner.md"
ev_assert "conductor owns architecture questions" grep -q 'Ask them in the main conversation' "$EV_PLUGIN_ROOT/agents/conductor.md"
ev_assert "architecture discovery is not a gate strike" grep -q 'failed gate or a strike' "$EV_PLUGIN_ROOT/agents/conductor.md"

# ── TA1 — data safety: the ledger must never become trackable ───────────────
bash "$H" >/dev/null 2>&1
ev_assert "session-start gitignores .coding-agent" grep -qE '^\.coding-agent/?$' .gitignore

bash "$L" product-init smoke >/dev/null
bash "$L" init smoke-feature >/dev/null
ev_assert "init installs the commit gate"        grep -q 'coding-agent pre-commit gate' "$(git rev-parse --git-path hooks)/pre-commit"
ev_assert "framed? rejects template plan"        test "$(ev_gate framed)" = block

# ── TA4 — agreement is evidence, not a stamp the writer wrote itself ────────
setintent smoke-feature 'goal: smoke the arc
tiers: unit
test-command-unit: bash thing.test.sh
touches: api
'
ev_assert "framed? blocks before freeze"        test "$(ev_gate framed)" = block
if bash "$L" freeze intent >/dev/null 2>&1; then forged=0; else forged=$?; fi
ev_assert "freeze refuses without --answer"     test "$forged" -eq 64
bash "$L" freeze intent --answer "yes, go ahead" >/dev/null
ev_assert "framed? passes on a recorded reply"  test "$(ev_gate framed)" = pass
ev_assert "the reply is in the ledger"          grep -q 'user said: "yes, go ahead"' .coding-agent/smoke-feature/ledger.md

ev_assert "architected? n/a (routine)"          test "$(ev_gate architected)" = n/a
ev_assert "designed? n/a (no ui)"               test "$(ev_gate designed)" = n/a

# ── TA3 — proof is per-tier, and hollow proof stays inert ───────────────────
bash "$R" "echo ok" run unit >/dev/null
ev_assert "proven? rejects kind=run"            test "$(ev_gate proven)" = block

cat > thing.sh <<'S'
echo "thing"
S
cat > thing.test.sh <<'S'
[ "$(bash thing.sh)" = "thing" ]
S
cat > thing.e2e.sh <<'S'
[ "$(bash thing.sh)" = "thing" ]
S
bash "$R" "bash thing.test.sh" test unit >/dev/null
ev_assert "proven? passes on a real test"       test "$(ev_gate proven)" = pass
if bash "$R" "true" test unit >/dev/null 2>&1; then hollow=0; else hollow=$?; fi
ev_assert "record.sh rejects substituted test"  test "$hollow" -eq 64

# prove workers may finish together; ids and JSON lines must remain unique.
bash "$R" "bash thing.test.sh" test unit >/dev/null & p1=$!
bash "$R" "bash thing.test.sh" test unit >/dev/null & p2=$!
wait "$p1"; wait "$p2"
ev_assert "concurrent evidence ids are unique" python3 -c 'import json; rows=[json.loads(x) for x in open(".coding-agent/smoke-feature/evidence.jsonl") if x.strip()]; ids=[r["id"] for r in rows]; raise SystemExit(0 if len(ids)==len(set(ids)) else 1)'

# add a second tier: the already-green unit run must NOT cover it
setintent smoke-feature 'goal: smoke the arc
tiers: unit, e2e
test-command-unit: bash thing.test.sh
test-command-e2e: bash thing.e2e.sh
touches: api
'
bash "$L" freeze intent --answer "yes" >/dev/null
ev_assert "one green tier is not proof of two"  test "$(ev_gate proven)" = block
ev_assert "the missing tier is named"           bash "$EV_PLUGIN_ROOT/gates/proven.sh" 2>&1 | grep -q 'e2e'
bash "$R" "bash thing.e2e.sh" test e2e >/dev/null
ev_assert "proven? passes with every tier"      test "$(ev_gate proven)" = pass

# ── TA5 — the review artifact has a schema the gate can actually read ───────
printf '# review\n\n## findings\n\n* [blocking] wrong bullet — a.sh:1\n' > .coding-agent/smoke-feature/review.md
bash "$R" "test \$(grep -c '^- \[blocking\]' .coding-agent/smoke-feature/review.md) -eq 0" review >/dev/null
ev_assert "malformed findings are not clean"    test "$(ev_gate reviewed)" = block
printf '# review\n\n## findings\n\n- [advisory] fine — a.sh:1\n' > .coding-agent/smoke-feature/review.md
bash "$R" "test \$(grep -c '^- \[blocking\]' .coding-agent/smoke-feature/review.md) -eq 0" review >/dev/null
ev_assert "reviewed? passes on a clean verdict" test "$(ev_gate reviewed)" = pass

# ── design verdicts fail closed on missing/stale SHA metadata ───────────────
mkdir -p .coding-agent/smoke-design
printf '<main>approved bytes</main>\n' > .coding-agent/smoke-design/design.html
printf '# ledger: smoke-design\n\n## intent\ngoal: approve this design\n' > .coding-agent/smoke-design/ledger.md
printf '{"verdict":"approved"}\n' > .coding-agent/smoke-design/design-verdict.json
if bash "$EV_PLUGIN_ROOT/scripts/design-review.sh" verify .coding-agent/smoke-design >/dev/null 2>&1; then weak=0; else weak=$?; fi
ev_assert "minimal design verdict is rejected"  test "$weak" -ne 0
design_sha="$(shasum -a 256 .coding-agent/smoke-design/design.html | cut -d' ' -f1)"
ledger_sha="$(shasum -a 256 .coding-agent/smoke-design/ledger.md | cut -d' ' -f1)"
printf '{"verdict":"approved","comments_open":0,"design_sha":"%s","ledger_sha":"%s"}\n' "$design_sha" "$ledger_sha" > .coding-agent/smoke-design/design-verdict.json
ev_assert "sha-bound design verdict passes" bash "$EV_PLUGIN_ROOT/scripts/design-review.sh" verify .coding-agent/smoke-design
printf '<main>changed after approval</main>\n' > .coding-agent/smoke-design/design.html
if bash "$EV_PLUGIN_ROOT/scripts/design-review.sh" verify .coding-agent/smoke-design >/dev/null 2>&1; then stale=0; else stale=$?; fi
ev_assert "post-approval design edit is rejected" test "$stale" -ne 0

# ── TA2 — clean? scans the STAGED diff; only source is ever staged ──────────
git add -- . ':(exclude).coding-agent'
ev_assert "clean? passes on a clean stage"      test "$(ev_gate clean)" = pass
ev_assert "no coordinator state is staged"      test -z "$(git diff --cached --name-only | grep coding-agent || true)"
git add -f .coding-agent/product.md
ev_assert "clean? blocks force-staged ledger state" test "$(ev_gate clean)" = block
git restore --staged .coding-agent/product.md
printf 'api_key = "sk-live-x"\n' > secret.py && git add secret.py
ev_assert "clean? catches a staged secret"      test "$(ev_gate clean)" = block
git rm -q --cached secret.py && rm -f secret.py

git commit -qm "smoke feature"
ev_assert "proven? survives the commit"         test "$(ev_gate proven)" = pass
ev_assert "reviewed? survives the commit"       test "$(ev_gate reviewed)" = pass
ev_assert "shipped? n/a (no deploy)"            test "$(ev_gate shipped)" = n/a
ev_assert "observed? n/a (no deploy)"           test "$(ev_gate observed)" = n/a

# ── TA14 — every block is durable, so strike 1 survives a resume ────────────
bash "$L" log "block: proven — no passing test at current tree" >/dev/null
ev_assert "prior blocks are recoverable"        test -n "$(bash "$L" blocks proven)"

# ── redirect mechanics ──────────────────────────────────────────────────────
bash "$L" revise intent "smoke revision" >/dev/null
ev_assert "revise re-opens framed?"             test "$(ev_gate framed)" = block
bash "$L" freeze intent --answer "ok, re-agreed" >/dev/null
ev_assert "re-freeze closes framed?"            test "$(ev_gate framed)" = pass

# ── record.sh taxonomy + tier guards ────────────────────────────────────────
if bash "$R" "true" prove >/dev/null 2>&1; then bad=0; else bad=$?; fi
ev_assert "record.sh rejects dispatch kinds"    test "$bad" -eq 64
if bash "$R" "true" test "bad tier" >/dev/null 2>&1; then badt=0; else badt=$?; fi
ev_assert "record.sh rejects a bad tier token"  test "$badt" -eq 64

# ── TA16 — rollback names the last HEALTHY release, not the last deploy ─────
bash "$R" "true" deploy >/dev/null && bash "$R" "true" observe >/dev/null
good_head="$(git rev-parse HEAD)"
echo "regression" >> thing.sh
git add -- . ':(exclude).coding-agent'
if git commit -qm "bad release" >/dev/null 2>&1; then walled=0; else walled=1; fi
ev_assert "the commit wall refuses an unproven tree" test "$walled" -eq 1
git commit -q --no-verify -m "bad release"      # a human shipping past the loop
bash "$R" "true" deploy >/dev/null; bash "$R" "false" observe >/dev/null 2>&1
ev_assert "rollback targets the healthy head"   bash "$L" rollback | grep -q "$good_head"

# ── TA15 + TA17 — an incident interrupts, then pops back ────────────────────
red_id="$(python3 -c "
import json
rows=[json.loads(l) for l in open('.coding-agent/smoke-feature/evidence.jsonl') if l.strip()]
print([r['id'] for r in rows if r['kind']=='observe' and r['exit']!=0][-1])")"
green_id="$(python3 -c "
import json
rows=[json.loads(l) for l in open('.coding-agent/smoke-feature/evidence.jsonl') if l.strip()]
print([r['id'] for r in rows if r['exit']==0][0])")"
bash "$L" incident smoke-hotfix --from smoke-feature --evidence "$red_id" >/dev/null
ev_assert "incident becomes the active feature"  test "$(ev_current)" = smoke-hotfix
ev_assert "the interrupted feature stays stacked" grep -q '^smoke-feature$' .coding-agent/CURRENT
ev_assert "interruption is logged where it happened" grep -q 'interrupted by smoke-hotfix' .coding-agent/smoke-feature/ledger.md
ev_assert "the intent is built from the red run" grep -q '^incident: smoke-feature' .coding-agent/smoke-hotfix/ledger.md
ev_assert "an incident still needs agreement"    test "$(ev_gate framed)" = block
if bash "$L" incident nope --from smoke-feature --evidence "$green_id" >/dev/null 2>&1; then g=0; else g=$?; fi
ev_assert "a GREEN run cannot frame an incident" test "$g" -ne 0

bash "$L" freeze intent --answer "yes, fix it" >/dev/null
ev_assert "framed? passes for the incident"     test "$(ev_gate framed)" = pass
bash "$L" close --summary "hotfix" --learnings "cause was X" --deployment "prod" >/dev/null
ev_assert "close pops back to the interrupted"  test "$(ev_current)" = smoke-feature

# ── TA12 — the rollup is required, not stubbed ──────────────────────────────
if bash "$L" close --summary "only a summary" >/dev/null 2>&1; then stub=0; else stub=$?; fi
ev_assert "close refuses a partial rollup"      test "$stub" -eq 64
bash "$L" close --summary "smoked the arc" --learnings "the gates hold" --deployment "n/a" >/dev/null
ev_assert "close clears CURRENT"                test -z "$(ev_current)"
ev_assert "close rolls into product.md"         grep -q "smoke-feature — shipped" "$(ev_product)"
ev_assert "learnings land where workers read"   grep -q 'the gates hold' "$(ev_product)"
ev_assert "evidence is well-formed"             ev_evidence_wellformed

# ── designed? re-verifies the human verdict; approval binds to the look ─────
bash "$L" init smoke-ui >/dev/null
setintent smoke-ui 'goal: a landing page
tiers: unit, e2e
test-command-unit: bash thing.test.sh
test-command-e2e: bash thing.test.sh
touches: ui
'
bash "$L" freeze intent --answer "yes" >/dev/null
UI=.coding-agent/smoke-ui
ev_assert "designed? blocks with no look-contract" test "$(ev_gate designed)" = block
printf '<main>hero</main>\n' > "$UI/design.html"
bash "$R" "true" design >/dev/null
ev_assert "a self-recorded design run is not approval" test "$(ev_gate designed)" = block
printf '{"verdict":"approved","comments_open":0,"design_sha":"%s"}\n' \
  "$(shasum -a 256 "$UI/design.html" | cut -d' ' -f1)" > "$UI/design-verdict.json"
bash "$R" "bash $EV_PLUGIN_ROOT/scripts/design-review.sh verify $UI" design >/dev/null
ev_assert "designed? passes on a verified verdict" test "$(ev_gate designed)" = pass
echo '<h1>built</h1>' > index.html
ev_assert "building the design keeps it approved" test "$(ev_gate designed)" = pass
bash "$L" log "design approved" >/dev/null
ev_assert "a ledger log does not void the approval" bash "$EV_PLUGIN_ROOT/scripts/design-review.sh" verify "$UI"
printf '<main>changed</main>\n' > "$UI/design.html"
ev_assert "designed? blocks a post-approval edit" test "$(ev_gate designed)" = block

# ── the commit wall holds without anyone claiming anything ──────────────────
git add index.html
if git commit -qm "wip" >/dev/null 2>&1; then walled=0; else walled=1; fi
ev_assert "the commit wall blocks an unmet gate" test "$walled" -eq 1
git restore --staged index.html && rm -f index.html

# ── ca: the loop in one command; lanes are measured, not declared ──────────
CA="$EV_PLUGIN_ROOT/lib/ca.sh"
bash "$L" close --summary "ui smoke" --learnings "design binds to the look" --deployment "n/a" >/dev/null
bash "$CA" start smoke-quick --lane quick >/dev/null
ev_assert "ca start records lane + base"         sh -c 'grep -q "^lane: quick" .coding-agent/smoke-quick/ledger.md && grep -q "^base: [0-9a-f]\{40\}" .coding-agent/smoke-quick/ledger.md'
frame='## intent
goal: quick smoke
tiers: unit
test-command-unit: bash thing.test.sh
touches: api
acceptance:
- [ ] thing works
## plan
1. keep thing working'
if printf '%s\n' "$frame" | bash "$CA" frame >/dev/null 2>&1; then f=0; else f=$?; fi
ev_assert "ca frame refuses without --answer"    test "$f" -eq 64
printf '%s\n' "$frame" | bash "$CA" frame --answer "yes, small fix" >/dev/null
ev_assert "ca frame writes + freezes"            test "$(ev_gate framed)" = pass
ev_assert "ca frame keeps lane + base"           grep -q "^lane: quick" .coding-agent/smoke-quick/ledger.md
ev_assert "ca prove records every tier"          bash "$CA" prove
ev_assert "quick lane: small change needs no reviewer" test "$(ev_gate reviewed)" = pass
seq 1 200 > big.txt
bash "$CA" prove >/dev/null
ev_assert "quick lane: a big change must be reviewed" test "$(ev_gate reviewed)" = block
rm -f big.txt
bash "$CA" prove >/dev/null
if bash "$CA" commit -m "x" -- . >/dev/null 2>&1; then c=0; else c=$?; fi
ev_assert "ca commit refuses a repo-wide pathspec" test "$c" -ne 0
ev_assert "ca next names the next step"          sh -c "bash '$CA' next | grep -q '^NEXT: close'"
# a verdict vouches only for code the reviewer saw
printf '# review\n\n## findings\n\n' > .coding-agent/smoke-quick/review.md
sleep 1; echo "# changed after review" >> thing.sh
if bash "$CA" verdict >/dev/null 2>&1; then v=0; else v=$?; fi
ev_assert "ca verdict refuses after a code change" test "$v" -eq 64
sed -i.bak '$d' thing.sh && rm -f thing.sh.bak
touch .coding-agent/smoke-quick/review.md; sleep 1; echo "notes" >> NOTES.md
ev_assert "ca verdict allows a docs-only follow-up" bash "$CA" verdict
rm -f NOTES.md .coding-agent/smoke-quick/review.md
bash "$CA" close --summary "quick" --learnings "lanes are measured" >/dev/null
ev_assert "ca close defaults the deployment line" grep -q "deployment: not deployed" "$(ev_product)"

# ── design waiver: only the user's words skip visual review ───────────────
bash "$CA" start smoke-waive --lane standard >/dev/null
printf '## intent\ngoal: page\ntiers: e2e\ntest-command-e2e: true\ntouches: ui\nacceptance:\n- [ ] renders\n## plan\n1. page\n' \
  | bash "$CA" frame --answer "yes" >/dev/null
ev_assert "designed? blocks without approval or waiver" test "$(ev_gate designed)" = block
if bash "$CA" waive design >/dev/null 2>&1; then w=0; else w=$?; fi
ev_assert "a waiver needs the user's words"      test "$w" -eq 64
bash "$CA" waive design --answer "I don't need a design review" >/dev/null
ev_assert "designed? honours the user's waiver"  test "$(ev_gate designed)" = pass
bash "$CA" close --abandoned --summary "waiver smoke" --learnings "waivers quote the user" >/dev/null

# ── the evidence wall denies hand-writes, allows reads ──────────────────────
W="$EV_PLUGIN_ROOT/hooks/evidence-wall.sh"
wall() { python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1" | bash "$W"; }
ev_assert "wall denies a shell append"      sh -c "$(declare -f wall); W='$W'; wall 'echo x >> $UI/evidence.jsonl' | grep -q deny"
ev_assert "wall denies an interpreter write" sh -c "$(declare -f wall); W='$W'; wall \"python3 -c \\\"open('$UI/evidence.jsonl','a').write('x')\\\"\" | grep -q deny"
ev_assert_not "wall allows a read"          sh -c "$(declare -f wall); W='$W'; wall 'grep test $UI/evidence.jsonl 2>/dev/null' | grep -q deny"

ev_summary
