# v5 promotion plan — executable task list

> Self-contained execution plan. An agent picking this up cold should read this
> file top to bottom, then work tasks in order, checking boxes as they land.
> Detailed rationale for every fix lives in [design-vet.md](design-vet.md)
> (26 vetted findings); the canonical design is
> [docs/concepts/v5-design.md](../docs/concepts/v5-design.md).

## Context (read first)

**What v5 is:** a redesign of this plugin around one axiom — *no claim advances
without evidence; evidence is recorded by execution, never written by the agent.*
One conductor (single writer of the ledger) runs an 8-gate pipeline
(`framed? → architected? → designed? → proven? → reviewed? → clean? → shipped? → observed?`)
and dispatches five stateless kind-specific agents:

| agent | kinds | effort |
|---|---|---|
| `v5/agents/planner.md` | frame, architect | xhigh |
| `v5/agents/developer.md` | build, prove, review | high |
| `v5/agents/diagnostician.md` | diagnose | xhigh |
| `v5/agents/designer.md` | design | high |
| `v5/agents/deployer.md` | ship, rollback | high |

Effort follows cognitive load, not tool surface: the two kinds whose failure
mode is *a wrong mental model* (an unweighed one-way door, a confident fix for
the wrong cause) get maximum reasoning depth.

Key machinery: `v5/gates/*.sh` (predicates over the ledger),
`v5/lib/record.sh` (the ONLY writer of `evidence.jsonl`),
`v5/lib/ledger.sh` (init/product-init/tail/log/blocks/freeze/revise/incident/rollback/close),
`v5/hooks/` (evidence wall + session resume), `v5/templates/` (product +
ledger), `evals/` (scenario prompts + deterministic asserts).
Runtime state lives in the consumer project under `.coding-agent/`.

**Current status (2026-07-25):** Phase A is complete — all 18 tasks landed and
verified, `00-smoke` covers them with 38 green assertions, validator PASSED.
Phase 4 (dogfooding) is now unblocked.

**Prior status (2026-07-24):** Phases 0–3 are done — v5 is wired and
dispatchable (v5.1.0), and the vet's criticals plus the three load-bearing v4
muscles (review, escalation, redirect) have landed. A second audit pass —
comparing v5's flow against mainline v4 beat by beat, then against the v4
CHANGELOG's scar record and the dogfood projects' `learnings.md` — found 18
further items, tracked below as **Phase A**. Several are v4 lessons that were
paid for in production and did not survive the redesign. **Phase A blocks
Phase 4** (dogfooding against a system with a known false-green path produces
untrustworthy A/B numbers).

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

- [x] **T2.1 Add the `review` kind (qualitative review, evidence-honest).**
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

- [x] **T2.2 Two-strike escalation in the conductor.** *(Lifecycle vet S11)*
  File: `v5/agents/conductor.md`.
  Change: hard rule — if the SAME gate blocks twice with no new evidence ids
  between the two runs, STOP dispatching. Surface to the user: the gate, both
  block reasons, and options (take over manually / revise intent via
  `ledger.sh revise` / abandon via `ledger.sh close --abandoned`). Log the
  escalation line to the ledger before stopping.
  Verify: prompt inspection (rule present, placed in Hard rules) + the W-run
  in T4.2 exercises it with a deliberately unfixable test.

- [x] **T2.3 Redirect mechanics: `ledger.sh revise`.** *(Lifecycle vet S3)*
  Files: `v5/lib/ledger.sh`, `v5/gates/framed.sh`, `v5/agents/conductor.md`.
  Change: new subcommand `revise <section> "<reason>"` — appends
  `> revision @<ts>: <reason>` to the section. `framed.sh` logic becomes: the
  LAST marker line matching `^> (frozen: agreed|revision) @` must be a
  `frozen:` one (a revision after the last freeze re-opens the gate until the
  user re-agrees and the conductor re-freezes). Conductor requirements-shift
  route points at `revise` + re-freeze.
  Verify: scratch ledger — freeze → framed? PASSES; revise → BLOCKS;
  freeze again → PASSES.

