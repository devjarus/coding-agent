# v5 design vet — ultracode review

> 25 agents · 5 review dimensions · adversarial verification pass · 2026-07-05

**Overall: `major-gaps`** — the architecture (conductor + kind-specific agents + evidence-gated pipeline) survived review; the confirmed findings are contract/wiring breaks between prompts, gates, and scripts.

## Top recommendations (priority order)

1. Repair the designed? evidence chain end-to-end — it is the one permanently-blocked gate: in v5/agents/designer.md, have the designer write design.html into .coding-agent/<slug>/ and start the surface with the feature dir (not the slug); delete the nonexistent agent-run 'approve' (the human approves in the browser via POST /verdict); record the verdict with record.sh "jq -e '.verdict==\"approved\"' .coding-agent/<slug>/design-verdict.json" design, or add a real sha-bound 'verify' subcommand to scripts/design-review.sh.

2. Fix the planner-to-gate artifact contract that breaks both agreement gates: demote the ADR heading to '### ADR — <slug> — <title>' and add a 'feature: <slug>' body line so architected? can see it past ledger_section's '^## ' terminator; delete the 'frozen:' placeholder from the frame template and anchor framed.sh to grep -q '^> frozen: agreed @' so only a real ledger.sh freeze passes; and fix designed.sh's touches: regex to a word-boundary match ('^[[:space:]]*touches:.*\bui\b') so multi-value UI features aren't silently skipped.

3. Make tree-bound evidence survive the prescribed walk: rework ca_tree_sha in v5/gates/lib.sh to hash working-tree content only (git ls-files -co --exclude-standard, excluding .coding-agent/, per-file digests — invariant across git add and git commit) so the prove → clean? → commit → ship sequence stops invalidating all evidence; and tree-bind observed? via evidence_match like its sibling gates so a stale healthy observation can't green-light a broken redeploy.

4. Close the conductor's control-loop gaps in one conductor.md edit: assign staging+commit as an explicit loop step between proven? and shipped? (giving clean? an owner so its secret scan actually runs); add Branch routes for framed?/architected?/clean? plus a default re-dispatch rule; add the two-strike escalation rule (same gate blocks twice with no new evidence → stop and surface to the user; agreement gates never cleared by re-dispatch); add the hard rule 'never freeze while open_questions are unresolved'; route frame → ledger ## intent and ADR → product.md ## decisions as in-loop actions; and use full ${CLAUDE_PLUGIN_ROOT}/v5/lib/ledger.sh paths.

5. Commit v5/ + docs/concepts/v5-design.md immediately (the redesign is currently one git clean from loss) and extend scripts/validate.sh with a v5 section (agent frontmatter schema, gate/lib executability, referenced-path existence — this would have caught the designer subcommand break); then at promotion, register the five agents in .claude-plugin/plugin.json AND merge v5/hooks/hooks.json (evidence-wall + SessionStart) in the same change, so the 'one law' is mechanically enforced from the first wired session.

## Confirmed findings

### [CRITICAL] designed? gate is permanently unclearable

