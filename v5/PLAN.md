# v5 promotion plan — executable task list

> Self-contained execution plan. An agent picking this up cold should read this
> file top to bottom, then work tasks in order, checking boxes as they land.
> Detailed rationale for every fix lives in [design-vet.md](design-vet.md)
> (26 vetted findings); the canonical design is
> [docs/concepts/v5-design.md](../docs/concepts/v5-design.md).

## Context (read first)

**What v5 is:** a redesign of this plugin around one axiom — *no claim advances
without evidence; evidence is recorded by execution, never written by the agent.*
One conductor (single writer of the ledger) runs a 7-gate pipeline
(`framed? → architected? → designed? → proven? → clean? → shipped? → observed?`)
and dispatches four stateless kind-specific agents:

| agent | kinds |
|---|---|
| `v5/agents/planner.md` | frame, architect |
| `v5/agents/developer.md` | build, prove, diagnose |
| `v5/agents/designer.md` | design |
| `v5/agents/deployer.md` | ship |

Key machinery: `v5/gates/*.sh` (predicates over the ledger),
`v5/lib/record.sh` (the ONLY writer of `evidence.jsonl`),
`v5/lib/ledger.sh` (init/tail/log/freeze), `v5/hooks/` (evidence wall +
session resume — **not yet wired**), `v5/templates/` (product + ledger).
Runtime state lives in the consumer project under `.coding-agent/`.

**Current status:** design validated by a 25-agent adversarial review; the
architecture held, but 3 critical wiring breaks + 10 majors block any real run,
and 3 load-bearing v4 capabilities (review, escalation, redirect) are missing.
v4 (repo root: `agents/`, `protocols/`, `checks/`) keeps working throughout —
nothing here may change v4 behavior.

## Ground rules for the executing agent

1. **Work one task at a time, in order.** Tasks are dependency-ordered.
   Check the box only after its Verify step passes — run it, don't assert it.
2. **`./scripts/validate.sh` must report PASSED before every commit** (after
   T1.1 lands, it also lints v5). This is the repo's hard gate (see AGENTS.md).
3. **One scoped commit per task**, subject `type(v5/<area>): summary`, ending
   with the `Co-Authored-By: Claude` line. CHANGELOG entry per task; version
   bump per phase (patch for Phase 1, minor for Phase 2, major for Phase 3 —
   agents added = major per AGENTS.md semver).
4. **Never touch:** v4 agent prompts, protocols, or checks. The only shared
   file you may edit is `scripts/design-review.sh`, and only additively (new
   subcommand).
5. **Paths:** plugin internals always `${CLAUDE_PLUGIN_ROOT}/...` in prompts;
   never relative `..`.
6. Finding references like *(F: designed-unclearable)* point into
   `v5/design-vet.md` — read the finding before starting the task.

---

## Phase 0 — preserve

- [x] **T0.1 Commit the v5 scaffold as-is.** — done: `e2a4f75`, v4.8.0, validator PASSED.
  Files: `v5/**`, `docs/concepts/v5-design.md`.
  Change: none — snapshot commit before fixes so the vet report's line
  references stay meaningful. CHANGELOG entry (Added: v5 scaffold + design doc
  + vet report), minor bump.
  Verify: `git status` shows no untracked files under `v5/` or `docs/concepts/`;
  `./scripts/validate.sh` PASSED.

---

## Phase 1 — fix (make it correct)

- [x] **T1.1 Extend `scripts/validate.sh` with a v5 section — FIRST, it's the
  regression net for everything after.** — done: 5 v5 checks added; check 4
  (subcommand contract) caught the T1.2 break automatically.
  Checks to add (each prints a line; any failure fails the run):
  1. Every `v5/agents/*.md` has frontmatter keys `name`, `description`,
     `model`, `tools`; name matches filename.
  2. Every `v5/gates/*.sh` and `v5/lib/*.sh` is executable and passes `bash -n`.
  3. Path existence: every `${CLAUDE_PLUGIN_ROOT}/<path>` string referenced in
     `v5/agents/*.md` and `v5/gates/*.sh` resolves to an existing file when
     `CLAUDE_PLUGIN_ROOT` = repo root.
  4. Subcommand contract: every `design-review.sh <word>` invocation in
     `v5/agents/*.md` names a subcommand that appears in
     `scripts/design-review.sh`'s case statement. *(This alone would have
     caught the worst critical.)*
  5. Kind taxonomy: the evidence kinds gates grep for (`test`, `design`,
     `deploy`, `observe`) each appear in at least one agent prompt as a
     `record.sh ... <kind>` instruction.
  Verify: `./scripts/validate.sh` PASSED and prints the v5 section; then break
  one agent frontmatter key locally → validator FAILS → revert.