- [x] **T2.4 Close/abandon primitive: `ledger.sh close`.** *(Lifecycle vet S8)*
  Files: `v5/lib/ledger.sh`, `v5/agents/conductor.md`.
  Change: `close [--abandoned|--superseded]` — appends a rollup skeleton
  (feature summary line, learnings stub, deployment line if any) to
  `product.md`, clears `CURRENT`, and on `--abandoned` renames the feature dir
  to `<slug>.abandoned/`. Learnings stub is written EVEN when abandoned
  (v4 loses these). Conductor end-of-loop step + abandon routes use it.
  Verify: scratch project — `close --abandoned` → product.md gained the
  learnings stub, `CURRENT` empty, dir renamed.

- [x] **T2.5 Artifact ground-truth check at the fold.** *(Lifecycle vet S5)*
  File: `v5/agents/conductor.md`.
  Change: fold-step rule — after any `build`/`diagnose` dispatch returns, run
  `git status --porcelain` and confirm the files the worker claims in `did`
  actually changed; empty diff + claimed completion = failed dispatch (route
  per branch table, counts toward two-strike).
  Verify: prompt inspection; exercised implicitly by T4 runs.

---

## Phase 3 — wire (make it live)

- [x] **T3.1 Register the v5 agents in the plugin manifest.**
  Files: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`.
  Change: add the five v5 agent files to the manifest `agents` field. CAUTION:
  if setting `agents` explicitly disables default `agents/` dir discovery,
  list ALL agents (v4's six + v5's five) explicitly — v4 must keep working.
  Names don't collide.
  Verify: fresh `claude` session in a scratch project — dispatching
  `subagent_type: planner` (and each of the other four) resolves; v4's
  `orchestrator` still resolves.

- [x] **T3.2 Wire the v5 hooks.**
  Files: `hooks/hooks.json` (root), `v5/hooks/*`.
  Change: merge v5's two hook entries into the root hook config in the SAME
  commit as T3.1 (registration without the evidence wall leaves the one law
  unenforced): PreToolUse evidence-wall on `Edit|Write|MultiEdit|Bash`,
  SessionStart v5 resume injector (coexists with v4's SessionStart entry —
  hook arrays run all entries).
  Verify: in a scratch project with an active v5 feature: an Edit targeting
  `evidence.jsonl` is BLOCKED; `record.sh "true" test` still works; new
  session shows the injected v5 resume context AND v4's context.

- [x] **T3.3 Docs truth pass.**
  Files: `v5/README.md`, `ARCHITECTURE.md`, `docs/README.md`, `AGENTS.md`.
  Change: v5/README Layout block says `conductor.md · worker.md — the two
  system prompts` — update to the five actual agents + gate list; add a v5
  section to ARCHITECTURE.md; sync any counts the validator reports.
  Verify: validator PASSED (count sync); no stale `worker.md` references:
  `grep -rn "worker.md" v5/ docs/ ARCHITECTURE.md` returns nothing.

- [x] **T3.4 Release commit.** Major version bump (agents added), CHANGELOG
  rollup of phases 1–3, `release: vX.0.0 — v5 wired` commit.
  Verify: validator PASSED; both `.claude-plugin/*.json` carry the new version.

---

## Phase A — audit repair (blocks Phase 4)

> From the 2026-07-24 second-pass audit: a beat-by-beat v4↔v5 flow comparison,
> a scale test (240-line ledger / 2000 evidence entries / 12-feature product
> ledger), and a sweep of the v4 CHANGELOG + both dogfood projects'
> `learnings.md`. Provenance markers: *(v4: <version>)* means v4 already paid
> for this lesson in production — read that CHANGELOG entry before starting.
>
> Ordering is by damage, not by effort. TA1–TA6 are the ones that let wrong
> work through; nothing downstream is trustworthy until they land.

### A0 — safety and verification integrity

- [x] **TA1 Stop staging `.coding-agent/`; add the gitignore preflight.** — done: conductor stages scoped; session-start writes the gitignore line. Verified: fresh repo gets `.coding-agent/`, idempotent, no `git add -A` left in v5.
  *(v4: 2.2.0 — real data loss)*
  Files: `v5/agents/conductor.md`, `v5/hooks/session-start.sh`.
  Change: (1) conductor step 7 currently prescribes `git add -A` — the exact
  command v4 banned after coordinator artifacts were swept into a commit and
  then erased by a later `git reset --hard`. Replace with scoped staging:
  `git add -- . ':(exclude).coding-agent'`, or stage only the paths the worker
  reported in `did`. (2) v5 has no gitignore preflight anywhere; add one to
  `session-start.sh` — if `.gitignore` lacks a `.coding-agent/` line, append it
  before anything else writes to that directory. Non-skippable, same as v4.
  Verify: scratch repo with no `.gitignore` → open a v5 session → `.gitignore`
  contains `.coding-agent/`; `grep -rn 'git add -A' v5/` returns nothing.

- [x] **TA2 Fix the `clean?` sequence — it currently scans an empty stage.** — done: stage → clean? → commit. Verified: unstaged secret = n/a, staged secret = block.
  File: `v5/agents/conductor.md` (step 7).
  Change: the prescribed order is `clean?` → `git add` → commit, but
  `clean.sh` reads `git diff --cached` and returns `n/a "nothing staged"` when
  nothing is staged — so the secret / debug-print scan never sees the diff it
  exists to scan. Reorder to: stage (per TA1) → `clean?` → commit. Never commit
  past a `clean?` block.
  Verify: scratch repo — write a line containing `api_key = "x"`, stage it,
  run `clean.sh` → BLOCKS. Unstaged → `n/a`. Confirm the prompt's order matches.

- [x] **TA3 Restore the multi-tier proof gate.** — done: `tiers:` in the intent, tier label on evidence, `proven?` requires every declared tier. Verified: one green tier names the missing one; hollow kind=run inert; survives commit, dies on edit. *(v4: 4.5.0 — the headline fix)*
  Files: `v5/lib/record.sh`, `v5/gates/proven.sh`, `v5/agents/developer.md`,
  `v5/templates/ledger.template.md`.
  Change: `proven?` passes on ONE `kind=test` entry at the current tree, so a
  single narrow green run clears it — exactly the proxy-verification failure
  v4.5.0 diagnosed (*"the implementor recorded one self-chosen command as
  verified, while the binding rules lived only as prose"*). `developer.md:85`
  now carries that same insufficient prose. Make it structural:
  1. The frame declares its tiers — add a `tiers:` line to the intent block
     (e.g. `tiers: typecheck, unit, e2e`), authored by the planner.
  2. `record.sh` takes an optional tier label: `record.sh "<cmd>" test <tier>`,
     written into the entry as `"tier":"<name>"`.
  3. `proven.sh` passes only when **every** declared tier has a green entry at
     the current tree; the block reason names the missing/red tiers.
  Verify: scratch — declare `tiers: unit, e2e`; record only `unit` green →
  `proven?` BLOCKS naming `e2e`; record `e2e` green → PASSES; edit a source
  file → BLOCKS again (tree moved).

- [x] **TA4 Make agreement evidence, not a self-written stamp.** — done: `freeze --answer` records the reply; `framed?` rejects a marker without one; one-way-door ADRs need `user agreed:`. Conductor gained AskUserQuestion. Verified block→pass→revise→block.
  *(v4: 4.7.0 root cause — "the model took the cheaper path by preference")*
  Files: `v5/agents/conductor.md`, `v5/lib/ledger.sh`, `v5/gates/framed.sh`,
  `v5/gates/architected.sh`.
  Change: `framed?` passes on a `> frozen: agreed @` blockquote that **the
  conductor writes itself** — and the conductor's `tools:` has no
  `AskUserQuestion`, so it cannot ask but can stamp. This is 4.7.0's failure
  mode relocated to a different gate, and this time there is no missing
  verdict file to detect it by. Minimum fix: add `AskUserQuestion` to the
  conductor's tools and require the freeze to carry the answer it received
  (`freeze intent --answer "<user's verbatim reply>"`, recorded in the marker).
  Stronger fix, preferred if the design-review surface can take a text
  artifact: route intent + ADR through the surface like `designed?` already is,
  so agreement produces sha-bound evidence and the cheap path stops existing.
  Pick one, record which in the task when it lands.
  Verify: a conductor that never asked cannot produce a passing `framed?`;
  eval `05-design-gate`'s self-approval-resistance assertion extended to cover
  `framed?`.

- [x] **TA5 Give `review.md` a schema the gate actually reads.** — done: `review.template.md` + `reviewed?` reads the artifact (findings section, malformed-bullet detection, placeholder rejection) as well as the evidence. Verified: `* [blocking]` no longer records clean.
  Files: `v5/agents/developer.md`, new `v5/templates/review.template.md`,
  `v5/gates/reviewed.sh`.
  Change: `reviewed?` consumes an evidence entry whose recorded command is
  `test $(grep -c '^- \[blocking\]' review.md) -eq 0`. The artifact's Markdown
  convention is therefore load-bearing but is defined only in one agent's
  prose — a worker writing `* [blocking]` or an indented bullet records a
  clean verdict with findings on the page. Add a template with a required
  header and a machine-readable findings block, and have the recorded command
  count against that structure (or have `reviewed.sh` parse the artifact and
  cross-check the evidence entry's count).
  Verify: a `review.md` with a `* [blocking]` line (wrong marker) must NOT
  produce a passing verdict.

- [x] **TA6 Live-path evidence for user-facing changes.** — done: `proven?` blocks a `touches: ui` intent that declares no `e2e` tier; developer must drive and screenshot the real flow.
  *(v4: 4.4.0 / 4.5.0 + three dogfood incidents: `useForecast`, `useSuggestions`,
  `kbCounts` — green tests, dead feature)*
  Files: `v5/agents/developer.md`, `v5/gates/proven.sh` (or a new gate).
  Change: v4 blocks review PASS on UI projects with the `ui-evidence` check;
  v5 has one prose bullet the vet already flagged as satisfiable by a
  home-page screenshot. When the intent has `touches: … ui …`, require an
  `e2e` tier entry (per TA3) that drove the feature flow — navigate, interact,
  assert the user-visible result — plus a recorded screenshot path.
  Verify: a UI-tagged feature with unit-only evidence must not clear `proven?`.

### A1 — restore what regressed from structure to prose

- [x] **TA7 Split agents by reasoning depth; restore the `xhigh` tier.** — done: `diagnostician` split out at `effort: xhigh` (carries v4 debugger method + `debugging`/`observability`); `planner` raised to xhigh. **Deviation:** the architect kind stays on `planner` rather than getting its own agent — `architect` is taken by the v4 agent while both coexist, and a renamed near-duplicate reads worse than one xhigh agent covering frame+architect. Revisit at Phase 5 when v4 retires.
  Files: `v5/agents/*.md`, new `v5/agents/diagnostician.md`, new
  `v5/agents/architect.md`, `v5/agents/conductor.md` (dispatch table),
  `.claude-plugin/plugin.json`.
  Change: every v5 agent is `effort: high`; v4 deliberately ran architect,
  debugger and product-lead at `xhigh` because *"the irreversible-judgment
  roles get maximum reasoning depth where a wrong call cascades"* (4.1.0).
  Because `effort` is per-agent frontmatter and `developer` covers
  build · prove · diagnose · review under one setting, running a test suite and
  root-causing a wrong mental model get identical reasoning depth. v5 grouped
  kinds by **tool surface**; regroup by **cognitive load**:

  | kind | agent | effort |
  |---|---|---|
  | `diagnose` | `diagnostician` (new; port `agents/debugger.md`'s method + its `debugging`/`observability` skills) | xhigh |
  | `architect` | `architect` (new; split out of planner) | xhigh |
  | `frame` | `planner` | high |
  | `build` · `prove` | `developer` | high |
  | `review` | `reviewer` (or keep on developer) | high |
  | `design` | `designer` | high |
  | `ship` | `deployer` | high (sonnet) |

  Verify: `grep -c 'effort: xhigh' v5/agents/*.md` ≥ 2; validator PASSED; every
  new agent registered in the manifest and dispatchable.

- [x] **TA8 Complete the craft plane.** — done: four missing tiers added (frame · diagnose · design · ship); thinking & context discipline ported into conductor.md. Validator now fails on a dangling anchor or a kind with no tier.
  Files: `v5/principles.md`, `v5/agents/conductor.md`.
  Change: (1) `conductor.md:79` says each agent reads `principles.md#<kind>`
  for all eight kinds, but only `operating · build · prove · review ·
  architect` exist — `frame`, `diagnose`, `design` and `ship` dangle, and
  `diagnose` (the hardest mode) has no tier at all. Add the four, or state the
  real mapping explicitly. (2) v5 has **no** thinking guidance anywhere
  (`grep -riE "interleav|think hard|thinking" v5/` → nothing); port
  `orchestrator.md`'s "Thinking & context discipline" into `conductor.md` —
  think hard at irreversible decisions, don't spend it on mechanical state
  edits, plus 2.1.0's interleaved-thinking expectation for diagnose/architect.
  Verify: every `principles.md#<anchor>` referenced in any v5 agent resolves to
  a real heading — add this to `validate.sh`'s v5 section.

- [x] **TA9 Wire skills.** — done: skills preloaded per agent + a dispatch routing table in conductor.md. Validator fails on a skill that does not exist.
  Files: `v5/agents/*.md` (frontmatter), `v5/agents/conductor.md`.
  Change: the design doc's dispatch schema has a `skills=[…]` field; no v5
  agent declares `skills:` and no prompt names one, so all 58 are unreachable
  from the v5 path. Preload the always-on set per agent (developer: `tdd`,
  `test-doubles-strategy`, `security-checklist`, `load-bearing-markers` —
  mirroring `implementor.md`) and give the conductor a routing table for
  domain skills at dispatch, the way `plan-writing.md` routes them today.
  Note `principles.md` is not a substitute: principles are stack-agnostic
  craft; skills carry project-shaped knowledge.
  Verify: validator check — every skill named in a v5 agent's frontmatter or
  routing table exists under `skills/`.

- [x] **TA10 Add the disclosure field to the return contract.** — done: `skipped_or_assumed` on all five return contracts; conductor folds it into the log line.
  *(design-vet finding, never actioned)*
  Files: all `v5/agents/*.md`, `v5/agents/conductor.md`,
  `docs/concepts/v5-design.md` §4.
  Change: operating principle 5 ("Say what you didn't do") has no carrier —
  the four-field return spine has no slot for a skipped tier or an assumption
  proceeded on, and the conductor is told to distrust prose. Add
  `skipped_or_assumed: [<…> | none]`; conductor loop step 5 folds it into the
  `## log` line.
  Verify: prompt inspection + the field appears in a ledger log line during a
  Phase 4 run.

- [x] **TA11 Close the learnings loop.** — done: workers read `product.md ## learnings` (what v5 actually writes); `close --learnings` files the entry there.
  Files: `v5/agents/developer.md`, `v5/agents/conductor.md`,
  `v5/lib/ledger.sh`.
  Change: `developer.md:44` tells every build worker to read `learnings.md` —
  **nothing in v5 writes that file**; `close` writes learnings into
  `product.md ## learnings`, and no prompt points a worker there. Read side and
  write side are aimed at different files, so the loop is open at both ends.
  Point workers at `product.md ## learnings` (sliced, per TA13), and have the
  conductor append a learnings entry at close from what the run surfaced.
  Verify: scratch — close a feature with a learning, start the next, confirm
  the dispatch brief carries it.

- [x] **TA12 Reject placeholder rollups.** — done: `close` requires --summary/--learnings/--deployment and exits 64 on a partial rollup.
  Files: `v5/lib/ledger.sh`, new `v5/gates/closed.sh` (or `close --check`).
  Change: `close` writes literal `<one line — what this feature did>` /
  `<what this taught us …>` and nothing checks they were filled. Measured: 12
  of 12 rollups unfilled after a simulated 12-feature run — the product memory
  degrades at exactly the rate you ship. Make `close` refuse (or a `closed?`
  gate block) while any `<…>` placeholder remains in the new block.
  Verify: `close` with unfilled stubs → non-zero exit naming the fields.

- [x] **TA13 ADR supersession + a product-ledger slice for workers.** — done: `superseded-by:` honoured by `architected?`; planner reads a product slice, not the file.
  Files: `v5/templates/product.template.md`, `v5/agents/planner.md` (and the
  new `architect.md`), `v5/gates/architected.sh`, `v5/agents/conductor.md`.
  Change: (1) ADRs append forever with no supersession — measured 0 markers
  after 8 decisions, so ADR-7 can reverse ADR-2 and both read as current. Add
  an optional `supersedes: ADR-<n>` line; `architected?` reads only
  non-superseded ADRs. (2) `planner.md:61` tells the worker to read
  `product.md` whole on every frame; at feature 50 that is every ADR and every
  rollup in context. The conductor already sends *slices* of the feature
  ledger — apply the same discipline: vision + current-state + live ADRs only.
  Verify: mark an ADR superseded → `architected?` no longer counts it; the
  frame dispatch brief contains a slice, not the file.

- [x] **TA14 Make strike 1 durable.** — done: every block is logged; `ledger.sh blocks <gate>` derives the strike count from disk.
  File: `v5/agents/conductor.md`.
  Change: the two-strike rule logs only the **second** block, so after a
  compaction the conductor sees a first block it has no record of and
  dispatches again — measured: 24 escalation records in a 240-line log, 1
  visible in `ledger.sh tail 30`, **0** in the SessionStart 24-line inject.
  Log **every** gate block to the ledger, and derive the strike count by
  reading back the log rather than from working memory.
  Verify: eval `03-escalation` extended — kill and resume the session between
  the two blocks; escalation must still fire.

### A2 — steady state (long-lived products, ad-hoc incidents)

> These close the gap the arc-shaped design never modelled: a product you
> operate for years, where a hotfix interrupts a feature and a bad deploy
> needs an ad-hoc entry.

- [x] **TA15 `CURRENT` becomes a stack; mark the interrupted feature.** — done: `CURRENT` is a stack — `init` pushes with an `interrupted by` marker, `close` pops back.
  Files: `v5/lib/ledger.sh`, `v5/hooks/session-start.sh`,
  `v5/agents/conductor.md`.
  Change: measured — starting a hotfix mid-feature silently repoints `CURRENT`,
  nothing records that the feature was interrupted, and `close` leaves
  `CURRENT` **empty** rather than restoring the previous slug. The interrupted
  work survives on disk but the system loses its place. Make `init` push and
  `close` pop; append a `> interrupted @<ts>: <why>` marker to the ledger being
  pushed off; SessionStart surfaces the stack, not just the top.
  Verify: init A → init B → close B → `CURRENT` is A, and A's ledger carries
  the interrupted marker.

- [x] **TA16 Give rollback an executor.** — done: `ledger.sh rollback` derives the last deploy confirmed healthy by a later observe (with its `head`); deployer gained a `rollback` kind that executes it.
  Files: `v5/lib/ledger.sh`, `v5/agents/deployer.md`,
  `v5/agents/conductor.md`.
  Change: rollback is routed to nobody — `conductor.md:98` says *"rollback to
  the last good tree, then diagnose"* but the conductor never deploys;
  `deployer.md:69` says *"Rollback is the conductor's call… do not initiate
  rollback yourself."* Each defers to the other, and there is no `rollback`
  kind and no `ledger.sh rollback`. Add a `rollback` kind on the deployer whose
  target is derived from `evidence.jsonl` (last `kind=deploy` with a green
  `observe` after it), recorded as its own evidence entry.
  Verify: scratch — record deploy+observe green, then deploy+observe red;
  `ledger.sh rollback --dry-run` names the correct target tree sha.

- [x] **TA17 Incident entry: a red observation can be the frame.** — done: `ledger.sh incident <slug> --from <f> --evidence <id>` builds the intent from a failing run; refuses a green one. Agreement is still required, the planner round-trip is not.
  Files: `v5/gates/framed.sh`, `v5/agents/conductor.md`.
  Change: the loop always starts at `framed?`, which is unconditional — so a
  production incident cannot begin until an intent is drafted, agreed and
  frozen. v4 has an explicit escape (*"Bug reports — diagnose first… dispatch
  `debugger` BEFORE classifying size"*). Allow `framed?` to accept a failing
  `kind=observe`/`kind=test` entry as the frame — the intent of a hotfix is
  literally *make evidence #N green* — with the user's one-line confirm as the
  freeze. Keeps the axiom (evidence, not prose) and deletes the round-trip.
  `proven?` is then satisfied only when that exact recorded command flips green.
  Verify: new eval scenario — record a red health check, confirm the arc can
  reach `diagnose` without a planner dispatch, and that `proven?` keys off the
  original failing command.

### A3 — lock it in

- [x] **TA18 Eval coverage for Phase A.** — done: 00-smoke rewritten: 38 assertions covering every task above, all green. Three new validator checks.
  Files: `evals/scenarios/**`, `evals/lib.sh`, `scripts/validate.sh`.
  Change: every task above that changes behavior gets an assertion, since the
  point of the harness is that fixes stay fixed. At minimum: `08-tier-proof`
  (TA3), `09-agreement` (TA4, extends 05), `10-incident` (TA17),
  `11-interleave` (TA15), plus resume-mid-escalation added to `03` (TA14) and
  a staging-safety assertion (TA1) in `00-smoke`. Add the two new validator
  checks named in TA8 and TA9.
  Verify: `evals/run.sh 00-smoke` green; each new scenario fails against
  today's head and passes after its task lands (record both runs).

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

Only if Phase A is complete and T4.1–T4.4 pass with no A/B regression:

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