**What:** designed? gate is permanently unclearable: designer.md instructs 'design-review.sh approve <feature-slug>' and 'verify <feature-slug>', but scripts/design-review.sh supports only start|stop|status and requires an existing feature directory (with spec.md/plan.md/design.html — which v5's ledger.sh init never creates). Every documented invocation exits 1; record.sh faithfully records kind=design exit:1; evidence_match requires exit:0 — so every 'touches: ui' feature blocks forever, even run by hand.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/agents/designer.md lines 34-65 (steps 1, 4, 5) vs /Users/suraj-devloper/workspace/codingAgent/scripts/design-review.sh lines 22, 42-96; gate: /Users/suraj-devloper/workspace/codingAgent/v5/gates/designed.sh line 9

**Fix:** Rewrite designer.md steps 1/4/5: (a) have the designer write design.html into .coding-agent/<slug>/ before starting the surface, and pass the feature dir, not the slug ('start .coding-agent/<slug>'); (b) delete the agent-run 'approve' — the HUMAN approves in the browser (POST /verdict writes design-verdict.json; an agent-run approve would defeat the zero-open-comments gate); (c) after human approval, record the verdict check: record.sh "jq -e '.verdict==\"approved\"' .coding-agent/<slug>/design-verdict.json" design (works because ca_tree_sha excludes .coding-agent/, so writing the verdict does not invalidate the tree sha). Alternatively add a real 'verify <slug|dir>' subcommand to design-review.sh that exits 0 iff design-verdict.json says approved and its recorded artifact shas still match (reuse verify_design_verdict from checks/lib.sh ~line 65).

### [CRITICAL] architected? cannot see the ADR the planner produces

**What:** architected? cannot see the ADR the planner produces: planner emits a level-2 heading '## ADR — <feature-slug> — <title>' marked 'ready to paste', but ledger_section() terminates the '## decisions' section at the next '^## ' line, so a verbatim-pasted ADR falls outside the section and grep for the slug finds nothing (verified: gate blocks at level-2, passes at '###'). The slug appears only in that heading, so the heading level is load-bearing.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/agents/planner.md line 73 vs /Users/suraj-devloper/workspace/codingAgent/v5/gates/lib.sh ledger_section (lines 29-36) and /Users/suraj-devloper/workspace/codingAgent/v5/gates/architected.sh line 11

**Fix:** Change the planner's ADR heading to level-3 ('### ADR — <feature-slug> — <decision-title>') and add a 'feature: <feature-slug>' body line so the gate has a canonical anchor that survives title rewording (matches templates/product.template.md's shown convention). Optionally also pipe the decisions extraction in architected.sh through strip_comments so template-comment words cannot false-pass a coincidental slug.

### [CRITICAL] v5 is not wired as a plugin

**What:** v5 is not wired as a plugin: .claude-plugin/plugin.json has no 'agents' field, so only the six v4 root agents are auto-discovered. Task dispatch with subagent_type planner/developer/designer/deployer fails at runtime and the conductor cannot be invoked — the system cannot run at all. v5/hooks/hooks.json (evidence-wall PreToolUse + SessionStart resume) is likewise never loaded, so the 'one law' (evidence only via record.sh) has zero mechanical enforcement. This state is deliberate and documented in v5/README.md ('v5 is not yet wired as a plugin'), but it is the promotion blocker.

**Where:** /Users/suraj-devloper/workspace/codingAgent/.claude-plugin/plugin.json (no agents field); /Users/suraj-devloper/workspace/codingAgent/v5/agents/; /Users/suraj-devloper/workspace/codingAgent/v5/hooks/hooks.json

**Fix:** At promotion, in one change: add "agents": "./v5/agents" (or the explicit five-file list) to plugin.json — the five v5 names don't collide with v4's six, so both coexist; merge the two v5 hook entries into the plugin's hook config in the same commit (registration alone would leave the evidence wall dead); run ./scripts/validate.sh and sync counts per AGENTS.md; fix the stale v5/README.md Layout block ('conductor.md · worker.md — the two system prompts' vs five actual agent files). Do not register early just to silence the finding if hand-dogfooding is the current intent.

### [MAJOR] framed? false-passes on the planner's own placeholder

**What:** framed? false-passes on the planner's own placeholder: the frame template contains the literal line 'frozen: agreed @ <user-confirmed timestamp>    # LEFT BLANK — conductor fills on agreement'; strip_comments removes only HTML comments (not trailing # notes), so a verbatim-pasted intent satisfies framed.sh's unanchored grep 'frozen: agreed @' with zero user agreement and no ledger.sh freeze (verified empirically). The template also contradicts its own step 5 ('Leave frozen: blank').

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/agents/planner.md line 44 vs /Users/suraj-devloper/workspace/codingAgent/v5/gates/framed.sh line 10 and strip_comments in /Users/suraj-devloper/workspace/codingAgent/v5/gates/lib.sh line 40

**Fix:** Delete the 'frozen:' line from the frame template entirely and reword step 5 to 'Do not include a frozen: line at all — only the conductor adds it via ledger.sh freeze after the user agrees'; tighten framed.sh line 10 to grep -q '^> frozen: agreed @' (verified to match ledger.sh freeze's blockquote output exactly and reject the placeholder); apply the same anchor to any other freeze check (freeze also stamps 'plan'). Also restyle the 'touches: ui | api | data | infra | docs  # ...' template lines as choose-one instructions outside the artifact body so verbatim pastes can't feed bogus tag values to the conditional gates.

### [MAJOR] ca_tree_sha rotates on a content-identical commit

**What:** ca_tree_sha rotates on a content-identical commit: it hashes 'git rev-parse HEAD' + 'git diff HEAD', so committing (HEAD changes, diff empties) yields a new sha over byte-identical files. All tree-bound evidence (test/design/deploy) is silently invalidated by the natural prove → clean? → commit → ship sequence, and the deployer's proven?-pre-flight is guaranteed to fail after the commit, forcing an undocumented redundant re-prove. Safe direction (false block), but the prescribed gate order cannot be walked.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/gates/lib.sh ca_tree_sha lines 44-55; /Users/suraj-devloper/workspace/codingAgent/v5/agents/deployer.md lines 39-42

**Fix:** Hash working-tree content only (the approach the non-git fallback already uses). Replace the git-branch pipeline with: git ls-files -co --exclude-standard -z -- ':(exclude).coding-agent/' | sort -z | xargs -0 shasum -a 256 2>/dev/null | shasum -a 256 | cut -d' ' -f1 — empirically invariant across both git add and git commit while changing on real content changes; per-file 'digest path' lines are path-sensitive and boundary-safe. Note: HEAD^{tree}+diff still rotates on commit, and ls-files -s+unstaged-diff rotates on git add (staging sits inside the same walk), so neither alternative works. Committed-ness at deploy remains enforced by the deployer's git-status check. Cheaper fallback: keep the hash and add a documented mandatory post-commit re-record step in conductor.md.

### [MAJOR] clean? has no owner

**What:** clean? has no owner: no dispatch kind stages or commits (the conductor 'never writes code', the kind table has no commit/ship-prep entry, and the developer is never told to git add), so clean? returns n/a vacuously and its secret/debug-print scan never actually runs — while the deployer pre-flight separately demands a committed clean tree, a step no prompt assigns.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/gates/clean.sh lines 7-8; /Users/suraj-devloper/workspace/codingAgent/v5/agents/conductor.md dispatch table lines 47-56 and loop lines 27-39

**Fix:** Assign commit mechanics explicitly in conductor.md: insert a loop step between proven? and shipped? — 'stage the change (git add on the scoped paths, excluding .coding-agent/), run clean?, then commit' — noting that git plumbing is coordinator state-keeping, not product code, so it does not violate 'never writes code'. Also split the 'shipped? fails → diagnose' route: dirty tree / nothing committed → stage + clean? + commit, retry ship; genuine deploy error → diagnose. Mirror in deployer.md pre-flight: dirty tree returns block with reason 'uncommitted work — conductor must commit', not a diagnose trigger.

### [MAJOR] observed? is the only evidence gate that is NOT tree-bound

**What:** observed? is the only evidence gate that is NOT tree-bound: it greps for any '"kind":"observe"' + '"exit":0' ever recorded instead of using evidence_match. Verified: after the tree moved, shipped? correctly blocked but observed? still passed on a stale healthy observation recorded against the OLD tree — a false pass on the final gate before declaring a release healthy.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/gates/observed.sh lines 10-13 vs evidence_match in /Users/suraj-devloper/workspace/codingAgent/v5/gates/lib.sh lines 58-63

**Fix:** Replace the raw grep with the shared helper, mirroring shipped.sh: evidence_match observe >/dev/null && gate_result pass "post-deploy health recorded at current tree" || gate_result block "no healthy post-deploy observation at current tree (kind=observe)". Works with already-recorded data (record.sh stamps tree_sha on observe entries) and is trivially satisfiable in the prescribed deployer flow. Optionally also require the observe entry's id to exceed the matching deploy entry's id for defense in depth.

### [MAJOR] Conditional-gate applicability regex is first-value-anchored

**What:** Conditional-gate applicability regex is first-value-anchored: planner is told 'touches: ui | api | data | infra | docs — one or more', but designed.sh greps 'touches: *ui', which matches only when ui is the FIRST value. Verified: 'touches: api, ui' returns n/a — the design gate is silently skipped for a UI feature, a false skip that defeats the evidence chain for it.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/gates/designed.sh line 8 vs /Users/suraj-devloper/workspace/codingAgent/v5/agents/planner.md line 42

**Fix:** Replace with grep -qiE '^[[:space:]]*touches:.*\bui\b' (verified working on this platform's grep: matches 'touches: api, ui', rejects 'touches: api'; leading-whitespace tolerant since the intent block is agent-written). shipped.sh/observed.sh/architected.sh key off single-valued yes|no tags and need no change.

### [MAJOR] No termination condition, retry cap, or escalation rule anywhere in the conductor's loop or Branch s

**What:** No termination condition, retry cap, or escalation rule anywhere in the conductor's loop or Branch section: a gate that blocks repeatedly (user never agrees to intent, tests persistently fail) has no prescribed escape, so the conductor can re-dispatch workers indefinitely and spin silently.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/agents/conductor.md lines 27-39 (loop) and 64-70 (Branch)

**Fix:** Add an escalation rule to '## Branch & failure routing', mirroring v4's fix-round cap: 'Two-strike rule: if the same gate blocks twice in a row with no new passing evidence in between (same tree sha for proven?/shipped?/observed?, same rejection theme for designed?), stop dispatching — summarize both attempts with the failing output to the user and wait for direction. Agreement gates (framed?, architected?) are never cleared by re-dispatch: once the draft exists, ask the user — do not loop workers.' Mirror into docs/concepts/v5-design.md section 7.

### [MAJOR] Branch routing lacks explicit handlers for framed? and clean? gate blocks (architected? handling liv

**What:** Branch routing lacks explicit handlers for framed? and clean? gate blocks (architected? handling lives only in Hard rules); the only framed? mention in Branch is a requirements-shift edge case. A conductor seeing a standard block on those gates has no prescribed action and may improvise incorrectly — acute for clean?, which no dispatch kind serves.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/agents/conductor.md lines 64-70 (Branch section)

**Fix:** Add: 'clean? blocks → dispatch build to the developer scoped to only the flagged lines (scrub the secret/debug print, restage); if the match is a false positive, log the judgment and proceed' (mandatory, since no kind serves clean?), plus a default rule for the rest: 'any other gate blocks → re-dispatch the kind that serves it (Dispatch table) with the block reason; framed?/architected? clear only on explicit user agreement (ledger.sh freeze intent / ADR recorded in product.md)'. Mirror in docs/concepts/v5-design.md section 7, whose table currently contradicts its own heading 'every gate has a fail edge'.

### [MAJOR] Nothing requires open_questions to be resolved before the intent is frozen

**What:** Nothing requires open_questions to be resolved before the intent is frozen: the planner returns the artifact and open_questions together, and the conductor — who performs the freeze — has no rule tying freeze to resolved questions, so an underspecified intent can be frozen while the user skims past the questions.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/agents/conductor.md Hard rules (freeze action); /Users/suraj-devloper/workspace/codingAgent/v5/agents/planner.md kind=frame, How-to-fill step 6 and return contract

**Fix:** Primary (the conductor does the freezing and never reads planner.md): add a conductor Hard rule — 'Never ledger.sh freeze a section while the returning worker's open_questions are unresolved; put each question to the user and record the answers in the ledger first.' Secondary belt-and-braces in planner.md kind=frame step 6: 'If open_questions is non-empty, prefix the artifact with DRAFT — open questions must be resolved before freeze.' Keep framed.sh unchanged, per the repo's 'prompt edits over enforcement hooks' decision.

### [MAJOR] Operating principle 5 'Say what you didn't do' has no structural carrier

**What:** Operating principle 5 'Say what you didn't do' has no structural carrier: all four worker return contracts are {did, evidence_ids, gate_status, open_questions} with open_questions defined narrowly as 'anything the conductor must decide' — a skipped tier or an assumption proceeded-on has no slot, and the conductor is told to distrust prose ('Read evidence.jsonl, never prose'), so disclosures ride the one channel that structurally omits them. Neither evidence.jsonl (cmd/exit/hash only) nor the gates (proven? passes on any single green kind=test run) can carry them.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/agents/developer.md lines 22-27; /Users/suraj-devloper/workspace/codingAgent/v5/agents/planner.md lines 22-27; /Users/suraj-devloper/workspace/codingAgent/v5/agents/designer.md lines 21-27; /Users/suraj-devloper/workspace/codingAgent/v5/agents/deployer.md lines 22-28

**Fix:** Add a disclosure line to each return contract — skipped_or_assumed: [<tiers not run, assumptions proceeded on, residual uncertainty — or "none">] — adapting per contract (planner's shape is {did, artifact, open_questions}, not the four-field spine). Update conductor.md loop step 4 to name the field and step 5 to include it in the ledger.sh log summary so it lands under ## log; mirror the field in docs/concepts/v5-design.md sections 4.1/4.2 where the return spine is defined. Prompt-only change, no new hooks or gates.

### [MAJOR] Build principle 1 'Simplest thing that works; deletability over cleverness (YAGNI)' and principle 3 

**What:** Build principle 1 'Simplest thing that works; deletability over cleverness (YAGNI)' and principle 3 'abstract on the third repetition' have zero in-body weight in developer.md's build section — present only via the one-line craft-plane reference — while the prompt heavily proceduralizes everything else (logging, markers, test paths). Re-described steps will dominate agent behavior; the top build principle won't.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/agents/developer.md lines 31-101 (step 7 at line 68, Hard rules 93-101, step-10 self-check)

**Fix:** Extend step 7: 'Implement. Make tests pass with the simplest thing that clears acceptance — deletable over clever; no speculative abstraction (abstract on the third repetition, not the first). Follow existing patterns. Reuse utilities. Use Context7 to verify library/CLI interfaces before invoking from memory.' Add one step-10 self-check bullet: 'Diff is the smallest reversible change that clears acceptance — nothing speculative, nothing outside the brief' (echoes operating principle 2's vocabulary). Placement in step 7 over Hard rules is deliberate: Hard rules are binary/checkable; simplicity is implement-time judgment. Bump minor version + CHANGELOG per AGENTS.md.

### [MINOR] Conductor references bare 'ledger.sh tail' (line 28) and 'ledger.sh log' (line 35) with no path whil

**What:** Conductor references bare 'ledger.sh tail' (line 28) and 'ledger.sh log' (line 35) with no path while gates and every worker prompt use full ${CLAUDE_PLUGIN_ROOT} paths; bare ledger.sh is not on PATH, so the conductor's first tool call fails command-not-found, and it violates AGENTS.md path convention rule 5.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/agents/conductor.md lines 28 and 35

**Fix:** Use ${CLAUDE_PLUGIN_ROOT}/v5/lib/ledger.sh in both places, and mention ${CLAUDE_PLUGIN_ROOT}/v5/lib/record.sh once for dispatch briefs.

### [MINOR] The loop never tells the conductor to route planner artifacts to their destinations at the right tim

**What:** The loop never tells the conductor to route planner artifacts to their destinations at the right time: loop step 5 only appends a one-line ## log summary, and ADRs roll into product.md 'at the end' — but architected? (which runs before build) reads product.md ## decisions NOW. Worse, planner.md's own law says 'The conductor appends them to the ledger', which for kind=architect is the wrong destination.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/agents/conductor.md lines 34-39 (loop) vs /Users/suraj-devloper/workspace/codingAgent/v5/agents/planner.md lines 18-19, 68-69

**Fix:** Add explicit in-loop routing to conductor.md: frame artifact → ledger.md ## intent (then freeze on user agreement); architect artifact → product.md ## decisions (then get user agreement on one-way doors) — as loop actions, not close-out.

### [MINOR] record.sh accepts any kind string unvalidated, and the dispatch-kind vs evidence-kind taxonomies col

**What:** record.sh accepts any kind string unvalidated, and the dispatch-kind vs evidence-kind taxonomies collide (prove/build/ship vs test/deploy/observe); both worker 'one law' lines read record.sh "<cmd>" <kind>, inviting a worker to record its dispatch kind. Verified: kind=prove with exit 0 satisfies no gate — proven? still blocks (orphan evidence, silent false block).

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/lib/record.sh lines 15-16; /Users/suraj-devloper/workspace/codingAgent/v5/agents/developer.md line 18; /Users/suraj-devloper/workspace/codingAgent/v5/agents/deployer.md line 18

**Fix:** Validate in record.sh: case "$kind" in test|deploy|design|observe|run) ;; *) echo "unknown kind '$kind' (use test|deploy|design|observe|run)" >&2; exit 64;; esac — and word the agents' law lines with the concrete evidence kinds.

### [MINOR] Worktree-isolated parallel builds cannot record

**What:** Worktree-isolated parallel builds cannot record: conductor.md prescribes isolate=worktree for fan-out builds, but inside a worktree ca_root resolves to the worktree where .coding-agent/CURRENT does not exist — record.sh exits 64 'no active feature' — while developer.md build step 10 makes recording mandatory before returning. The two prompts contradict. Concurrent record.sh appends also race on the wc-l-derived id.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/lib/record.sh line 19 + ca_root in /Users/suraj-devloper/workspace/codingAgent/v5/gates/lib.sh line 6; /Users/suraj-devloper/workspace/codingAgent/v5/agents/conductor.md lines 75-77; /Users/suraj-devloper/workspace/codingAgent/v5/agents/developer.md lines 83-92

**Fix:** Exempt worktree-isolated build dispatches from the self-record requirement in developer.md (proof happens at the conductor's fold, which re-runs proven? against the merged tree), or make ca_root worktree-aware via git rev-parse --git-common-dir; also address the append id race.

### [MINOR] proven? applicability diverges from the design doc

**What:** proven? applicability diverges from the design doc: the doc scopes it to 'a code change exists', but the gate has no n/a path and always demands kind=test evidence at the current tree — a docs-only intent (touches: docs) must record something as kind=test to ever advance.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/gates/proven.sh vs /Users/suraj-devloper/workspace/codingAgent/docs/concepts/v5-design.md line 77

**Fix:** Either document that proven? is unconditional and name what counts as a 'test' for non-code changes (linter, link-checker), or add an n/a path keyed off an intent tag.

### [MINOR] conductor.md line 57 claims every agent reads 'principles.md#<kind>' for all 7 kinds, but principles

**What:** conductor.md line 57 claims every agent reads 'principles.md#<kind>' for all 7 kinds, but principles.md defines only operating/build/prove/architect tiers — the anchor dangles for frame, diagnose, design, and ship, leaving the design and ship crafts with no principle tier at all (designer's accessibility rule is ad hoc, unbacked by principles.md).

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/agents/conductor.md line 57 vs /Users/suraj-devloper/workspace/codingAgent/v5/principles.md headings

**Fix:** State the real mapping (frame/architect → architect; build/prove/diagnose → build+prove; design/ship → operating-only) or add small design/ship tiers to principles.md if those crafts warrant binding principles.

### [MINOR] The planner cannot express 'defer'

**What:** The planner cannot express 'defer': the ADR decision block forces 'Chosen: <Option N>' with no defer/decide-later outcome, so the second half of architect principle 3 ('defer irreversible decisions to the last responsible moment') has no carrier — 'last responsible moment' appears nowhere in planner.md.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/agents/planner.md lines 86-92, 100-106

**Fix:** Allow 'Chosen: defer — revisit when <trigger>' as a valid decision outcome, and add a How-to-fill bullet: if the decision is irreversible and not yet forced, recommend deferring and name the forcing trigger.

### [MINOR] Prove principles 1 and 4 are half-carried or absent in developer.md step 6

**What:** Prove principles 1 and 4 are half-carried or absent in developer.md step 6: 'not implementation details' never appears (nothing stops white-box tests asserting internal call order), and there is no preference for few honest integration tests over many mock-heavy unit tests — step 6 is a pure volume mandate (unit + integration + E2E for every behavior). Build principle 4 (explicit boundaries, dependencies toward the stable core) is also uncarried.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/agents/developer.md lines 61-67 (step 6) and steps 3/7

**Fix:** Append to step 6: 'Assert observable behavior, never internal call sequences or private state. Prefer few integration tests at real seams over many mock-heavy unit tests — a behavior fully proven at the seam does not also need a mocked unit test.' Add one line to step 3 or 7: 'Note the project's module boundaries; new dependencies point toward the stable core — never import feature code from shared modules.'

### [MINOR] Planner tools omit Context7 (mcp__context7__resolve-library-id, mcp__context7__query-docs); the arch

**What:** Planner tools omit Context7 (mcp__context7__resolve-library-id, mcp__context7__query-docs); the architect kind evaluates libraries, frameworks, and infra topology and risks stale cost-of-change assessments without live docs.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/agents/planner.md frontmatter tools: [Read, Write, Edit, Bash, Grep, Glob]

**Fix:** Add both Context7 tools to the planner's tools list and reference them in kind=architect How-to-fill step 2: 'Use Context7 to verify current library/framework capabilities before evaluating options.'

### [MINOR] Developer build step 10's live-path check is vague ('Drive the live path for any user-facing change'

**What:** Developer build step 10's live-path check is vague ('Drive the live path for any user-facing change') — satisfiable with a single home-page browser_snapshot rather than exercising the actual user flow end-to-end.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/agents/developer.md step 10 Self-check, second bullet

**Fix:** Make it concrete: 'For any user-facing surface, use Playwright tools to navigate to the feature, interact with it (fill form / click CTA / assert result), and record a screenshot as evidence. A snapshot of the home page is not sufficient — the feature flow must be exercised.'

### [MINOR] Nothing is committed or validator-covered

**What:** Nothing is committed or validator-covered: v5/ and docs/concepts/v5-design.md are untracked (?? in git status) — the entire redesign is one git clean away from loss and invisible to any fresh clone — and scripts/validate.sh has zero v5 references (no frontmatter/existence linting for the 5 agents, 7 gates, 2 libs).

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/ (untracked); /Users/suraj-devloper/workspace/codingAgent/docs/concepts/v5-design.md (untracked); /Users/suraj-devloper/workspace/codingAgent/scripts/validate.sh

**Fix:** Commit v5/ + docs/concepts/v5-design.md now (parallel-build status is fine for a commit), and extend validate.sh with a v5 section: agent frontmatter schema, gate/lib executability, and referenced-path existence — the last of which would have caught the designer approve/verify break and the bare ledger.sh paths.

### [NOTE] The evidence wall is porous once wired

**What:** The evidence wall is porous once wired: the Bash branch denies only commands that literally mention 'evidence.jsonl' AND contain a redirect-ish token, and whitelists any command containing the substring 'record.sh' — interpreter writes (python -c "open(...,'a')"), glob paths (evid*.jsonl), or 'echo x >> evidence.jsonl # record.sh' all bypass it. Separately, strip_comments' sed fallback (when perl is absent) mishandles single-line HTML comments (range runs to the next '-->' or EOF), which could eat real ledger content including frozen markers.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/hooks/evidence-wall.sh lines 23-27; /Users/suraj-devloper/workspace/codingAgent/v5/gates/lib.sh line 40

**Fix:** In the Bash branch, drop the record.sh substring whitelist in favor of matching the full legitimate invocation shape (^bash .*/lib/record\.sh) and extend detection to interpreter-write idioms; for strip_comments, make the sed fallback handle same-line '-->' or require python3/perl outright (record.sh already requires python-or-fallback anyway).

### [NOTE] Conductor frontmatter lists a nonexistent tool name 'Agent' alongside 'Task' (tools

**What:** Conductor frontmatter lists a nonexistent tool name 'Agent' alongside 'Task' (tools: [Read, Edit, Write, Bash, Agent, Task, TodoWrite]); Task is the real subagent-dispatch tool. Harmless today only because the agent is unregistered.

**Where:** /Users/suraj-devloper/workspace/codingAgent/v5/agents/conductor.md line 6

**Fix:** Drop 'Agent' from the tools list; keep Task.

---

# Part 2 — lifecycle vet: non-happy paths, product iteration, v4 comparison

> Follow-up review 2026-07-07: scenario-based analysis of failure paths and iteration,
> v5 (design + implementation as scaffolded) vs v4 (shipping plugin at repo root).

## Scenario-by-scenario: v4 vs v5

| # | Scenario | v4 | v5 | Edge |
|---|----------|----|----|------|
| S1 | Tests fail during build | EXPLICIT — `all_green` gate, `blocked` return (no orchestrator route for `blocked`) | EXPLICIT — `proven?` block → dispatch `diagnose`; the red run IS the repro | **v5** (failure→repro is structural) |
| S2 | Qualitative review of code | EXPLICIT — evaluator agent + review protocol + fix-round | **ABSENT** — no evaluator, no review step; `proven?` consumes exit codes only | **v4** (biggest regression) |
| S3 | Requirements change mid-feature | EXPLICIT — redirect.md 3-way classify (feedback/scope/pivot), graduated re-approval, `revisions-resolved` check | DESIGNED, NOT MECHANIZED — §7 says "re-opens framed?" but `ledger.sh` has no unfreeze; once the frozen line exists `framed?` passes forever | **v4** |
| S4 | Session death / compaction | EXPLICIT — checkpoint procedure + SessionStart inject + PreCompact breadcrumb; session.md is mutable resume truth the orchestrator must maintain | EXPLICIT + STRUCTURAL — append-only ledger + idempotent gates = resume is a property; fresh session re-enters at "first unmet gate" | **v5** (property beats procedure) |
| S5 | Subagent fabricates results | EXPLICIT — `tests-actually-committed` vs git ground truth + commit-msg hook | STRUCTURAL for verification (prose claims inert; only record.sh writes evidence) but NO artifact check — nothing verifies a build worker actually wrote the files it claims | split — v5 stronger on claims, v4 stronger on artifacts |
| S6 | Parallel same-file conflicts | PARTIAL — plan-time "disjoint files" rule only, zero runtime handling | EXPLICIT design — `isolate=worktree` / disjoint scope, merge-then-prove; but record.sh breaks inside worktrees (no CURRENT) and merge-conflict procedure absent | **v5 design**, broken impl |
| S7 | Deploy failure / rollback | PARTIAL — failed-deploy surfacing explicit; rollback named, no procedure | EXPLICIT — `observed?` fail → rollback to last good `tree_sha` (derivable from evidence.jsonl) then diagnose | **v5** (rollback has trigger + target) |
| S8 | Feature abandoned mid-flight | PARTIAL — `.abandoned/` move offered at 3 entry points; no learnings capture | THIN — "closes as superseded" mentioned only for intent change; no abandon path, no `ledger.sh close` | **v4** |
| S9 | Second feature (brownfield) | EXPLICIT — close-out writes learnings/docs/threads; all agents read them; consumer-repo doc set (README/AGENTS/architecture) generated + checked | EXPLICIT — product.md single durable ledger; ADRs with options/doors/next-seam are stronger decision memory; but consumer-docs generation deleted entirely | split — v5 better decision memory, v4 better docs output |
| S10 | Bug in shipped feature | PARTIAL — diagnose-first rule + touch-up pipeline; no hotfix path | PARTIAL — diagnose kind + arc sizing gives a natural expedited path; no severity triage either | tie |
| S11 | Repeated failure escalation | EXPLICIT — fix-round 3-round hard cap + Round-3 user escalation + context-health signals (3+ failed → debugger; loop detection) | **ABSENT** — no retry cap, no escalation rule; a blocking gate loops forever | **v4** (second biggest regression) |
| S12 | User rejects design repeatedly | PARTIAL — comment-batch triage, archived rounds, no cap | PARTIAL — re-dispatch with comment thread, no cap, no triage rule | v4 slightly |

## Product iteration assessment (v5)

The loop closes by design: ship → observe → learnings → product backlog → frame next.
`product.md` is the single durable memory (vision · current-state · ADRs · backlog ·
learnings · deployments); feature ledgers roll up into it and the next frame reads it.

Strengths:
- ADR discipline (forces, options weighed, one-way doors, **next seam**) makes
  architecture evolution a readable history — materially stronger than v4's
  design-doc + learnings spread across files.
- Arc sizing means iteration N+1 on a stable product pays only the gates that
  apply — no mode switch, no ceremony cliff.
- Append-only product.md serializes concurrent feature sessions (stated constraint).

Gaps:
- **Rollup timing**: ADRs must land in product.md ## decisions BEFORE build
  (architected? reads it now), but the conductor's loop says roll up "at the end."
- **No close primitive**: `ledger.sh` has init/tail/log/freeze — no `close`,
  no archive, no abandoned state. The conductor hand-edits product.md.
- **Learnings only on close**: an abandoned feature's gotchas evaporate (v4 has
  the same gap).
- **Consumer docs deleted**: v4 close-out generates + checks the committed doc set
  (README, AGENTS.md, architecture/dataflow docs) for the user's repo. v5 has no
  equivalent — a real loss for repos other agents/humans will enter.

## Verdict: better or not?

v5 inverts v4's strength profile. v4 is strongest *inside* the pipeline (review,
fix-round ladder, escalation, resume procedure, memory files) and weakest at the
*edges* (parallel runtime safety, rollback, terminal states). v5 redesigned exactly
those edges (worktree parallelism, tree-sha rollback targets, resume-as-property,
fabrication-inert evidence) — and dropped several inside-pipeline muscles on the
assumption the model + gates cover them.

Where v5 is genuinely better:
1. Verification integrity is structural, not policed (record.sh + tree_sha + wall).
2. Recovery is free (append-only ledger + idempotent gates), not a procedure.
3. Ceremony scales continuously (conditional gates), no mode switch.
4. Parallelism model is coherent (stateless workers, single-writer fold).
5. Rollback has a defined trigger and target.
6. Decision memory (ADR w/ next seam) beats v4's doc spread.
7. ~90% less prompt surface to drift (1 loop vs 12 protocols; the chronic
   count-sync and phantom-check failure modes disappear structurally).

What v5 must port from v4 before promotion (in priority order):
1. **A review stage** (S2) — either an 8th kind (`review`) dispatched between
   proven? and clean?, or a reviewed? conditional gate. Exit codes catch breakage,
   not wrong-but-green code, missing acceptance criteria, or security smells.
2. **The two-strike escalation ladder** (S11) — same gate blocks twice with no new
   evidence → stop, surface options to the user (v4 fix-round Round-3 semantics,
   simplified).
3. **Redirect mechanics** (S3) — `ledger.sh revise <section>`: appends a revision
   block, supersedes the prior frozen stamp, framed? checks the LAST stamp.
4. **Artifact ground-truth check** (S5) — conductor verifies a build worker's
   claimed files against `git status` before logging the dispatch (v4's
   tests-actually-committed, one line in the loop).
5. **Close/abandon primitive** (S8) — `ledger.sh close [--abandoned|--superseded]`:
   appends rollup (+ learnings stub even when abandoned) to product.md, clears CURRENT.
6. Optional: keep v4's consumer-docs close-out step for repos that need committed docs.