- [x] **T1.2 Repair the `designed?` evidence chain.** *(F: designed-unclearable — critical)* — done: `verify` subcommand added, designer rewired (human approves), verified end-to-end (block→approve→pass→mutate→block).
  Files: `v5/agents/designer.md`, `scripts/design-review.sh` (additive).
  Change:
  1. designer.md step 1: the designer writes `design.html` into
     `.coding-agent/<slug>/` first, then starts the surface with the feature
     **dir**: `design-review.sh start .coding-agent/<slug>`.
  2. Delete the agent-run `approve` step entirely — the HUMAN approves in the
     browser (the server writes `design-verdict.json` via POST /verdict). The
     designer waits, then records:
     `record.sh "jq -e '.verdict==\"approved\"' .coding-agent/<slug>/design-verdict.json" design`.
  3. Optional hardening: add a `verify <dir>` subcommand to
     `scripts/design-review.sh` that exits 0 iff the verdict is approved AND
     its recorded artifact shas still match (reuse `verify_design_verdict`
     from `checks/lib.sh`); then the record command becomes
     `record.sh "design-review.sh verify .coding-agent/<slug>" design`.
  Verify: in a scratch repo with a fake feature dir: hand-write an approved
  `design-verdict.json` → `v5/gates/designed.sh` passes; delete it → blocks.
  Every subcommand designer.md names exists (validator check 4 green).

- [x] **T1.3 Fix the planner→gate artifact contracts.** *(F: adr-invisible + frozen-false-pass — critical + major)* — done: ADR heading→###+feature anchor, frozen placeholder deleted, framed.sh anchored. Verified both gates block-then-pass.
  Files: `v5/agents/planner.md`, `v5/gates/framed.sh`, `v5/gates/architected.sh`.
  Change:
  1. ADR heading `## ADR —` → `### ADR — <slug> — <title>` and add a
     `feature: <slug>` body line (matches `templates/product.template.md`
     convention; `ledger_section` terminates sections at `^## `, so a level-2
     heading falls OUTSIDE `## decisions`).
  2. Delete the `frozen: agreed @ <placeholder>` line from the frame template;
     reword step 5: "Do not include a frozen: line at all — only the conductor
     adds it via `ledger.sh freeze` after the user agrees."
  3. Anchor `framed.sh`: `grep -q '^> frozen: agreed @'` (matches
     `ledger.sh freeze`'s blockquote output exactly; rejects placeholders).
  4. Move the `touches: ui | api | ...` choose-one guidance out of the pasteable
     artifact body (into planner instructions), so verbatim pastes can't feed
     bogus tag values to conditional gates.
  Verify: paste the frame template verbatim into a scratch ledger → `framed.sh`
  BLOCKS; run `ledger.sh freeze intent` → PASSES. Paste an ADR with `###`
  heading under `## decisions` → `architected.sh` PASSES; with `##` → blocked
  (proving the fix was needed).

- [x] **T1.4 Make `ca_tree_sha` commit-invariant.** *(F: tree-sha-rotates — major)* — done: per-file content hash over ls-files -co; verified invariant across add+commit, changes on edit.
  File: `v5/gates/lib.sh`.
  Change: replace the `rev-parse HEAD + diff HEAD` hash with working-tree
  content hashing:
  `git ls-files -co --exclude-standard -z -- ':(exclude).coding-agent/' | sort -z | xargs -0 shasum -a 256 2>/dev/null | shasum -a 256 | cut -d' ' -f1`
  (invariant across `git add` and `git commit`; changes on real content
  change; keep the existing non-git fallback).
  Verify: in a scratch git repo — record evidence, `git add -A && git commit`,
  re-run `proven?` → still PASSES; edit a source file → BLOCKS.

- [x] **T1.5 Tree-bind `observed?`.** *(F: observed-not-tree-bound — major)* — done: uses evidence_match observe; verified stale observation now blocks.
  File: `v5/gates/observed.sh`.
  Change: replace the raw `grep '"kind":"observe"' ... '"exit":0'` with
  `evidence_match observe` (same helper `shipped?`/`designed?` use).
  Verify: scratch repo — record a passing observe, change a file: `observed.sh`
  now BLOCKS (before the fix it passed).

- [x] **T1.6 Close the conductor's control-loop gaps (one conductor.md edit).**
  *(F: clean-no-owner, missing-branch-routes, first-value-regex, bare-paths,
  rollup-timing, agent-tool-name — majors + minors)*
  Files: `v5/agents/conductor.md`, `v5/gates/designed.sh`,
  `v5/gates/architected.sh`, `v5/gates/shipped.sh`, `v5/gates/observed.sh`.
  Change:
  1. Insert an explicit loop step between `proven?` and `shipped?`: the
     conductor stages and commits (it is the single writer; `clean?` gets an
     owner and its secret/debug scan actually runs pre-commit).
  2. Branch table: add routes for `framed?` (re-engage user / re-dispatch
     frame), `architected?` (dispatch architect; one-way door → user), and
     `clean?` (strip offending lines, re-stage) blocks, plus a default rule:
     any unrouted block → re-dispatch the owning kind once with the gate's
     reason in the brief.
  3. ADR timing: when a planner(architect) returns, the conductor appends the
     ADR to `product.md ## decisions` IMMEDIATELY (architected? reads it before
     build), not at end-of-feature rollup.
  4. Fix conditional-gate regexes in the four conditional gates:
     `grep -qiE 'touches:.*\bui\b'` (and the `deploys:`/`consequential:`
     equivalents) so `touches: api, ui` still applies the design gate.
  5. All `ledger.sh` references become
     `${CLAUDE_PLUGIN_ROOT}/v5/lib/ledger.sh ...` (bare name is not on PATH).
  6. Frontmatter `tools`: drop nonexistent `Agent`, keep `Task` (the real
     dispatch tool).
  Verify: validator PASSED; grep confirms no bare `ledger.sh ` references
  remain in conductor.md; scratch test: `echo 'touches: api, ui' | grep -qiE
  'touches:.*\bui\b'` succeeds.

- [x] **T1.7 record.sh hardening.** *(F: kind-unvalidated + worktree-record — minors)*
  File: `v5/lib/record.sh`.
  Change: (1) validate `kind` against `test|deploy|design|observe|review|run`,
  exit 64 with usage on anything else (prevents workers recording their
  dispatch kind, e.g. `prove`); (2) resolve `.coding-agent/` via the MAIN
  repo root — use `git rev-parse --git-common-dir` — so `record.sh` works
  inside worktree-isolated parallel builds.
  Verify: `record.sh "true" prove` → exits 64 with a clear message;
  `git worktree add /tmp/wt && cd /tmp/wt && record.sh "true" test` appends to
  the main repo's evidence.jsonl (then remove the worktree).

---

## Phase 2 — port (the load-bearing v4 muscles)

- [ ] **T2.1 Add the `review` kind (qualitative review, evidence-honest).**
  *(Lifecycle vet S2 — v5's biggest regression vs v4)*
  Files: `v5/agents/developer.md`, new `v5/gates/reviewed.sh`,
  `v5/agents/conductor.md`, `v5/principles.md`.
  Change:
  1. New kind `review` in developer.md: read the diff since the feature's
     first commit + the intent's acceptance criteria; write findings to
     `.coding-agent/<slug>/review.md` as `- [blocking]` / `- [advisory]`
     lines; then record the evidence-honest verdict:
     `record.sh "test \$(grep -c '^- \[blocking\]' .coding-agent/<slug>/review.md) -eq 0" review`
     (findings file is the artifact; the recorded command proves zero
     blocking findings at the current tree).
  2. New gate `reviewed.sh`: applies when a code change exists;
     `evidence_match review` → pass/block. Pipeline position: after `proven?`,
     before `clean?`. Update the conductor's gate order + dispatch table
     (kind `review` → developer).
  3. Conductor branch route: `reviewed?` blocks → dispatch `build` scoped to
     the blocking findings, then re-dispatch `review` (two-strike rule from
     T2.2 bounds this loop).
  4. principles.md: add a short `review` tier (review the diff against intent,
     not taste; blocking = would fail acceptance/security, advisory =
     everything else; findings cite file:line).
  5. Parallel option (documented in conductor Parallelism section): fan out
     review dimensions (correctness · security · simplicity) as concurrent
     review workers; conductor merges findings files before the verdict record.
  Verify: scratch run — review.md with one `- [blocking]` line → gate blocks;
  fix the line to `- [advisory]` + re-record → passes. Validator PASSED
  (gate script + taxonomy checks green — add `review` to T1.1 check 5 list).

- [ ] **T2.2 Two-strike escalation in the conductor.** *(Lifecycle vet S11)*
  File: `v5/agents/conductor.md`.
  Change: hard rule — if the SAME gate blocks twice with no new evidence ids
  between the two runs, STOP dispatching. Surface to the user: the gate, both
  block reasons, and options (take over manually / revise intent via
  `ledger.sh revise` / abandon via `ledger.sh close --abandoned`). Log the
  escalation line to the ledger before stopping.
  Verify: prompt inspection (rule present, placed in Hard rules) + the W-run
  in T4.2 exercises it with a deliberately unfixable test.

- [ ] **T2.3 Redirect mechanics: `ledger.sh revise`.** *(Lifecycle vet S3)*
  Files: `v5/lib/ledger.sh`, `v5/gates/framed.sh`, `v5/agents/conductor.md`.
  Change: new subcommand `revise <section> "<reason>"` — appends
  `> revision @<ts>: <reason>` to the section. `framed.sh` logic becomes: the
  LAST marker line matching `^> (frozen: agreed|revision) @` must be a
  `frozen:` one (a revision after the last freeze re-opens the gate until the
  user re-agrees and the conductor re-freezes). Conductor requirements-shift
  route points at `revise` + re-freeze.
  Verify: scratch ledger — freeze → framed? PASSES; revise → BLOCKS;
  freeze again → PASSES.

- [ ] **T2.4 Close/abandon primitive: `ledger.sh close`.** *(Lifecycle vet S8)*
  Files: `v5/lib/ledger.sh`, `v5/agents/conductor.md`.
  Change: `close [--abandoned|--superseded]` — appends a rollup skeleton
  (feature summary line, learnings stub, deployment line if any) to
  `product.md`, clears `CURRENT`, and on `--abandoned` renames the feature dir
  to `<slug>.abandoned/`. Learnings stub is written EVEN when abandoned
  (v4 loses these). Conductor end-of-loop step + abandon routes use it.
  Verify: scratch project — `close --abandoned` → product.md gained the
  learnings stub, `CURRENT` empty, dir renamed.

- [ ] **T2.5 Artifact ground-truth check at the fold.** *(Lifecycle vet S5)*
  File: `v5/agents/conductor.md`.
  Change: fold-step rule — after any `build`/`diagnose` dispatch returns, run
  `git status --porcelain` and confirm the files the worker claims in `did`
  actually changed; empty diff + claimed completion = failed dispatch (route
  per branch table, counts toward two-strike).
  Verify: prompt inspection; exercised implicitly by T4 runs.

---

## Phase 3 — wire (make it live)

- [ ] **T3.1 Register the v5 agents in the plugin manifest.**
  Files: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`.
  Change: add the five v5 agent files to the manifest `agents` field. CAUTION:
  if setting `agents` explicitly disables default `agents/` dir discovery,
  list ALL agents (v4's six + v5's five) explicitly — v4 must keep working.
  Names don't collide.
  Verify: fresh `claude` session in a scratch project — dispatching
  `subagent_type: planner` (and each of the other four) resolves; v4's
  `orchestrator` still resolves.

- [ ] **T3.2 Wire the v5 hooks.**
  Files: `hooks/hooks.json` (root), `v5/hooks/*`.
  Change: merge v5's two hook entries into the root hook config in the SAME
  commit as T3.1 (registration without the evidence wall leaves the one law
  unenforced): PreToolUse evidence-wall on `Edit|Write|MultiEdit|Bash`,
  SessionStart v5 resume injector (coexists with v4's SessionStart entry —
  hook arrays run all entries).
  Verify: in a scratch project with an active v5 feature: an Edit targeting
  `evidence.jsonl` is BLOCKED; `record.sh "true" test` still works; new
  session shows the injected v5 resume context AND v4's context.

- [ ] **T3.3 Docs truth pass.**
  Files: `v5/README.md`, `ARCHITECTURE.md`, `docs/README.md`, `AGENTS.md`.
  Change: v5/README Layout block says `conductor.md · worker.md — the two
  system prompts` — update to the five actual agents + gate list; add a v5
  section to ARCHITECTURE.md; sync any counts the validator reports.
  Verify: validator PASSED (count sync); no stale `worker.md` references:
  `grep -rn "worker.md" v5/ docs/ ARCHITECTURE.md` returns nothing.

- [ ] **T3.4 Release commit.** Major version bump (agents added), CHANGELOG
  rollup of phases 1–3, `release: vX.0.0 — v5 wired` commit.
  Verify: validator PASSED; both `.claude-plugin/*.json` carry the new version.

---

## Phase 4 — prove (dogfood before promote)

Test suite: `~/workspace/test-agents/` (W1 greenfield Todo API, W2 fullstack,
W3 brownfield extends W2, W4 session recovery). For each: `rm -rf .coding-agent/`,
start `claude`, paste the PROMPT.md prompt, drive as the user.

- [ ] **T4.1 W1 greenfield through v5.** Success = gates walked in order with
  real evidence: `evidence.jsonl` shows test entries bound to the final tree;
  `framed?` was frozen before any build dispatch; feature closed into
  product.md via `ledger.sh close`.
- [ ] **T4.2 W3 brownfield + forced failures.** Mid-feature: (a) inject a
  requirement change → conductor must use `revise` + re-freeze, not hand-edit;
  (b) make one test unfixable for a round → two-strike escalation must fire
  and stop dispatching. Success = both behaviors observed in the ledger log.
- [ ] **T4.3 A/B same feature, v4 vs v5.** Pick one real small feature on a
  dogfood project (`~/workspace/personal` or `personal-knowledge-base`), run
  it through v4 in one worktree and v5 in another. Record: total tokens,
  wall-clock, dispatch count, gates/checks hit, defects found later. Evidence
  for the comparison comes from `evidence.jsonl` (v5) and `session.md` action
  log (v4). Write the numbers into `v5/design-vet.md § Part 3`.
- [ ] **T4.4 W4 session recovery.** Kill the session mid-build; fresh session
  must resume at the first unmet gate from the injected ledger tail with no
  recovery prompt needed. Success = conductor's first action is a gate run,
  not a question.

---

## Phase 5 — promote (gated on Phase 4 data)

Only if T4.1–T4.4 pass and the A/B numbers don't regress:

- [ ] **T5.1** Make the conductor the default entry (marketplace description,
  README, CLAUDE.md routing) with v4 available behind an explicit ask.
- [ ] **T5.2** Deprecation notes on the 12 v4 protocols pointing at their v5
  equivalent (gate/route/kind); no deletions for one release cycle.
- [ ] **T5.3** Migration note for existing `.coding-agent/` consumer projects
  (v4 artifacts stay readable; new features open v5 ledgers).

---

## Done means

- All boxes checked, validator PASSED at head.
- A fresh session in a scratch project can run a feature end-to-end through
  the conductor: frame → freeze → build → prove → review → clean/commit →
  close, with every gate transition backed by an `evidence.jsonl` entry.
- v4 flows still pass W1 untouched.
