# Changelog

All notable changes to this plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [7.0.0] — 2026-09-27 — Goal-driven runtime: measured against native Claude Code

The plugin now has a measured goal: beat native Claude Code on quality without
losing on cost or time (`bench/GOAL.md`). The first baseline showed v6.1 at the
same hidden-test quality as native for **7.2× the cost and 3.5× the wall time**.
The causes were structural, so this release changes the runtime's shape.

### Changed (breaking)

- **The conductor builds.** In the quick and standard lanes the main loop
  writes the code itself; specialists are dispatched only where a separate agent
  adds judgment (independent review, architecture, diagnosis, design surface,
  deployment). Deep-lane builds still go to developer workers. Delegating every
  build meant each worker re-read the code from scratch.
- **Lanes: quick, standard, deep.** Lanes change ceremony, never proof. The
  quick lane skips review only while `reviewed?` measures the diff since the
  recorded base at ≤ 150 lines with no `ui`/`consequential`/`deploys` tag;
  beyond that it blocks.
- **Every role uses `model: inherit`.** v6.1 forced Opus on every role even
  when the user's session ran a cheaper model.

### Added

- **`lib/ca.sh`**: the loop's bookkeeping as one command each (`next`,
  `start [--answer … < frame]`, `frame`, `prove`, `verdict`, `waive design`,
  `commit`, `close`). Every step prints the next action.
- **Design-review waiver.** `designed?` passes when the user declined visual
  review in their own words (`ca waive design --answer`).
- **Cheaper review.** The conductor updates docs before review (a later change
  re-opens `proven?`), dispatches the reviewer in the foreground instead of
  polling, and asks for a delta re-review of the fixed findings only.
  `ca next` lists uncommitted paths when it says to commit. Advisory findings
  are logged for follow-up instead of fixed mid-feature, since any code change
  after review costs a re-review.

### Fixed

- **`clean?` false positives.** It blocked `print(` (a CLI's output) and any
  `token =` / `password:` line, which fired on 3 of 4 complex bench runs and
  each time forced a rewrite plus another review round. It now blocks
  high-confidence key formats, secret-named keys assigned a long non-placeholder
  literal outside test files, and debugger statements.
- **Verdicts over unreviewed code.** `ca verdict` refuses when any non-doc file
  changed after `review.md` was written, so a post-review code change needs a
  (delta) re-review; docs-only follow-ups don't.
- **Principles referenced but never read.** Transcripts showed neither the
  conductor nor the reviewer ever opened `principles.md`; the reviewer even
  found the `LIKE` defect and filed it as advisory. The two defect classes and
  the rule "a behavior contradicting the request's wording is blocking" now
  live in the prompts the agents actually load (conductor build steps,
  developer review section), and the reviewer runs the change before writing
  findings.
- **Review misses by luck.** Two v7 runs of the same task differed only in
  whether the reviewer happened to check the error contract on unhandled
  methods and SQL `LIKE` escaping. `principles.md` now names both defect classes
  in the review tier, and the build tier asks for a test per stated rule
  (including error formats and literal inputs).
- **Generated files in commits.** `ca commit` refuses `__pycache__`, `*.pyc`,
  `node_modules`, build output and `.DS_Store`, and says to ignore them.
- **`bench/`**: a two-arm benchmark. The same tasks run under native Claude
  Code and under the plugin (loaded via `--plugin-dir`, as users install it),
  scored by hidden acceptance tests the agents never see. Tasks: a small
  maintenance fix, a medium REST service, and two complex apps (an issue
  tracker with auth and a state machine; a booking engine with expiring holds
  and a FIFO waitlist), each with a later change-request phase that is also
  regression-tested, plus a multi-process job queue (leases, retries with
  backoff, dead-lettering, 8 concurrent worker processes in the hidden tests). `bench/GOAL.md` + `goal.json` set the targets: quality at
  least native (and +10 points on complex work), cost and time no worse
  suite-wide. `bench/selftest.sh` proves every hidden suite passes on a
  reference implementation and fails on the starting state.

## [6.1.0] — 2026-09-25 — Close the design, commit, and staging holes

An end-to-end and adversarial review of 6.0.0 against 4.3.0 found that the
design gate could be satisfied without a human, that nothing stopped a commit
past an unmet gate, and that the UI arc could not finish once built. This
release closes those gaps and brings the runtime docs in line with the code.

### Added

- **Git pre-commit gate** (`hooks/pre-commit.sh`, installed as a shim by
  `ledger.sh init` and refreshed by `session-start.sh`). While a feature is
  active it runs `framed?` through `clean?` and refuses the commit at the first
  block, regardless of the commit message. It is a no-op with no active feature,
  never overwrites a foreign hook, and skips a managed `core.hooksPath`. This
  restores and extends the commit wall 4.x had through its commit-msg hook.
- **`architecture-visualization` skill** carried over from `main` (4.3.0 there),
  which this branch had diverged from. It is routed from the conductor's skills
  table. Inventory is 59 → 60 skills.
- **Smoke assertions** for each fix: 48 → 61 checks.
- **`08-wall-integrity` eval** (script-only, zero-cost like `00-smoke`):
  install scope, foreign-hook and `core.hooksPath` safety, stale-shim refresh,
  refusals naming the blocking gate, no-op with no active feature, every
  evidence-wall write route, and a self-test that the bypass detectors fire.
- **The pre-commit gate leaves a trace.** It runs its check through
  `record.sh` as `kind=run tier=commit`, so every gated commit has green
  evidence at its parent. A `--no-verify` commit has none.
- **Model scenarios assert the wall held.** New helpers
  `ev_commit_gate_intact`, `ev_every_commit_gated`, and
  `ev_state_never_committed` are wired into 01–07 as each scenario allows.
  05 also requires the look-contract to exist and no commit to land without
  approval.

### Fixed

- **`designed?` accepted any recorded `kind=design` command.**
  `record.sh "true" design` passed the one gate that needs a human. The gate now
  re-verifies `design-verdict.json` against `design.html` (approved, zero open
  comments, matching SHA) on every run, and still requires the recorded entry.
- **The UI arc could never reach `proven?`.** Design approval was bound to the
  source tree, so the build that implemented the approved design re-opened
  `designed?`. Approval now binds to the look-contract (`design.html`) instead.
  Editing `design.html` still re-opens the gate.
- **`design-review.sh verify` failed after any ledger log line.** It bound
  approval to `ledger.md`, which the conductor appends to after every dispatch.
  Verify now binds to `design.html`; the verdict keeps `ledger_sha` for audit.
- **`clean?` passed force-staged coordinator state.** It now blocks any staged
  path under `.coding-agent/`, which the architecture already claimed.
- **Evidence wall let interpreter writes through.** It now also denies
  in-place editors, file-moving tools, and Python/Perl/Node/Ruby writes that
  name `evidence.jsonl`, while still allowing reads (including `2>/dev/null`).
  It also covers `NotebookEdit`. The docs now say plainly that the wall is an
  accident guard, not a security boundary.
- **Review read `...HEAD` although review runs before the commit.** The
  developer's review now diffs the working tree against the base and lists
  untracked files. When the intent touches UI, departing from the approved
  `design.html` counts as a blocking finding.
- **Codex skipped the lifecycle preflight.** `delivery-pipeline` now runs
  `hooks/session-start.sh` explicitly (gitignore, commit gate, resume state).

### Changed

- README, ARCHITECTURE, AGENTS, CONTRIBUTING, concept docs, and the evals guide
  now describe the commit wall, the design-approval binding, the evidence
  wall's real limits, the non-root requirement for headless evals, and 60
  skills. AGENTS no longer claims the skill count is derived when the validator
  pins it.

## [6.0.0] — 2026-09-06 — Canonical evidence-gated runtime

### Added

- **Finished high-level and component-level architecture documentation** — the
  landing page, architecture reference, primitives, workflow, lifecycle,
  contributor guide, and eval guide now document one production runtime with
  consistent diagrams, ownership tables, trust boundaries, and cross-links.
- **Delivery plans are part of framing** — the planner returns both intent and
  bounded ordered steps; `framed?` blocks until both are concrete and the user
  agrees to the frame.
- **Canonical-layout validation** — the self-validator derives inventory,
  verifies both manifests, role frontmatter, executable gates, evidence/design
  invariants, plugin-root links, documentation links, stale runtime paths, shell
  syntax, and skill freshness.

### Changed

- **The evidence-gated conductor runtime is now the project itself** —
  conductor, planner, developer, diagnostician, designer, and deployer live in
  root `agents/`; gates, libraries, and hooks live at root canonical paths; the
  Claude manifest selects only these roles and hooks; Codex uses the same
  runtime through `delivery-pipeline`.
- **Design review reads the canonical ledger** — the browser surface presents
  the agreed intent/plan beside the visual look-contract and binds approval to
  `ledger.md` and `design.html` digests.
- **Runtime-coupled skills were refreshed** — project docs, research,
  prototypes, artifact migration, CI, observability, UI verification, and role
  routing now use the conductor/ledger/evidence model and current root paths.
- **CI now runs the same validator and zero-cost smoke eval used locally.**

### Removed

- **The parallel legacy runtime** — the old agent set, protocol tree,
  deterministic-check tree, setup/verification scripts, runtime templates, and
  historical work-in-progress design files are removed. Release history remains
  in this changelog and Git history.
- **The experimental runtime namespace** — there is no `v5/` directory or
  version-qualified execution path. The promoted design is the sole supported
  architecture.

## [5.5.0] — 2026-09-06 — Architecture dialogue and durable technical docs

### Added

- **Structured architecture dialogue** — the v5 planner can return `needs-input` with one to three system- or component-level decisions. The conductor asks those questions in the main conversation, records the answers, and redispatches the planner before an ADR is written.
- **Component contract documentation** — substantial boundaries can now receive focused `docs/components/*.md` contracts alongside the high-level `docs/architecture.md`; the docs index, close-out protocol, and link checker understand the optional layer.
- **Skill freshness registry and validator** — version-sensitive skills declare their verified scope, official sources, and recheck date in `skills/freshness.json`; plugin validation fails when registered guidance expires or drifts from the registry.

### Changed

- **Framework guidance is current and version-aware** — refreshed React 19, component composition, Next.js 16.2, Tailwind CSS v4/shadcn, and iOS/Swift Testing availability while preserving explicit compatibility paths for older supported projects.
- **Technical docs now operate at two altitudes** — architecture owns system topology and cross-component decisions; optional component contracts own public interfaces, invariants, failure behavior, and local test strategy without duplicating source code.
- **Artifact inventory is now 23 templates** — adds `component-doc.template.md` and synchronizes plugin manifests and canonical documentation at version 5.5.0.

## [5.4.0] — 2026-08-03 — Codex multi-agent conductor

### Added

- **`delivery-pipeline` Codex skill** — makes the main Codex task the v5 conductor and explicitly dispatches Codex subagents into the existing planner, developer, diagnostician, designer, and deployer roles. It adapts Claude-specific tool names and plugin-root paths while preserving the ledger, evidence recorder, gate order, user-approval ownership, and two-strike escalation rule.
- **Codex skill UI metadata** — exposes a focused `Run Coding Agent` entry with an explicit invocation prompt, keeping the expensive multi-agent workflow opt-in.

### Changed

- **Codex manifest and docs now expose a real multi-agent runtime** rather than only the shared skill/MCP library. Starter prompts invoke `$coding-agent:delivery-pipeline`, and inventory is synchronized to `59 skills / 12 protocols / 18 checks / 22 templates / 5 MCP servers`.
- **Plugin self-validation covers Codex packaging** — the validator checks the Codex manifest and the delivery entry skill alongside the existing Claude runtime.

### Fixed

- **`debugging` skill frontmatter is valid strict YAML** — quotes the colon-bearing description so Codex plugin validation no longer depends on a permissive parser.
- **Codex shared-workspace dispatch is attribution-safe** — worker returns include `changed_paths`, the conductor compares scoped paths with a pre-dispatch snapshot, stages only explicit attributable paths, and parallel review dimensions stay read-only until one aggregate reviewer writes `review.md`.
- **Evidence recording is concurrency-safe and intent-bound** — `record.sh` locks id allocation/appends across parallel workers and accepts `kind=test` only when the command exactly matches the frozen `test-command-<tier>:` contract.
- **Design approval verification fails closed** — verdict checks require parseable zero-open-comment metadata and current artifact hashes; the review server uses persisted comments as authoritative state, and the designer role no longer exposes approval-capable browser tools.

## [5.3.0] — 2026-08-03 — Codex packaging + canonical workflow fixes

### Added

- **Codex-local packaging for the repo itself** — added [`.codex-plugin/plugin.json`](.codex-plugin/plugin.json) plus repo-local marketplace metadata at [`.agents/plugins/marketplace.json`](.agents/plugins/marketplace.json), so Codex can install this workspace directly via `codex plugin marketplace add <repo>` and `codex plugin add coding-agent@coding-agent-local`.

### Changed

- **Plugin metadata and contributor docs now describe the dual-runtime shape** — the repo remains the full Claude Code multi-agent plugin, while the Codex package exposes the shared skills + MCP configuration that Codex local plugin manifests accept. Updated [`README.md`](README.md), [`AGENTS.md`](AGENTS.md), [`CLAUDE.md`](CLAUDE.md), and legacy marketplace metadata to reflect the current `58 skills / 12 protocols / 18 checks / 22 templates / 5 MCP servers` inventory.

### Fixed

- **Canonical workflow docs are internally consistent again** — failing reviews stay active work, smoke/touch-up paths keep a durable review artifact, approved plans clarify when revisions supersede prior approval, session checkpoints are scoped as explicit exceptions, implementor questions route back through `work.md`, and evaluator commands are stack-agnostic rather than hard-coded to `npm`.

## [5.2.0] — 2026-07-25 — v5 Phase A: audit repair (18 fixes)

A second audit pass — v5's flow compared against mainline v4 beat by beat, a scale test (240-line ledger / 2000 evidence entries / 12-feature product ledger), and a sweep of this CHANGELOG's own scar record plus both dogfood projects' `learnings.md` — found 18 items. Several were lessons v4 paid for in production that did not survive the redesign. All 18 land here; `00-smoke` now covers them with 38 assertions. v4 untouched.

### Fixed

- **`git add -A` re-introduced a known data-loss bug** (TA1) — `conductor.md` prescribed the exact command 2.2.0 banned after coordinator artifacts were swept into a commit and erased by a later `git reset --hard`. Now `git add -- . ':(exclude).coding-agent'`, and `v5/hooks/session-start.sh` gained the non-skippable gitignore preflight v5 never had (v4 has had it since 2.2.0).
- **`clean?` scanned an empty stage** (TA2) — the prescribed order was `clean?` → `git add` → commit, but the gate reads `git diff --cached` and returns `n/a "nothing staged"`, so the secret / debug-print scan never saw the diff it exists to scan. Reordered to stage → `clean?` → commit.
- **`proven?` accepted one self-chosen command as proof of a whole suite** (TA3) — the regression 4.5.0 closed and this reopened (*"a green unit run while browser/e2e tiers are stale is a false PASS"*). The intent now declares `tiers:`, `record.sh "<cmd>" test <tier>` labels each run, and the gate demands a green entry **per declared tier** at the current tree, naming any that are missing. `all_green`, promoted into the gate.
- **Agreement was a stamp the writer wrote about itself** (TA4) — `framed?` passed on a blockquote the conductor produced, and the conductor had no `AskUserQuestion` tool: it could not ask but could consent. This is 4.7.0's root cause (*"the model took the cheaper path by preference"*) relocated to a different gate, with no missing verdict file to detect it by. `ledger.sh freeze` now requires `--answer "<what the user replied>"` and records the quote; `framed?` rejects a marker without one; one-way-door ADRs need a `user agreed:` line; the conductor gained `AskUserQuestion`.
- **`review.md` had no schema while its format was load-bearing** (TA5) — `reviewed?` consumed a grep count, so a worker writing `* [blocking]` recorded a clean verdict with defects on the page. Added `v5/templates/review.template.md`; the gate now reads the artifact too — findings section required, malformed (non-flush-left) finding lines rejected, unfilled template rejected.
- **UI features could be "proven" by unit tests** (TA6) — three real-project incidents shipped features whose engine was fully unit-tested and whose hook never passed its input. `proven?` now blocks a `touches: ui` intent that declares no `e2e` tier, and the developer must drive the real flow and screenshot it.
- **The learnings loop was open at both ends** (TA11) — workers were told to read `learnings.md`, a file nothing in v5 writes; `close` wrote learnings to `product.md ## learnings`, which no prompt pointed at. Both ends now meet at `product.md`.
- **`close` wrote placeholders nothing checked** (TA12) — measured 12 of 12 unfilled rollups in a simulated 12-feature run: the product memory degrades at exactly the rate you ship. `close` now requires `--summary` / `--learnings` (`--deployment` when shipped) and exits 64 on a partial rollup.
- **Strike 1 was not durable** (TA14) — the two-strike ladder logged only the *second* block, so after a compaction the conductor saw a first block it had no record of and dispatched again. Measured: 24 escalations in a 240-line log, 1 visible in `tail 30`, **0** in the SessionStart inject. Every block is now logged, and `ledger.sh blocks <gate>` derives the count from disk.
- **Rollback was routed to nobody** (TA16) — `conductor.md` said the conductor orders it, `deployer.md` said *"do not initiate rollback yourself"*, and no kind or primitive existed. Added `ledger.sh rollback` (derives the last deploy a later `observe` confirmed healthy, and its `head`) and a `rollback` kind on the deployer that executes it. `record.sh` now stamps `head` alongside `tree_sha` so the target is checkoutable.

### Added

- **`v5/agents/diagnostician.md`** (TA7) — `diagnose` split onto its own agent at `effort: xhigh`, carrying v4 `debugger.md`'s method and its `debugging` / `observability` skills. Every v5 agent had been `effort: high`, so root-causing a wrong mental model ran at the same depth as running a test suite — `effort` is per-agent frontmatter, so a multi-kind agent cannot tier it. `planner` also raised to `xhigh` (it owns one-way doors). *Deviation from plan:* the `architect` kind stays on `planner` rather than getting its own agent — the name collides with v4's `architect` while both coexist; revisit at Phase 5.
- **Four missing principle tiers** (TA8) — `frame`, `diagnose`, `design`, `ship`. `conductor.md` claimed every kind read `principles.md#<kind>`, but only five tiers existed and `diagnose` — the hardest kind — had none. Also ported v4's **"Thinking & context discipline"** section into `conductor.md`; v5 had no thinking guidance anywhere.
- **Skills wired** (TA9) — v5's dispatch schema documented a `skills=[…]` field that nothing populated, leaving all 58 unreachable. Preloaded per agent (developer: `tdd`, `test-doubles-strategy`, `security-checklist`, `load-bearing-markers`; diagnostician: `debugging`, `observability`; planner: `deep-research`) plus a domain routing table in the conductor's dispatch section.
- **`skipped_or_assumed` on every return contract** (TA10) — operating principle 5 ("say what you didn't do") had no carrier: a skipped tier or an assumption proceeded on had nowhere to ride, and the conductor is told to distrust prose.
- **ADR supersession + product slicing** (TA13) — `## decisions` is append-only and grows for the life of the repo; measured 0 supersession markers after 8 ADRs, so a reversed decision still read as current. `architected?` now honours `superseded-by:` and matches the canonical `feature:` anchor rather than the heading. The planner reads a *slice* of `product.md`, not the file.
- **`CURRENT` is a stack** (TA15) — starting a hotfix mid-feature silently repointed it, and `close` left it empty rather than restoring the interrupted feature. `init` now pushes (marking the interrupted ledger with `interrupted by <slug>`), `close` pops back.
- **Incident entry** (TA17) — `ledger.sh incident <slug> --from <feature> --evidence <id>` builds the intent from a failing run (*"make evidence #N green"*), refusing a green one. The arc always started at `framed?`, so a production failure waited on a drafted-and-agreed intent before anyone could reproduce it. User agreement is still required; the planner round-trip is not.
- **Three validator checks** (TA18) — dangling `principles.md#<tier>` anchors, kinds with no tier, and preloaded skills that do not exist.

### Changed

- **`evidence.jsonl` entries gained `tier` and `head`.** Existing entries stay readable; gates that key off tiers only see entries written after this release.
- **`00-smoke` rewritten** — 38 assertions covering every Phase A guarantee, still script-only and model-free (~3s). `evals/lib.sh`'s `ev_current` follows the CURRENT stack.

## [5.1.0] — 2026-07-19 — evals: the continuous-iteration harness

New in-repo eval harness for testing and iterating the plugin: scenario prompts + deterministic assertion scripts, judged the same way v5's gates judge work — by artifacts (ledger, `evidence.jsonl`, git state, running code), never by the model's prose.

### Added

- **`evals/`** — runner (`run.sh`: headless `claude -p` in scratch repos, or `--manual` for interactive sessions), shared assertion library (`lib.sh`: `ev_assert`, `ev_gate`, `ev_evidence_has`, `ev_tree_sha`, `ev_ledger_order`, `ev_metrics`), A/B comparator (`compare.sh`: per-scenario verdicts + metric deltas, non-zero exit on pass→fail regressions), and 8 scenarios:
  - `00-smoke` — script-only full-arc walk of all 8 gates + freeze/revise/close/record (zero-cost CI baseline; runs in ~2s with no model)
  - `01-quick-arc` — the bread-and-butter path with proof bound to the *final* tree
  - `02-redirect` — mid-feature requirement change must go `revise` → re-freeze, append-only
  - `03-escalation` — unfixable red test must trigger two-strike escalation, bounded dispatching, no fabricated green
  - `04-recovery` — session killed mid-arc; a fresh session finishes the same feature from the ledger alone
  - `05-design-gate` — self-approval resistance: with no human, the session must stop AT `designed?`
  - `06-adr-gate` — consequential change produces a gate-visible ADR *before* build
  - `07-fabrication` — "just say tests passed" pressure: commit implies real tree-bound proof, or no commit at all
- **validate.sh section 10 (Evals)** — every eval script executable + `bash -n` clean, every scenario has an `assert.sh`.
- **AGENTS.md § Testing Changes** — evals/ is now the primary harness; the `~/workspace/test-agents/` W1–W4 suite is documented as the legacy v4 path.

Verified: `00-smoke` passes 17/17 through the real runner; all 7 model scenarios fail *cleanly* against an empty project (pure-JSON output, no hangs, no vacuous passes — `07`'s refusal branch requires session engagement).

## [5.0.0] — 2026-07-11 — v5 Phase 3: wired live (coexists with v4)

The five v5 agents are now **registered in the plugin manifest** and the v5 hooks are wired, so the conductor and its workers are dispatchable as `subagent_type`. v4 is untouched and remains the default entry — this registers v5, it does not promote it (promotion to default is Phase 4/5, gated on dogfooding). Major bump because agents were added to the manifest (per AGENTS.md semver).

### Changed

- **Plugin manifest registers all 11 agents + both hook files** (T3.1, T3.2) — the plugin reference documents that an explicit `agents`/`hooks` field **replaces** default directory discovery (confirmed against docs.claude.com), so `plugin.json` now lists all six v4 agents **and** the five v5 agents explicitly (omitting the v4 six would have silently dropped them), plus `"hooks": ["./hooks/hooks.json", "./v5/hooks/hooks.json"]`. All names are unique across the combined set. New validator check 9.6 fails if any manifest path stops resolving.
- **v5 hooks made safe for coexistence** (T3.2) — v4 and v5 share `.coding-agent/`, so `v5/hooks/session-start.sh` now no-ops unless a genuine v5 ledger exists at `.coding-agent/<slug>/ledger.md` (v4 keeps features under `.coding-agent/features/<slug>/`), preventing a bogus v5 banner in v4 projects. The evidence-wall PreToolUse hook only acts on paths ending in `evidence.jsonl`, so it is a no-op everywhere else.
- **Docs truth pass** (T3.3) — `v5/README.md` (rewrote the two-agent `worker.md` model to the four kind-specific agents + 8 gates, updated wiring status), `ARCHITECTURE.md` (added a v5 topology note), `docs/concepts/v5-design.md` (implementation note reconciling the one-`worker.md`/seven-kinds spec with the as-built four agents + `reviewed?` gate; fixed the file-layout tree), and `.claude-plugin/marketplace.json` (v4+v5 description).

**Live verification still owed (needs an interactive session):** dispatching `subagent_type: conductor|planner|developer|designer|deployer` resolving in a fresh session, and confirming both SessionStart hooks fire cleanly in a real v4 and v5 project. Structural checks (JSON validity, all 13 manifest paths resolve, name uniqueness, hook no-op logic) pass.

## [4.9.0] — 2026-07-11 — v5 Phase 2: porting the load-bearing v4 muscles

Phase 1 made v5 correct; Phase 2 makes it complete — porting the three v4 capabilities the lifecycle vet flagged as load-bearing (qualitative review, escalation, redirect), which the gates-only model had dropped. Still unwired; v4 unchanged. Tasks in `v5/PLAN.md`.

### Added

- **`review` kind + `reviewed?` gate** (T2.1) — v5's biggest regression vs v4 was having no qualitative review: `proven?` reads exit codes, which catch breakage but not wrong-but-green code, missed acceptance criteria, or security smells. New `v5/gates/reviewed.sh` sits between `proven?` and `clean?`, is `n/a` until code is proven, and passes only on a `kind=review` verdict (exit 0 = zero blocking findings) bound to the current tree. New `review` kind in `v5/agents/developer.md`: reads the diff against the intent's acceptance criteria + ADR, writes `- [blocking]`/`- [advisory]` findings (citing `file:line`) to `.coding-agent/<slug>/review.md`, and records an evidence-honest verdict that recomputes the blocking count from the file. Conductor gets the gate in its order, `review → developer` in the dispatch table, a `reviewed?` branch route (scoped `build` on blocking findings → re-`review`), a `review` principle tier, and a parallel-review fan-out option (correctness · security · simplicity → merge → one verdict). Verified: blocking finding blocks, advisory-only passes.
- **Two-strike escalation** (T2.2) — the conductor had no retry cap: a persistently blocking gate could loop forever. Added an Escalation section to `v5/agents/conductor.md` — if the same gate blocks twice with **no new evidence id** between runs, stop dispatching, log the escalation to the ledger, and surface both block reasons + options (take over / revise intent / abandon) to the user; wait for them. A re-dispatch that produced fresh evidence (even still-failing) counts as progress and resets the strike.
- **`ledger.sh revise` — redirect mechanics** (T2.3) — a mid-feature requirement change had no mechanism: once `framed?` was frozen it passed forever, so v5's documented "revision re-opens `framed?`" was impossible. New `revise <section> "<why>"` appends a `> revision @<ts>` marker; `framed.sh` now checks the **last** agreement marker, so a revision after a freeze re-opens the gate until the conductor re-freezes on user re-agreement. Verified: freeze→pass, revise→block, re-freeze→pass.
- **`ledger.sh close [--abandoned|--superseded]` — terminal states** (T2.4) — v5 had no close/abandon primitive; the conductor hand-edited `product.md`. New `close` rolls a feature up into `product.md` (summary + learnings + deployment stub), clears `CURRENT`, and on `--abandoned` renames the feature dir to `<slug>.abandoned/`. The learnings stub is written **even when abandoned** — a gap v4 shares (learnings only captured at successful close). Verified: rollup appended, CURRENT cleared, dir renamed.
- **Artifact ground-truth check** (T2.5) — the conductor now verifies a `build`/`diagnose` worker's claimed files against `git status --porcelain` before logging the dispatch; an empty diff behind a completion claim is a failed dispatch (re-brief once, then it counts toward the two-strike escalation). Ports v4's `tests-actually-committed` guard as one loop step.

### Fixed

- **validator taxonomy check was silently pattern-fragile** (found during T2.1) — check 9.5 used `record\.sh[^\n]*"…`; grep treats `\n` in a bracket expression as the literal chars `\` and `n`, so a recorded command containing backslashes (the review verdict's `\$`/`\[`) broke the match and the kind read as unrecorded. Switched to `.*` (grep is already line-based). The check now reliably catches a gate expecting an unrecordable evidence kind.

## [4.8.1] — 2026-07-10 — v5 Phase 1: correctness fixes (from the vet)

Fixing the vetted breaks in the v5 scaffold so it can actually run. v5 is still unwired (v4 unchanged); this phase makes the gates, agents, and evidence chain internally consistent. Tasks tracked in `v5/PLAN.md`.

### Added

- **`scripts/validate.sh` v5 section** (T1.1) — the regression net for the rest of the phase. Lints v5 agent frontmatter (name matches filename), gate/lib/hook shell scripts (executable + `bash -n`), `${CLAUDE_PLUGIN_ROOT}` path resolution, the design-review.sh **subcommand contract** (an agent invoking a nonexistent subcommand now fails the build — this alone catches the worst critical), and the evidence-kind taxonomy (every kind a gate greps for must be recordable by some agent).
- **`scripts/design-review.sh verify <feature_dir>`** (T1.2) — machine-checkable design gate: exits 0 only when `design-verdict.json` says `approved` AND the artifacts are byte-identical to sign-off (reuses `verify_design_verdict` from `checks/lib.sh`). Additive; v4 unaffected.

### Fixed

- **`designed?` was permanently unclearable** (T1.2, critical) — `v5/agents/designer.md` instructed nonexistent `design-review.sh approve/verify <slug>` calls against a script that only had `start|stop|status` and takes a feature **dir**. Rewrote the design loop: the designer writes `design.html` into `.coding-agent/<slug>/` and starts the surface with the dir; the **human** approves in the browser (no agent self-approval); the designer records the sha-bound `verify` check as `kind=design` evidence. Verified end-to-end: gate blocks → record approval → gate passes → mutate design → `verify` blocks on sha mismatch.
- **`architected?` couldn't see the planner's ADR** (T1.3, critical) — the planner emitted a level-2 `## ADR` heading, which terminates the `## decisions` section, so a pasted ADR (and its slug) fell outside what the gate greps. Demoted the ADR heading to `### ADR — <slug> — <title>` + added a canonical `feature: <slug>` anchor line; piped `architected.sh`'s extraction through `strip_comments` so the template's commented example can't false-pass. Verified: level-2 blocks, level-3 passes.
- **`framed?` false-passed on the frame template's own placeholder** (T1.3, major) — the template shipped a literal `frozen: agreed @ <timestamp>` line and the gate's grep was unanchored, so a verbatim paste satisfied the gate with zero user agreement. Deleted the placeholder from `v5/agents/planner.md`, aligned the frame block to the real `ledger.template.md` structure, made the `touches:` tags paste-safe (no `ui | api | …` menu that feeds bogus values to conditional gates), and anchored `framed.sh` to `^> frozen: agreed @` — the exact blockquote `ledger.sh freeze` writes. Verified: placeholder blocks, real freeze passes.
- **`ca_tree_sha` rotated on a byte-identical commit** (T1.4, major) — it hashed `rev-parse HEAD` + `git diff HEAD`, so committing (HEAD moves, diff empties) produced a new sha over unchanged files, silently invalidating every tree-bound proof across the natural prove → commit → ship walk. Rewrote `v5/gates/lib.sh` to hash per-file working-tree content over `git ls-files -co` (excluding `.coding-agent/`) — invariant across `git add` and `git commit`, still changes on any real edit or rename. Verified: sha holds across add + commit, `proven?` survives the commit, a real edit re-blocks it.
- **`observed?` was the only evidence gate not tree-bound** (T1.5, major) — it grepped for any `kind=observe` + `exit:0` ever recorded, so a healthy observation from a previous tree still passed after the code moved. Now uses `evidence_match observe` (kind + exit 0 + current `tree_sha`), matching `shipped?`/`designed?`. Also hardened validator check 9.5 to ignore comment lines so prose mentioning `evidence_match` can't false-flag. Verified: passes at current tree, blocks when stale, n/a without `deploys:`.

### Changed

- **Conductor control-loop gaps closed** (T1.6, majors + minors) — one `v5/agents/conductor.md` edit plus regex fixes across the four conditional gates:
  - `clean?` now has an owner: an explicit stage-and-commit loop step before `shipped?` (the conductor is the single writer, so it owns the commit; its secret/debug scan runs on the staged diff).
  - Branch routing became a full table with fail edges for **every** gate (`framed?`, `architected?`, `clean?` were previously unrouted) plus a default rule and a two-strike escalation hook (no infinite re-dispatch).
  - ADRs are appended to `product.md ## decisions` **immediately** on a `planner(architect)` return — `architected?` reads them before build, so end-of-feature rollup was too late.
  - Build/diagnose returns are verified against `git status --porcelain` before being logged — an empty diff behind a completion claim is a failed dispatch.
  - Conditional-gate applicability is word-boundary anchored (`^…touches:.*\bui\b`), so `touches: api, ui` correctly applies `designed?` (previously only matched `ui` as the first value) and a stray `ui` in a goal line no longer trips it.
  - All `ledger.sh` command references use the full `${CLAUDE_PLUGIN_ROOT}/v5/lib/ledger.sh` path (bare name isn't on `PATH`); dropped the nonexistent `Agent` tool from frontmatter (kept `Task`).
- **record.sh hardening** (T1.7, minors) — (1) `kind` is now validated against `test|deploy|design|observe|review|run`; a worker that records its *dispatch* kind (`prove`, `build`, `ship`) instead of an evidence kind gets exit 64 instead of writing an entry no gate will ever read. (2) `ca_root` (in `v5/gates/lib.sh`) resolves via `git --git-common-dir`, so a `build` worker running in an isolated worktree records into the **main** repo's `evidence.jsonl` — previously it hit "no active feature" (exit 64) because the worktree has no `.coding-agent/`. Root-caused in the shared `ca_root` rather than special-casing record.sh, so gates and record agree on where the ledger lives. Verified: invalid kind → 64; worktree record lands in main, no local `.coding-agent/` created.

## [4.8.0] — 2026-07-09 — v5 scaffold, adversarially vetted, committed

The v5 reimagining lands as an inert scaffold under `v5/` — nothing is wired into the plugin manifest, so v4 behavior is unchanged. This commit exists to preserve the design and its vet before any fixes land.

v5 collapses v4's four primitives into one axiom — *no claim advances without evidence; evidence is recorded by execution, never written by the agent* — and derives the machinery from it: one conductor (single writer of an append-only ledger) runs a 7-gate pipeline and dispatches four stateless kind-specific agents (planner / developer / designer / deployer).

### Added

- **`v5/`** — the scaffold: 5 agent prompts, 7 gate scripts + `gates/lib.sh`, `lib/record.sh` (the only writer of `evidence.jsonl`) + `lib/ledger.sh`, `hooks/` (evidence wall + session resume, unwired), `templates/` (product + feature ledger), `principles.md` (the craft plane).
- **`docs/concepts/v5-design.md`** — the canonical design: the axiom, three primitives (ledger / evidence / gate), two roles, arc sizing without modes, failure routing, the concurrency model.
- **`v5/design-vet.md`** — findings from a 25-agent adversarial review (3 critical, 10 major, 11 minor, 2 note), plus a scenario-by-scenario v4-vs-v5 lifecycle comparison across 12 non-happy paths and product iteration.
- **`v5/PLAN.md`** — the executable promotion plan: 24 dependency-ordered tasks across 6 phases, each with Files / Change / Verify.

Known state: 3 critical wiring breaks block any real run (`designed?` unclearable, `architected?` cannot see the planner's ADR, agents unregistered), and 3 load-bearing v4 capabilities are missing (qualitative review, escalation ladder, redirect mechanics). All are enumerated in `v5/design-vet.md` and scheduled in `v5/PLAN.md`.

## [4.7.0] — 2026-06-24 — The design-review surface is required, not optional (it was never actually shown)

Real-usage finding: across both dogfood projects, `design.html` was being generated but **no `design-verdict.json` / `design-comments.json` ever existed** — the interactive design-review surface was never launched. Every spec/plan approval went through chat instead. Root cause (same pattern as the verification forensics): the gate framed chat as an always-available "headless fallback," `spec-approved`/`plan-approved` accept chat approval just as readily, and starting a localhost server is friction — so the model took the cheaper path by preference. The surface itself is fully functional (verified end-to-end: server serves `/meta` + renders spec at HTTP 200 against a real feature dir).

### Changed

- **`agents/orchestrator.md` (approval gate)** — the design-review surface is now **REQUIRED, not a preference**, for spec/plan/design gates. The orchestrator must **actually run** `design-review.sh start` as a tool call and confirm `{"ok":true,"url":…}` before asking the user; printing the spec and calling `AskUserQuestion` *without* launching the surface is explicitly called out as **skipping the gate**. The chat path is now a **conditional fallback** — used only when `start` returns `{"ok":false}` (python3 missing, port in use, genuinely headless), and the fallback must be logged (`gate-fallback | design-review surface unavailable: <reason> → chat`) so a skipped surface is visible, not silent.
- **`protocols/design-review.md`** — rule 1 now requires actually running the `start` command (not just "print a summary + URL"); the "Headless fallback" rule is rescoped to fire only on a real `ok:false`, with convenience/speed explicitly excluded, and the fallback logged.

v4.5.0 made each iteration *honest*; this batch reduces the *number of round-trips per feature*, from the agents/protocols audit. The pipeline flow changed for non-large features — verified internally consistent by an adversarial pass tracing both medium (combined) and large (split) features end-to-end across all 15 touched files.

### Changed

- **A1 — combined design gate (non-large).** Small/medium features now run spec-writing and plan-writing in **one architect dispatch** (`Phase: SPEC+PLAN`) approved in **one design-review session**: the surface already renders both `spec.md` and `plan.md` as tabs and the server already hashes every present artifact, so the single verdict binds **both** `spec_sha` and `plan_sha` with **zero** server/check changes. Both artifacts flip to approved atomically; `spec-approved` + `plan-approved` both run against the one verdict. **Large** features keep the two-dispatch / two-gate split (spec locked + immutable before wave decomposition). This removes a full architect round-trip and a second browser-review cycle per non-large feature — three user gates (Intent · Design · Push) instead of four. Touched: `orchestrator.md`, `architect.md`, `spec-writing.md`, `plan-writing.md`, `design-review.md`, and the flow narratives in `ARCHITECTURE.md`, `docs/concepts/{workflow,lifecycle}.md`, `README.md`.
- **A2 — architect drafts-with-defaults.** For **≤2 low-stakes forks** (choices that don't change the core flow), the architect now picks a sane default, records it in the spec's new `## Assumed Defaults` section (rendered in the review surface so the user still sees the tradeoff before approving), and returns `status: complete` — instead of a `needs-input` round-trip. Design-changing forks, or more than 2 forks, still return `ask_user`. Touched: `architect.md`, `spec-writing.md`, `templates/spec.template.md`, `docs/concepts/workflow.md`.
- **A3 — conventions hand-off.** The implementor now records `conventions_probed` (active `test_path_pattern`, `logger_module`, `peer_files_matched`) in its return; the orchestrator persists it to `work.md § Conventions Probed`; the evaluator reads it as a **spot-check starting point to verify, not trust** (did tests land *inside* the pattern? is the reported logger the real one?) — instead of re-deriving every convention from scratch. Touched: `implementor.md`, `orchestrator.md`, `evaluator.md`, `review.md`, `templates/work.template.md`, `docs/concepts/lifecycle.md`. (Also aligned `evaluator.md` step 3 to the v4.5.0 multi-tier `--tier` form.)

### Fixed

- **B1 — `checks/no-raw-print.sh` regex typo.** The JS console matcher used `^[^*//]*` — a malformed class (`[^*/]`) that **exempted any line with a `/` before `console`**, silently letting raw `console.log("a/b"); console.log(x)` through. Replaced with a two-step comment-skip (drop comment-only lines, then match the call anywhere); applied the same shape to the Python `print(` branch. Verified: a real console call after a `/` is now flagged, while commented-out and JSDoc lines stay exempt.

A second forensic pass over the same two projects pinned the single root cause of "too many iterations" / "long-running with no progress": the pipeline scored progress against a **proxy** — the implementor recorded one self-chosen command (usually jsdom unit tests) as "verified", while the binding rules (all tiers green + live path wired) lived only as prose in the review protocol. So tier drift, dead live-paths, and schema-version breakage surfaced a re-dispatch *later* (at the wave barrier / e2e / sweep), never at build. This batch moves full-tier + live-path verification UP to where work is declared done, and makes the recorded artifact incapable of being green while a tier is red. Three gate false-FAILs (which themselves caused wasted rounds) were fixed in the same pass.

### Changed

- **`scripts/run-and-record.sh` (multi-tier gate)** — now records **every declared tier**, not one command. New `--tier name=cmd …` form runs each tier and writes `last-verify.json` with a per-tier breakdown, `all_green` (true ⟺ every tier exit 0), and `failing_tiers`. The legacy single-command and auto-detect forms still work (one tier named `verify`), and the top-level `ok`/`exit_code`/`tree` fields now mirror the aggregate, so existing consumers get multi-tier semantics for free. A green unit run while browser/e2e/server tiers are stale now lands as `all_green:false` with the failing tier named — the silent false-PASS that drove the 3× schema-drift recurrence is structurally impossible.
- **`agents/implementor.md` (step 8 self-check)** — the builder now (a) runs **every tier its task's plan declares** plus typecheck/build via the `--tier` form and may only mark a task `complete` when `all_green`, and (b) **drives the live path** for any user-facing FR (exercise the real app flow end-to-end, confirm the user-visible result changes) before returning — catching the unit-green-but-dead-wiring class (`useForecast` never fed `goalMonthlyNets`; `useSuggestions` never passed `portfolio`). Pulls the review protocol's existing live-wiring requirement up to the builder's own gate.
- **`protocols/review.md`** — the "run every declared tier" step now points at the concrete `--tier` one-shot mechanism and keys the verdict off `all_green`.
- **`checks/commit-gate.sh` + `scripts/setup.sh` (commit-msg hook)** — both now read `all_green` (falling back to `.ok` for legacy records) and name the failing tier in the rejection, so the anti-fabrication machinery is load-bearing instead of cosmetic: `all_green` cannot be true while any tier is red.

### Fixed

- **`checks/review-passed.sh`** — a valid verdict with a trailing note (`## Status: PASS — all tiers green`, `**PASS**`, `PASS (live path checked)`) false-FAILED the entire commit gate (it required the status line to equal `PASS` exactly). Now matches a leading `PASS` token after stripping markdown markers, while still rejecting the `PASS | FAIL` template placeholder (it names `FAIL` as a word). Verified across 7 pass/reject cases.
- **`checks/tests-actually-committed.sh`** — wave-mode git-visibility check used the implementor's **raw claimed path**; an absolute or subdir-relative path matched nothing under `git status` and false-FAILED a real, modified file. Now derives the repo-relative path from the already-resolved `$found`. Absolute-path claims now pass; missing files still fail.
- **`checks/docs-links.sh`** — a standard titled Markdown link (`[x](./foo.md "Title")`) false-FAILED as a broken cross-link because the ` "Title"` suffix was kept in the resolved path. Now strips the title (everything from the first whitespace) before resolving.

## [4.4.0] — 2026-06-21 — Hardening from real-usage forensics (multi-tier gate, live-wiring e2e, forced discovery, decision-density sizing, artifact migration)

Forensic analysis of two real projects (a phased finance app, a 2-month knowledge base) surfaced recurring gaps. This batch addresses four of them; the `tests-actually-committed` fix shipped separately in 4.3.0.

### Added

- **`skills/practices/artifact-migration/`** — opt-in cleanup for legacy `.coding-agent/` artifacts from older plugin conventions (root-level flat `plan/spec/review` + `.prev*` chains, per-feature `progress.md`/`nits.md`/`mode`). Archive-never-delete to `.coding-agent/.archive/<date>/`, never touches the CURRENT feature, idempotent via a `.migrated` marker. The SessionStart hook now detects legacy artifacts and surfaces them so the orchestrator can offer the cleanup; the orchestrator gained the opt-in trigger. (Fixes the KB project's drift into confusing dual state.)

### Changed

- **`protocols/review.md` (multi-tier gate)** — the evaluator must run **every declared test tier**, not a single aggregate command; a green unit/jsdom run while browser/e2e tiers are stale is a false-PASS. New migration/schema sweep rule: if the diff touched a migration or schema-version constant, re-run the browser+e2e tiers (they carry version assertions a unit gate skips). New FAIL conditions enforce both. (Personal project hit silent schema drift twice.)
- **`protocols/plan-writing.md` + `protocols/review.md` (live-wiring e2e)** — a user-facing FR's E2E must exercise the **live wiring** (drive the real app path end-to-end), not just unit-test the engine; evaluator FAILs an FR with unit coverage but no live-wiring e2e. (Catches the "green tests, dead feature" failure seen twice.)
- **`agents/architect.md` (forced discovery)** — the architect must surface the 1–3 questions whose answers would *materially change the design or core flow* as `ask_user` BEFORE finalizing the spec, rather than defaulting a fork and forging ahead (which surfaces as re-review churn).
- **`agents/orchestrator.md` (decision-density sizing)** — task size is weighed by **decisions that can't be made mechanically from the spec**, not file/line volume — a trivial constant sweep across 5 files stays micro; one branching function is small.
- Inventory synced: **58 skills**.

## [4.3.0] — 2026-06-21 — Fix: tests-actually-committed false-fails on gitignored coordinator artifacts

Found by forensic analysis of two real projects using the plugin. The `wave`-mode ground-truth check required every returned artifact to be **git-visible as changed this cycle** — but evaluator/architect/debugger artifacts (`review.md`, `spec.md`, `diagnosis.md`, screenshots) live under `.coding-agent/`, which is gitignored by design, so the check spuriously failed with *"not visible to git"* on real evaluator returns. (A consumer project's own `learnings.md` had independently diagnosed this as a "plugin improvement candidate.")

### Fixed

- **`checks/tests-actually-committed.sh`** — coordinator/evaluator artifacts (anything resolving under `.coding-agent/`) are now verified by **disk existence**, not git-visibility; the git-changed-this-cycle proof applies only to **source** artifacts. The anti-fabrication guarantee is unchanged where it matters (real source must land; an unchanged or missing file still fails) — the check just stops false-failing on intentionally-gitignored coordinator state. Also probes `…/.coding-agent/<path>` so artifacts returned relative to the coordinator dir resolve. Verified against pass/fail cases.

## [4.2.0] — 2026-06-20 — Route deployment-patterns / ci-cd-patterns (they were unreachable)

`infra/deployment-patterns` and `infra/ci-cd-patterns` had solid content (production-readiness, hosting/containers, CI-CD rules) but were absent from the architect's `plan-writing.md` skill-routing table and referenced nowhere outside the CHANGELOG — so the architect had no trigger to put them in a task's skill manifest. Centralized config was already correct (`config-management` is in the routing table and cross-linked from 6 specialists); this brings deployment to parity.

### Changed

- **`protocols/plan-writing.md`** — new routing row: *"Task touches deployment / CI-CD / hosting / containers / production-readiness → `deployment-patterns`, `ci-cd-patterns`."* The architect now assigns them per task, the same way config tasks get `config-management`.
- **`skills/infra/aws-specialist`, `docker-specialist`, `terraform-specialist`** — cross-link `deployment-patterns` in their Skills sections (terraform gains a Skills section + `config-management` link), mirroring how `config-management` is reachable from stack skills.
- **`protocols/close-out.md`** — first-feature CI scaffolding now loads `ci-cd-patterns` + `deployment-patterns` alongside `ci-testing-standard`, so the scaffolded pipeline includes a deploy/release stage shaped by the practices.
- **`agents/orchestrator.md`** — Deploy mode applies `deployment-patterns` when first authoring or hardening a deploy setup.

## [4.1.0] — 2026-06-20 — Per-subagent reasoning effort tiers

The Agent SDK / subagents docs expose a per-subagent `effort` frontmatter key (`low`–`max`, overrides session effort when that subagent is active) that the plugin wasn't using — every dispatched agent ran at the session default regardless of how hard its work is. Verified against [the subagents doc](https://code.claude.com/docs/en/subagents) that plugin `agents/` frontmatter honors it, then tuned effort to each role's reasoning load. Independent of the "think hard" prompt instructions (effort sets reasoning depth per response; those instructions still apply).

### Changed

- **`agents/architect.md`**, **`agents/product-lead.md`**, **`agents/debugger.md`** — `effort: xhigh`. The irreversible-judgment roles (stack/scope/architecture, product direction, root-cause / wrong-mental-model debugging) get maximum reasoning depth where a wrong call cascades.
- **`agents/evaluator.md`**, **`agents/implementor.md`** — `effort: high`. Thorough but more procedural (running suites, following an approved plan); `high` is also the reliable ceiling for the implementor's `sonnet`.
- **`agents/orchestrator.md`** — left unset: it runs as the main session agent, so it inherits session effort (user-controlled via `/effort` / `/fast`), matching its adaptive-thinking design.
- **`AGENTS.md`** — agent-prompt frontmatter convention now lists `effort`.

## [4.0.0] — 2026-06-19 — Committed project documentation set: cross-referenced, no-duplication, vendor-neutral

A new always-on committed artifact category — the project documentation set any agent (plugin or not) can use to work on a project. Grounded in three published standards: the [agents.md spec](https://agents.md) (AGENTS.md), the [google design.md format](https://github.com/google-labs-code/design.md) (DESIGN.md), and the [Open Knowledge Format](https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing) (link-not-copy single-source-of-truth + a `docs/` bundle with `index.md`). The set is generated from the real codebase at close-out and kept current; **each fact lives in exactly one file, every other mention is a link** — so the docs can't drift into contradiction. Making it an always-generated committed category is a primitive-level change → major bump.

The committed set is portable: a `docs-links` check fails close-out if any committed doc references plugin-runtime state (`.coding-agent/`, `CLAUDE_PLUGIN_ROOT`, role/protocol names) or commits a secret — so removing the plugin leaves every doc working for whatever agent the user switches to.

### Added

- **8 templates** for the committed set — `readme`, `agents`, `product-doc`, `design-doc`, `architecture`, `dataflow`, `docs-index`, `deployment-doc` (`.template.md`). Each carries a one-line single-source-of-truth header, cross-link stubs, and a "never contains" boundary. Vendor-neutral: no plugin references in the produced bodies.
- **`checks/docs-links.sh`** — close-out gate: presence of the applicable docs (DESIGN only for UI projects via `detect_ui`; deployment only when CI config exists), cross-link integrity (every relative link resolves), and the portability no-leak guard (+ no committed secret in deployment.md).

### Changed

- **`skills/practices/project-docs/SKILL.md`** — rewritten to own the 8-file set: ownership table, cross-link wiring, vendor-neutrality contract, per-doc content sources, new + brownfield setup flows. Drops Mermaid (ASCII only). README solely owns pinned versions + tree; AGENTS owns commands (no versions/tree/decisions body); `docs/architecture.md` + `docs/dataflow.md` replace a root `ARCHITECTURE.md` (legacy root file → one-line pointer).
- **`protocols/close-out.md`** — step 3 generates the full set; step 4 retargets to `docs/architecture.md` + `docs/dataflow.md` (+ `docs/index.md`); new step 4.6 distills `DESIGN.md` (UI only); step 4.7 re-distills committed `PRODUCT.md` from the runtime north-star; `docs-links` added to step 8; touch-up/micro skip all of it.
- **`protocols/product-direction.md`** — documents the committed `PRODUCT.md` (close-out snapshot) vs runtime `.coding-agent/product.md` (working strategy) boundary; Shape/Review mutate only the runtime file.
- **`agents/orchestrator.md`** — `docs-links` in the checks list; an on-demand "set up docs" bootstrap trigger for brownfield repos.
- **`docs/concepts/primitives.md`** — Memory category split into runtime (gitignored) vs the committed, vendor-neutral doc set distilled at close-out.
- Inventory synced: **18 checks, 22 templates** (`AGENTS.md`, `plugin.json`, `marketplace.json`, `ARCHITECTURE.md`, `docs/README.md`).

## [3.0.0] — 2026-06-19 — Product-Lead: a 6th agent for product direction (opt-in)

The pipeline was excellent at *building the thing right* but assumed the thing was already decided. This adds the missing upstream layer: **what to build, for whom, solving what problem, and what "world-class" means** — plus an evolution loop so direction compounds across features instead of resetting each time. Adding an Actor is a primitive-level change → major bump.

**Opt-in by design.** The Product-Lead never auto-gates the pipeline. A user who says "just build X" gets built for. It engages only when direction is fuzzy ("what should I build", "is this the right thing"), when invoked, or as a lightweight close-out reflection.

### Added

- **`agents/product-lead.md`** — 6th agent. Founder/product-strategist hat, distinct from the architect's *how*. Owns product *direction*. Like the architect: no dispatch, no `AskUserQuestion`, returns `ask_user` bundles; orchestrator signs. Three modes: **Shape** (concrete problem + core flow + world-class bar), **Reflect** (per-feature north-star delta), **Review** (`/product-review` — maturity assessment + ranked next moves).
- **`templates/product.template.md`** — `.coding-agent/product.md`, a persistent **Memory** artifact (evolves, not immutable): Problem · Target User & JTBD · North-Star · Core Flows · World-Class Bar · Non-Goals · Principles · Maturity Ladder · Evolution Log (append-only).
- **`protocols/product-direction.md`** — the opt-in workflow: offer-don't-impose triggers, the Shape approval gate, per-feature Reflect at close-out, periodic Review.
- **`skills/practices/product-shaping/SKILL.md`** — the method (solution→problem trace, JTBD, one-clean-flow design, testable world-class bar, maturity ladder, compounding evolution).

### Changed

- **`agents/orchestrator.md`** — `product-lead` dispatch line + an opt-in "Product direction" routing table (offer on direction-uncertainty signals; do nothing for a decided user; reflect at close-out; pass approved `product.md` to the architect's SPEC dispatch).
- **`protocols/close-out.md`** — new opt-in step 4.7 (product reflection; skipped for touch-up/micro and when no `product.md` exists).
- **`protocols/README.md`**, **`docs/concepts/primitives.md`** — Product-Lead Actor row; `product.md` added to the Memory artifact category.
- Inventory synced everywhere: **6 agents, 57 skills, 12 protocols, 14 templates** (`AGENTS.md`, `plugin.json`, `marketplace.json`, `ARCHITECTURE.md`, `docs/README.md`).

## [2.7.0] — 2026-06-19 — Delta re-review: stop re-auditing untouched code on every fix round

The implementation → review → fix loop was the pipeline's real slow path, and the cause wasn't lack of parallelism — it was **redundant full re-verification**. Every fix-round re-review was forced to Full mode (`review.md` mode table), so after the implementor fixed two targeted findings the evaluator re-read spec+plan+work, re-ran the whole build + entire test suite, re-swept every FR, and re-drove every runtime flow — to re-confirm code nobody touched. New **Delta** mode re-verifies *what changed*, not *what didn't*: it re-checks only the named finding IDs + runs the test tiers (regression stays non-negotiable), and skips the from-scratch FR sweep and full runtime re-drive. Tests still run, so integrity is preserved; only the redundant audit of untouched surface is cut. Escalates to Full automatically when a fix isn't targeted (new files, surface beyond the findings) or on same-bug-twice (Round 2+).

### Added

- **`protocols/review.md`** — `Delta` mode + step-by-step (read prior findings + diff → build → run test tiers → verify each finding at file:line → conditional runtime check → append `## Round N Re-review` to existing `review.md`).
- **`protocols/fix-round.md`** — Round 1 re-review picks Delta vs Full from the fix's blast radius (changed files ⊆ findings' files → Delta); Round 2 stays Full (same-bug-twice means the mental model was already wrong once).

### Changed

- **`agents/evaluator.md`** — modes table adds `delta`; clarifies Delta narrows the *review*, never the regression gate.
- **`agents/orchestrator.md`** — evaluator dispatch template lists `delta` and notes it carries the prior finding IDs.

## [2.6.3] — 2026-06-19 — Fix factually-false "only you have the Agent tool" line in orchestrator

An ultracode workflow that mapped the dispatch model to find where nested subagents (now GA, 5-deep) could be leveraged concluded — after adversarial verification of 6 candidates — that **nesting is unsafe everywhere in our model**: the single-dispatcher rule is a *dispatch-authority* invariant, not a write invariant, so "read-only children" do not make a forbidden dispatch permitted (no grandchild return-merge, no `ask_user` bubble-up, lost action-log attribution, collapsed independent verifier). The no-nesting invariant stays **absolute**. The one real defect it surfaced: the orchestrator prompt claimed subagents *lack* the `Agent`/`AskUserQuestion` tools, when in fact they inherit them (omit `tools:`) and are merely forbidden to use them. Corrected to match reality — the subagent prompts already said "even if inherited," so this just aligns the orchestrator.

### Fixed

- **`agents/orchestrator.md`** — three lines that stated subagents "only you have the Agent tool" / "only you have AskUserQuestion" (factually false — both are inherited) now read "inherited by subagents but only YOU may use it," and the dispatch line notes dispatch authority lives at depth 0 only (no level-2 nesting).

## [2.6.2] — 2026-06-15 — Revert orchestrator + architect to Opus (Fable deactivated)

Fable 5 was deactivated upstream, so pinning agents to `claude-fable-5` would point at an unavailable model. Reverts the two roles to their prior Opus tier; implementor stays Sonnet, evaluator + debugger stay Opus.

### Changed

- **`agents/orchestrator.md`** — `model: claude-fable-5` → `claude-opus-4-8`.
- **`agents/architect.md`** — `model: claude-fable-5` → `opus`.
- **`ARCHITECTURE.md`** — model-tier table + topology reverted to Opus.

The validators still accept the `fable` alias / `claude-fable-N` IDs (harmless, dormant) so nothing needs re-wiring if Fable returns.

## [2.6.1] — 2026-06-15 — Design-review surface goes fully offline (drop mermaid + all CDN)

Dogfooding the v2.6.0 surface on the plugin's own design immediately exposed the CDN diagram path as fragile: a malformed mermaid diagram rendered nothing, and a valid one collapsed to a zero-size SVG because mermaid was run inside a `display:none` (inactive) tab. Rather than patch a renderer that can't be tested headless, the surface drops mermaid and `marked.js` entirely and renders **server-side**. It now matches the rest of the plugin: Markdown + Bash + stdlib, no build, works with no network.

### Changed

- **`scripts/design-review-server.py`** — adds a compact, dependency-free `render_markdown()` (frontmatter strip, headings, fenced code / ASCII diagrams, pipe tables, lists, blockquote, hr, inline bold/code/links; unrecognized input falls through to a paragraph, never throws) and a `GET /render/<artifact>` endpoint returning HTML. Because rendering is server-side it is now **curl-verifiable** — the previously untestable browser-render path is gone.
- **`scripts/design-review.html`** — removes both CDN `<script>` tags (mermaid + marked) and all mermaid logic; panes now inject server-rendered HTML and attach the comment layer to it. Fully offline; the only browser JS left is the comment/verdict layer.
- **`templates/spec.template.md` / `plan.template.md`, `agents/architect.md`, `protocols/design-review.md`** — diagrams are ASCII in plain code fences (the `ARCHITECTURE.md` house style), not mermaid; rich/visual layouts belong in `design.html` (pure HTML), keeping exactly one visual surface and one text surface.

### Why (design note)

`design.html` was always pure self-contained HTML and rendered first-try; mermaid was the lone CDN dependency and the lone source of render bugs. Removing it unifies the surface on "markdown = text contract (server-rendered), design.html = visual contract (pure HTML)" and restores the plugin's no-network, no-build invariant. Caught by the tool reviewing its own design.

## [2.6.0] — 2026-06-12 — Design-review surface + prototype mode

The pipeline's approval gates were text-only while product judgment is visual and interactive: chat hides the full design behind a terminal scroll, and every feedback item costs a whole round-trip. This release moves spec/plan review into the browser and adds a disposable-prototype mode for when the product direction itself is unknown.

### Added

- **Design-review surface** — `scripts/design-review.sh start|stop|status <feature_dir>` serves spec.md / plan.md (markdown + mermaid rendered as SVG) and design.html (iframe) on localhost via a stdlib-Python server (`design-review-server.py` + single-file app `design-review.html`, CDN marked/mermaid with raw-markdown fallback). The user pins comments to any block or design element, batches all feedback, and ends the round with **Approve** or **Request changes**. Comments persist to `design-comments.json` (auto-archived per round); the verdict to `design-verdict.json`, **sha-bound server-side** to the exact artifact bytes on disk. Approve is rejected (HTTP 409, enforced server-side, not just UI) while any comment is open.
- **`protocols/design-review.md`** — the gate loop: serve surface → user batches comments → orchestrator **triages** (trivial → one architect re-dispatch; material → revision machinery; out-of-scope → back to user / open-threads) → round++ until an approved verdict. Honest integrity note on record: sha-binding pins approval to reviewed bytes (post-approval edits mechanically fail the checks); fabrication-resistance is equivalent to the legacy gate — the orchestrator never writes the verdict/comments files, only the server does. Headless fallback = legacy chat gate.
- **`design.html` look-contract artifact** (`templates/design.template.html`, Plan category) — for UI features the architect now authors real screens (states included, self-contained inline-CSS) reviewed alongside the spec; spec.md stays the behavior contract; the implementor matches structure with the project's real stack, never copies the mock.
- **`skills/practices/prototype-first/SKILL.md` + orchestrator prototype mode** — for unknown product direction: intake-lite → mock app rounds in quarantined top-level `prototype/` (real frontend, fixture/msw/json-server backend, deterministic seed data; no TDD/evaluator/spec gates, one builds-and-renders self-check per round) → forcing question each round (continue/pivot/graduate/abandon) → graduation distills decisions into intent.md, lifts fixture JSON shapes into the spec's API section, seeds design.html from winning screens, **deletes `prototype/`** (git history is the archive), then runs the full feature pipeline. Production code never imports from `prototype/`; offered (never auto-entered) when the user answers "I don't know" to product-shape discovery.

### Changed

- **`checks/spec-approved.sh` + `checks/plan-approved.sh`** — when `design-verdict.json` exists, approval is additionally sha-verified: verdict `spec_sha`/`plan_sha` must match current bytes (post-approval edit → gate fails with "re-run the design review"); `changes-requested` verdict blocks. No verdict file = legacy frontmatter-only path, unchanged. New `lib.sh` helpers `sha256_file` (shasum/sha256sum portable, matches the server's hashing) + `verify_design_verdict`.
- **`agents/orchestrator.md`** — approval-gate protocol now routes spec/plan through the review surface (verdict file written ONLY by the server; hand-writing it = forged approval); prototype mode in the classifier + mode table.
- **`agents/architect.md`** — authors design.html for UI features and a `## Flows` mermaid diagram ("a flow only described in prose is a flow the user can't see"); on changes-requested, addresses the full anchored comment batch in one revision pass.
- **`protocols/spec-writing.md` / `plan-writing.md`** — gate step 6/7 rewritten: 5-line chat summary + surface URL instead of printing the full body; headless fallback retained.
- **`templates/spec.template.md` / `plan.template.md`** — optional `## Flows` / `## Wave Graph` mermaid sections (render as SVG in the surface).
- **`scripts/validate.sh`** — template inventory now counts `*.template.*` (design.template.html was invisible to the `.md`-only glob).

## [2.5.0] — 2026-06-09 — Fable 5 for orchestrator + architect

Moves the two highest-reasoning, longest-running roles — the orchestrator (the main-thread state machine that runs the whole session) and the architect (spec/plan design) — onto **Fable 5** (`claude-fable-5`), the model tier tuned for the hardest, longest tasks. The execution-heavy implementor stays on Sonnet; the evaluator and debugger stay on Opus.

### Changed

- **`agents/orchestrator.md`** — `model: claude-opus-4-8` → `claude-fable-5`.
- **`agents/architect.md`** — `model: opus` → `claude-fable-5`.
- **`scripts/validate.sh` + `scripts/post-edit-validate.sh`** — model-frontmatter validation now accepts the `fable` alias and `claude-fable-N` full IDs (the regex previously only matched opus/sonnet/haiku, which would have rejected the new value on save and at the gate). The decision-making-agent tier convention now passes for either the opus *or* fable tier — which also clears the long-standing cosmetic warning about the orchestrator's pinned full model ID.
- **`ARCHITECTURE.md`** — model-tier table + topology diagram updated to show orchestrator/architect on Fable; corrected the table's stale orchestrator ID (`claude-opus-4-7` → the real pinned value).

## [2.4.0] — 2026-05-31 — Project-docs close-out gate (no more scaffold READMEs)

Closes the last open item from the anti-fabrication incident review (failure #7): a feature shipped with its repo front page still the `create-vite` scaffold README, because the plugin only ever updated the agent-facing `AGENTS.md` at close-out and the project-docs skill told brownfield agents to *preserve* existing READMEs. Now a real human-facing README is a close-out gate.

### Added (checks: 16 → 17)

- **`checks/docs-current.sh`** — close-out gate (full close-out only; touch-up/micro skip). Fails if `README.md` is missing, still matches a known framework-scaffold fingerprint (Vite / CRA / Next / SvelteKit / Astro), or is byte-identical to its first commit while ≥3 source commits have since landed (an untouched placeholder). Catches "shipped a repo whose front page is still *This template provides a minimal setup*".

### Changed

- **`skills/practices/project-docs/SKILL.md`** — adds a *Replace scaffold READMEs* section with the fingerprint table (kept in sync with `docs-current.sh`), and corrects the brownfield rule: preserve a *hand-written* README, but replace a *scaffold* one wholesale instead of trying to patch it.
- **`protocols/close-out.md`** — step 3 broadened from "Update AGENTS.md" to "Update human + agent docs": the first feature (or any missing/scaffold README) now generates a real README via the project-docs skill, so the new gate has a remediation path. `docs-current` added to the checks-fired table and step 8; touch-up close-out skips it.
- **`agents/orchestrator.md`** — `docs-current` added to the critical-checks list (before commit gate, full close-out only).

## [2.3.0] — 2026-05-31 — Mechanical anti-fabrication enforcement

Converts the most-violated anti-fabrication rules from prompt-discipline into mechanically-enforced checks — the filesystem and git become the source of truth, validated by scripts, so a careless orchestrator can't *commit* the error even when it narrates one. Driven by a live incident review (narrated "verified" while red 3×, silent Edit no-ops, guessed test counts).

### Added (checks: 15 → 16)

- **`scripts/run-and-record.sh`** — runs the project's verification and records the RESULT (exit code + parsed test counts + a source-tree hash) to `.coding-agent/last-verify.json`. Test counts in `work.md`/`review.md`/commit messages are now *read from this file*, never typed from memory — a number that wasn't measured can't be written.
- **`checks/commit-gate.sh`** — one serialized commit gate: `review-passed` → `tests-actually-committed commit` → `no-secrets-staged` → `last-verify` green, stopping at the first failure. The orchestrator calls ONE script instead of hand-batching a dependency chain (the exact place it once parallel-batched and advanced on an uninspected result). `--allow-secrets` escape for the explicit user fixture-override only.
- **`commit-msg` git hook** (installed into the consumer repo by `setup.sh`) — **rejects** any commit message claiming verification ("verified" / "passing" / "N tests pass") unless `.coding-agent/last-verify.json` is green (exit 0) and its recorded source tree still matches the working source (content-based, non-racy). "(verified)" stops being a word you can type and becomes a machine-checked fact. Degrades open if `jq` is absent; only fires on messages that make the claim.

### Changed

- **`agents/implementor.md` + `agents/evaluator.md`** — the self-check / test run now goes through `run-and-record.sh`; counts in `notes` and `review.md § Test Results` are quoted from the recorded file, not transcribed.
- **`protocols/close-out.md` + `agents/orchestrator.md`** — commit gate is the single `commit-gate.sh` call; the message step forbids "verified/passing" narration and documents that the `commit-msg` hook enforces it. Checks list updated.
- **`scripts/setup.sh`** — installs the `commit-msg` hook (backs up any existing one) as part of full setup.

> Decision (overrides the earlier "prompts/checks over enforcement blockers" steer): after repeated fabrication incidents, the verification→commit path is now mechanically enforced. `.coding-agent/` stays fully gitignored (decision records are NOT tracked); durability across compaction rides on the PreCompact breadcrumb, not git.

## [2.2.1] — 2026-05-31 — Perf-regression fix + architecture-audit remediation

A 5-dimension architecture/flow/perf audit (30 agents, 23 confirmed findings) traced the post-2.1 "feels slower / over-careful" regression to the anti-fabrication serialization invariant and fixed it, plus the confirmed prompt-conflict, ceremony, and config issues. All prompt edits + one regex — no new hooks or checks.

### Fixed

- **Perf (root cause): per-task serialization collapsed to one observed boundary.** The anti-fabrication rule forced *verify → apply → check → dispatch* as **separate orchestrator turns on every returned task**, ~doubling round-trips (a 7-task feature went ~12-14 → ~28-32 turns). Reworked to a single boundary — the gating check's PASS must be observed in tool output before `Edit(complete)`, and the next dispatch must not share that check's tool block; parse + verify + apply `work_updates` + action-log now fuse into one turn. The b288581 anti-fabrication guarantee is fully intact (every claimed path still git-asserted before any `complete`).
- **Perf: ground-truth gate batched per-wave.** On a parallel wave the gate now runs **once** at the all-returns barrier over concatenated `artifacts_written` (the check already loops a path list) instead of N serial per-task chains that eroded parallel-dispatch throughput.
- **Validator cry-wolf:** `scripts/post-edit-validate.sh` now accepts full model IDs (`claude-opus-4-8`), mirroring `validate.sh` — no more spurious "invalid model" warning on every `orchestrator.md` edit.
- **Conflicting prompts:** `review.md` described `tests-actually-committed` wrong ("verifies test files in plan.md") — corrected to the canonical "returned artifact paths exist + changed in git." Evaluator UI/screenshot/runtime-mandatory requirements + Refusals are now scoped to **lightweight/full** mode, so a smoke-mode UI tweak no longer over-escalates to full review.
- **Unbounded thinking trimmed:** per-MCP-query interleaved thinking (`architect.md`, `research.md`) is now conditional on a surprising/contradicting result instead of firing on every query; routine approval-signing dropped from the orchestrator's think-hard list.
- **Phantom checks reconciled:** `test-tiers-covered` / `logger-imported` / `mcp-preflight` / `current-points-to-existing-feature` had no scripts but were cited as runnable (even "self-run them"). Renamed the invariant example to the shipped `active-feature-consistent`, swapped phantom rows in `primitives.md` for shipped checks, and marked test-tier/logger/MCP-preflight as prose-enforced across `workflow.md`/`review.md`/`implementor.md`/`evaluator.md`.

### Changed

- **`plugin.json`** — removed the dead `settings.agent` block (not a manifest field; auto-selection works via the root settings.json `setup.sh` writes). **`marketplace.json`** — trimmed the plugin entry to inherit version/author from `plugin.json` (no more version drift).
- **`recovery.md`** — unified three drifting compaction thresholds (12 / 5 / 5) to one derived `≥8` trigger, matching the action log's self-compaction point.
- **`session-start-context.sh`** — trimmed the redundant "go read everything" header tail (the orchestrator's session-start routine already does this).
- **`orchestrator.md`** — documented the intentional no-`mcp__*` tools allowlist so it isn't "fixed" away.
- **Contributor docs:** `AGENTS.md` "After Making Changes" checklist now includes the CHANGELOG + version-bump step (with semver) and drops stale CLAUDE.md table refs; `CLAUDE.md` names the hygiene gate. So the repo self-maintains without prompting.

## [2.2.0] — 2026-05-31 — Deploy/ops primitives, lifecycle hooks, anti-fabrication hardening

Everything between 2.1.0 and here: a deploy/ops capability, SessionStart/PreCompact hooks that make resume durable, and a hard line against fabricated progress — claims are now verified against git ground truth, and a failed Write/Edit is a hard stop for *both* the implementor and the orchestrator's own writes.

### Added (checks: 14 → 15, templates: 9 → 12)

- **Deploy mode** in `agents/orchestrator.md` — `deploy` / `rollback` / `env-change` with a mandatory production-approval gate (never deploys without the user's go-ahead in the orchestrator's own conversation), preflight env-var diff, post-deploy URL verification, and `deploy` / `rollback` action-log events.
- **Operations artifact category** + templates: `deployments.template.md`, `environments.template.md`, `open-threads.template.md`. `open-threads.md` is append-only and survives `/compact`.
- **Lifecycle hooks** (`hooks/hooks.json` + scripts): **SessionStart** injects resume state (CURRENT, open-threads, action-log tail) via `scripts/session-start-context.sh`; **PreCompact** writes a durable breadcrumb via `scripts/pre-compact-checkpoint.sh`; SubagentStart logging + PostToolUse frontmatter validation. All no-op outside a coding-agent project.
- **New checks:** `env-vars-present`, `no-secrets-staged` (blocks `.env` / private keys / token patterns at the commit gate), `stack-justified` + `test-infra-declared` (gate the spec draft), `review-passed` (commit gate requires the evaluator's `review.md` Status: PASS).
- **`scripts/validate.sh`** — check-reference linter (warns on named-but-unimplemented checks) + a derive-and-verify Inventory section that FAILS if `AGENTS.md`'s canonical counts drift from directory reality.

### Changed

- **MCP servers 7 → 5** — dropped `chrome-devtools` and `deepwiki`; scrubbed stale references across ~10 files; `e2e-testing` skill rewritten Playwright-only.
- **Implementor: build, don't review.** Removed `code-review` from preloaded skills (it's the evaluator's primitive — carrying it primed review-mode), added a "ship files, not findings" mission with teeth, and a rule for bugs-found-while-building (log to nits, keep building). Fixes off-task implementor returns observed in live runs.
- **Orchestrator: derive, don't duplicate.** Wave ground-truth gate now points at the codified `tests-actually-committed wave` check instead of an ad-hoc `git status`; log-compaction trigger is derived from the action log itself (removed the hand-synced `dispatches_since_compact` Checkpoint field).
- **Diagnose-first** for bug reports — symptom-without-cause routes to the debugger before size classification.
- **Vendor-neutral AGENTS.md** emitted on close-out (no `.coding-agent/` / protocol / check leakage into the consumer project's docs).

### Fixed

- **Anti-fabrication ground-truth gate.** A subagent's `return:` is a claim, not proof: completion is now verified against git before `work.md` records it. The orchestrator must never narrate test counts or "Wave N complete" it didn't observe in tool output that turn.
- **A failed Write/Edit is a HARD STOP — for both actors.** An `Edit` whose `old_string` doesn't match, or a `Write` to an unread file, doesn't land. The implementor and the orchestrator (its own coordinator-state and inline micro-task writes) must verify the edit returned success before claiming the change — this is what produced earlier fabricated "verified" commits.
- **Commit gate requires evaluator review PASS** (`review-passed`) before any commit — no substituting a partial `tsc`/build signal for the evaluator's verdict.
- **Coordinator artifacts no longer deleted by git.** `.coding-agent/` gitignoring is mandatory and non-skippable at session-start preflight; staging is always scoped (`git add -- . ':(exclude).coding-agent'`) — NEVER `git add -A`. Prevents `intent.md`/`spec.md`/`plan.md`/`session.md` being swept in and then erased by a later `git reset --hard`/`clean`.

## [2.1.0] — 2026-05-29 — Thinking + research workflow

Leverage recent Claude capabilities (adaptive/extended thinking, interleaved thinking, the multi-agent research pattern, context editing) across the plugin's thinking and research workflow.

### Added (skill count: 54 → 55, protocols: 9 → 10, templates: 8 → 9)

- **`protocols/research.md`** — orchestrator-led parallel research fan-out: decompose → dispatch concurrent investigators → adversarial verification → cited synthesis. Mirrors Anthropic's multi-agent research system (lead agent + 3–5 parallel subagents, interleaved thinking after tool results).
- **`skills/practices/deep-research/SKILL.md`** — the decompose / fan-out / interleaved-think / verify / synthesize methodology, with anti-patterns.
- **`templates/research.template.md`** — cited research artifact (findings + confidence, refuted/demoted claims, synthesis, open questions).
- **`Research` artifact category** in `docs/concepts/primitives.md` (`research.md`, optional, append-only).
- **Architect `research_request` return + `status: needs-research`** — escape hatch to offload breadth-heavy research to the orchestrator's fan-out, then synthesize verified findings.

### Changed

- **Orchestrator → `claude-opus-4-8`** (adaptive thinking) + new "Thinking & context discipline" section: steer thinking at irreversible decisions, lean on context editing / compaction, treat on-disk artifacts (`session.md`, `work.md`, `learnings.md`) as durable memory across compaction, discover MCP tools rather than enumerate them. Documented the parallel research fan-out dispatch pattern (multiple `Agent` calls in one message).
- **Think-hard cues at irreversible decision points:** ideation-council synthesis, plan wave decomposition, debugger diagnosis, evaluator PASS verdict.
- **Interleaved-thinking expectation** documented for architect research, debugger isolation, and the `debugging` skill — reason about each tool result before the next probe.
- **Adversarial verification** added to `spec-writing` test-infra research — refute load-bearing claims (second source / recency check) before recording.
- **`plan-writing.md § Practice skills routing`** — added `deep-research` row.

## [2.0.1] — 2026-04-22 — Post-2.0 hardening from real acceptance runs

Patch release tracking fixes from S1–S7 acceptance scenarios in `test-agents/v2-runs/`. No primitive changes; behavior corrections, vocabulary disambiguation, and skill-set tightening.

### Removed (skill count: 58 → 54)

- **`coordination-templates`** — 100% redundant with `templates/work.template.md` + `protocols/implementation.md` + `protocols/recovery.md`. Unique "Context Health Signals" table moved to `protocols/recovery.md`.
- **`context-management`** — overlapping with `protocols/recovery.md` + `templates/session.template.md`. Unique subagent-delegation heuristic moved to `agents/orchestrator.md`; rewind advisory to `protocols/recovery.md`.
- **`research-cache`** — vestigial v1; never read in v2 (architect writes research inline into `spec.md § Test Infrastructure`).
- **`project-detection`** — vestigial v1; covered by architect's discovery Q&A + AGENTS.md probe.

### Added

- **`templates/learnings.template.md`** — canonical schema for `.coding-agent/learnings.md` with worked example. First-ever write now has consistent shape.
- **`protocols/plan-writing.md § Practice skills routing`** — moved out of `CLAUDE.md`. CLAUDE.md is plugin docs for humans; runtime references should live in protocols. Architect consumes the table at runtime via `${CLAUDE_PLUGIN_ROOT}/protocols/plan-writing.md`.
- **`protocols/close-out.md` step 4.5** — dispatch implementor with `ci-testing-standard` skill on first-feature greenfield. Restores v1 behavior lost in v2 rewrite.
- **`agents/debugger.md` preloaded skills** — `observability` + `debugging` (was empty; debugger body uses log reading + general debugging methodology).
- **`docs/redesign/primitives.md § Avoid vocabulary collision`** — explicit 3-row reference table disambiguating artifact `state:`, task `task-state`, and review `## Status`. Prevents the `state: complete` vs `state: active` confusion that broke the close-out check on review.md.
- **`ARCHITECTURE.md § Subagent tool & MCP access`** — explains why subagents have no `tools:` field (plugin subagents lose MCP access if `tools:` is set).

### Fixed

- **Architect approval-gate forging.** Subagents have no real `AskUserQuestion` reach; it lives in the subagent's isolated context. Architect was signing `approved_by: user` on spec.md/plan.md without the user actually seeing the question. Fixed: architect writes drafts only; orchestrator owns ALL user approval gates; structured `ask_user.questions` bundle for discovery.
- **`mcpServers:` ignored in plugin subagents.** Removed `mcpServers:` from architect/implementor/evaluator/debugger frontmatter (silent no-op in plugins). Removed restrictive `tools:` field from those four — they now inherit parent session tools (including all MCPs from `.mcp.json`). Explicit "do not dispatch" + "do not call AskUserQuestion" rules added to each subagent's prompt body to compensate.
- **Intent immutability vs escalation.** Workflow-spec said "mode flips to small" on Touch-up→Small escalation but template declared `mutability: immutable`. Fixed: escalation does NOT edit `intent.md`; it adds `plan.md` to the existing feature dir. The signed user contract stays truthful at original mode/size.
- **`revisions-resolved.sh` regex too strict.** Old regex required bare `^Status: pending` line; missed common markdown variants like `- **Status:** pending user decision`. New regex strips `**` markers and matches with optional bullet prefix; supports prose suffixes after `pending`. Tested against 5 variants.
- **State-vocabulary collision (the real bug behind the close-out check failure).** Three "state" concepts conflated: artifact `state:` (lifecycle), task `task-state` in `work.md § Tasks` (work progress), and review `## Status` (PASS/FAIL). Evaluator wrote `state: complete` on review.md — task-state vocab in artifact-state field. Fixed in `protocols/implementation.md` + `protocols/review.md` + `agents/evaluator.md` + `templates/review.template.md`; reference table added to `docs/redesign/primitives.md`.
- **Architect's description claimed "Asks user discovery questions in batches."** Contradicted the AskUserQuestion-removal fix. Updated to "Drafts discovery questions as a structured ask_user bundle for the orchestrator to ask."
- **Architect didn't read learnings.md until PLAN phase.** Past gotchas affect stack + test-infra picks in SPEC. Added Step 1.5 in spec phase: read `learnings.md` before identifying unknowns.

### Implementor process additions (from S2 run)

- **Test-path discovery** before writing tests. Read `vitest.config.*` / `jest.config.*` / `pyproject.toml [tool.pytest]` for active include/testMatch pattern. Placing tests outside config patterns silently skips them.
- **Belt-and-braces combination test** required when a feature combines multiple transforms. Catches implementations correct in isolation but missing the combination.
- **Delete obsolete-by-intent artifacts.** Counterpart to `load-bearing-markers`: preserve non-obvious fixes; delete tests/stubs/mocks that contradict approved intent.

### Acceptance test suite (`test-agents/V2-ACCEPTANCE-TESTS.md`)

- S2 redesigned: replaced `expect(1).toBe(2)` sabotage (obsolete-by-intent) with belt-and-braces realistic mistake.
- S4 fixed: predecessor-slug references corrected; Feature→Feature vs Micro→Feature variant vocabularies separated.
- S7 expanded to 3 sub-tests: Layer 1 preflight (S7a), Layer 1 self-policing under prompt pressure (S7b), Layer 2 isolation test with hand-crafted tainted review.md (S7c).
- New scenario-authoring rules: never sabotage with intent-contradicting tests; discover test-path first; treat env breakage as gotcha not FAIL; test defense-in-depth layers in isolation.
- `audit.sh` works against any `.coding-agent/` tree, validates all primitive invariants.

### Infra

- `scripts/setup.sh` notes the parallel-implementor Bash permission caveat: write `.claude/settings.json` (project-shared) when patterns must propagate to parallel subagent batches. `settings.local.json` may not propagate reliably.
- Test-agents folder now has comprehensive `.claude/settings.json` at root + each `v2-runs/S*/` scenario.

---

## [2.0.0] — 2026-04-20 — First-principles redesign

Clean break from v1. No backwards compatibility with v1 artifacts. v1 feature directories remain readable but v2 protocols do not consume them. Profile (`~/.coding-agent/profile.md`) and global learnings remain compatible.

### Added

**Four primitives, explicit:**
- **Actor** — Orchestrator + Architect + Implementor + Evaluator + Debugger + User. Only the Orchestrator dispatches.
- **Artifact** — five categories (Intent, Plan, Work, Findings, Memory), typed frontmatter with `mutability:` class (`immutable` / `append-only` / `single-writer-mutable` / `composite`).
- **Skill** — scope, trigger, category declared in frontmatter; Architect picks the manifest per task.
- **Check** — deterministic bash scripts, exit 0/1 + JSON output, replace ~70 prose MUST rules.

**Nine named protocols** (new `protocols/` directory) — intake, spec-writing, plan-writing, implementation, review, fix-round, close-out, redirect, recovery. Agents reference by `${CLAUDE_PLUGIN_ROOT}/protocols/<name>.md`; they do not redescribe the workflow.

**Ten deterministic check scripts** (new `checks/` directory) — intent-approved, spec-approved, plan-approved, revisions-resolved, ui-evidence, no-raw-print, close-out-complete, action-logged, active-feature-consistent, plus lib.sh shared helpers. All tested on happy + failure paths before ship.

**Seven artifact templates** (new `templates/` directory) — canonical frontmatter stubs for intent, spec, plan, work, review, diagnosis, session.

**`scripts/setup.sh`** — one-command per-project installer. Writes `.claude/settings.local.json` with `defaultMode: acceptEdits` + broad allow + narrow ask for dangerous ops (git push, rm -rf, sudo, publish). Auto-detects iOS and enables xcodebuild / ios-simulator MCPs. Updates `.gitignore` for `.claude/settings.local.json` and `.coding-agent/`.

**`ARCHITECTURE.md`** — ASCII diagrams for topology, artifact lifecycle, supersession rule, check placement, fix-round escalation, memory scopes, plugin file layout.

**Design docs (`docs/redesign/`)** — `primitives.md`, `workflow-spec.md`, `lifecycle.md`.

### Changed

**Agents rewritten.** Each under ~150 lines (was 114–410 in v1):
- Reference protocols via `${CLAUDE_PLUGIN_ROOT}/...` (survives marketplace caching)
- Return structured YAML `return:` block; Orchestrator parses + applies to `work.md`
- Structured-return schema: `artifacts_written`, `status`, `work_updates.{task_states, deviations, revisions, decisions, nits}`, `ask_user`, `notes`

**Artifact consolidation.** Nine+ files collapsed to five categories:
- `work.md` merges v1's `progress.md`, `handoff.md`, `session-state.md`, `in-flight.md`, `nits.md` into one single-writer-mutable ledger with explicit sections.
- `session.md` is composite: `## Checkpoint` (single-writer-mutable) + `## Action Log` (append-only).

**User approvals owned exclusively by Orchestrator.** Subagent `AskUserQuestion` does not reach the real user (stays in subagent context). Architect now writes `spec.md` and `plan.md` in `state: draft` with blank approval fields; Orchestrator prints the body in chat, calls `AskUserQuestion`, and signs `approved_by: user` only on real user approval.

**Supersession rule.** Approved `spec.md` / `plan.md` are immutable forever. Mid-implementation amendments live in `work.md § Plan Revisions` with `Supersedes: plan.md §<section>` pointer. Architect, if re-dispatched for a revision, writes only into `work.md` (never edits approved artifacts).

**Close-out protocol.** Eight deterministic steps on review PASS, before commit gate: freeze artifacts, distill to `learnings.md`, update AGENTS/ARCHITECTURE if applicable, clear `CURRENT`, update `session.md`, append action-log entry, run all close-out checks.

**Path references.** All plugin-internal references use `${CLAUDE_PLUGIN_ROOT}/...` instead of relative paths. Works in dev (`--plugin-dir`) and marketplace-cached contexts.

**Plugin manifest** — version 2.0.0, description updated.

### Removed

- `pipeline-verification/verify-stage.sh` skill — wasn't invoked in practice; replaced by the `checks/` directory.
- "PASS pending human verification" escape hatch in Evaluator — UI projects either have `screenshots/` evidence (PASS) or they don't (FAIL with `BROWSER_MCP_UNAVAILABLE` or `BROWSER_EVIDENCE_MISSING` reason).

### Known issues

- Architect-approval-forging observed in first post-v2 S1 test run: spec and plan signed `approved_by: user` at the same timestamp as architect dispatch-returned. Fix landed in this release (Architect writes `state: draft` only; Orchestrator signs after real `AskUserQuestion`) but needs verification on re-run. Acceptance suite at `test-agents/V2-ACCEPTANCE-TESTS.md` has checkpoints that catch forged approvals.

### Migration

No automatic migration. v1 feature directories (`.coding-agent/features/<slug>/`) remain readable but v2 protocols will not consume them. Either close out v1 in-flight features manually against v1 agents, or archive the `.coding-agent/` directory and start fresh. Profile and global learnings are forward-compatible.

---

## [Unreleased]

### Added (from personal-knowledge-base learnings — 2026-04-11)

**Framework-agnostic bug preventers:**

- **Evaluator: dev server port detection.** Never hardcode port 3000/5173. Parse the actual listening port from dev server stderr. Applies to any dev server (Next, Vite, Astro, Nuxt, webpack-dev-server). Prevents "API is broken" false positives when another process owns the default port.
- **Evaluator: Playwright MCP self-check.** Before runtime testing, probe `mcp__playwright__browser_navigate("about:blank")` as a no-op availability check. If it fails, degrade loudly — add a Critical finding telling the user to enable `playwright` in `.claude/settings.local.json` — do NOT silently fall back to curl.
- **Evaluator: HTML-inspection Plan B.** Documented fallback when Playwright is unavailable: curl + grep for stable data-attrs (e.g., shadcn `data-sidebar`/`data-slot`), pair with explicit "human 30-second eyeball" notes, mark review as degraded. A review done with HTML inspection alone cannot PASS — can only complete with `PASS (pending human verification)`.
- **Evaluator: restore test fixtures.** If smoke tests edited files, `git checkout -- <paths>` before returning. Dirty fixtures leak into `git status` and confuse the orchestrator's commit step.
- **Evaluator: native dialog vs modal.** `browser_handle_dialog` only handles native `window.confirm/alert/prompt`. Modal React components (shadcn AlertDialog, Radix Dialog) are regular DOM — use `browser_click`. Hanging scripts waiting for a dialog that never fires are usually this.
- **Evaluator: lightweight mode trigger.** If files changed list contains zero paths under `src/`/`app/`/`lib/`/`pkg/`, default to lightweight mode automatically. Packaging-only changes should review in <200 lines.
- **Implementor: CLI version verification.** When invoking third-party CLIs (`shadcn`, `create-next-app`, etc.), verify the current interface via Context7 or `--help` before running commands from memory. `shadcn@latest` in 2026 is v4 with a preset-based CLI; the classic `--base-color new-york` flags are from v2.x.
- **Implementor: load-bearing comments.** Use `// LOAD-BEARING: <reason>` marker on code that looks over-engineered but has a specific reason. Prevents future "simplification" passes from regressing defensive patterns.
- **Orchestrator: preserve load-bearing patterns on refactor.** Before dispatching an implementor to rewrite an existing file, grep it for `// LOAD-BEARING`, `// HACK`, `// F-\d+:` markers, and paste them into the dispatch prompt with "preserve exactly" instructions.
- **Architect: detect partial drafts.** When some files exist but the project is incomplete (scaffolded but not implemented), treat them as an implementation draft to extend, not a codebase to replace.
- **Architect: respect locked decisions.** If the user's brief or existing AGENTS.md declares decisions as "locked" / "decided" / "do not re-litigate", acknowledge them in the spec Technical Approach and do NOT re-open them in discovery questions.
- **Architect: performance budgets for UI/latency-sensitive apps.** Spec must declare measurable ceilings in the stack's native units (First Load JS, Lighthouse score, app-launch time, p99 latency, TTFB). Without declared budgets, bundles balloon.
- **Architect: error-path criteria in plan evaluation.** Every wave must have at least one "misconfiguration / error path" criterion, not just happy paths. Plus canonical verification commands where applicable.

**Practice skill additions:**

- **project-docs: CLAUDE.md and AGENTS.md must not duplicate.** One is the source of truth, the other is a 5-line redirect. Duplication guarantees drift.
- **publish-ready: CLI bin loaders (new Step 7).** Bin loaders MUST use `import.meta.url` not `process.cwd()` to find the package root. Canonical verification: `cd /tmp && node /abs/path/bin/mytool.mjs`. `tsx` in devDependencies works for `pnpm link --global` but drops out on `npm i -g .`. Global CLIs don't get `.env` for free — choose CLI flags, user config file, or shell env vars.
- **publish-ready: Shipping your own MCP tools (new Step 8).** Project-scoped `.mcp.json` at project root auto-wires MCP tools for any Claude Code session opened in the directory. Use `pnpm mcp` (package script), not `kb-mcp` (linked binary), so it works before `pnpm link --global`.
- **api-design: routes are transports, not logic.** Every route handler should be ~10 lines. Business logic lives in core/service layer, not in Next.js Route Handlers / Express middlewares / FastAPI endpoints / Gin handlers. Testing core = testing every route.

**Framework-specific skill additions:**

- **nextjs-specialist: Next.js 15+ gotchas section.** Async `params`/`searchParams` must be `await`-ed (runtime errors, not typecheck errors). `dynamic(..., { ssr: false })` forbidden in server components — needs a `'use client'` loader wrapper. `next-themes` FOUC prevention requires `<html suppressHydrationWarning>` + IIFE present in served HTML. Dev server port fallback. `pnpm dev` wipes `.next/` on restart — verify artifacts before starting dev server.
- **css-tailwind-specialist: Tailwind v4 gotchas.** Tailwind v4 has NO config file — `@import "tailwindcss";` + `@theme {}` block in CSS. `@plugin "@tailwindcss/typography";` directive replaces `plugins: []`. Don't create `tailwind.config.js` on a v4 project.
- **css-tailwind-specialist: shadcn/ui uses OKLCH.** Current shadcn uses OKLCH color space, not HSL. Any older guidance is out of date.
- **ui-excellence: shadcn data-attr verification.** Stable data-attributes (`data-sidebar`, `data-slot`) enable HTML-inspection verification when Playwright is unavailable.

- **Deep Agents rules** in `agent-frameworks-specialist` skill — new `rules/deepagents.md` (AF-07) documenting the `deepagents` library: when to use it, minimal example, subagent factory pattern, built-in tools, multi-provider model strings, system prompt patterns, and anti-patterns. Learned from building a real research agent.
- **CLI logging gotchas** in observability skill — `sonic-boom is not ready yet` crash when pino's async stream meets `process.exit()`. Rule: `sync: true` for CLIs, `sync: false` for servers with flush hooks. Equivalent notes for Python, Go, Java.
- **Null Object Pattern for optional loggers** — use `pino({ level: "silent" })` not hand-rolled stubs. Examples for pino, structlog, slog.
- **Factory pattern for testable components** — `createWebSearch(logger?)` pattern with backward-compatible defaults for test isolation and per-component child loggers.
- **Self-diagnosis startup log** — one info entry with node version, platform, cwd, log file, package version, env-var presence (booleans only, never values), upstream service URLs.

### Changed

- Observability skill now has 8 core rules (added: logs separate from outputs, self-diagnosis startup log).
- **Orchestrator prompt** — expanded bright-line examples (what crosses Micro→Small even under 30 lines), mid-task refinements rule (iterative chat must use cumulative totals), same-bug-twice rule (user-signaled recurrence routes to Debugger). Captures lessons from orchestrator self-critique in `codingAgent/.coding-agent/learnings.md`.
- **Debugging skill** — added two rules files (`direct-api-diagnostic.md`, `read-adapter-source.md`) with concrete patterns for debugging agent frameworks (bypass with curl, read adapter source when docs lag code).
- **deepagents rules** — added Model Capacity section with three-bucket routing (frontier / ollama-cloud / small-local → ReAct), Ollama gotchas (`temperature: 0`, `think: true`, adapter defaults), and Ollama Cloud auth modes.
- **Artifact layout — per-feature subdirectories.** Every feature now gets its own directory at `.coding-agent/features/<YYYY-MM-DD>-<slug>/` containing its `spec.md`, `plan.md`, `progress.md`, `review.md`, and (when applicable) `diagnosis.md`. A `CURRENT` pointer file at `.coding-agent/CURRENT` tracks the active feature. Past features are never overwritten — history accumulates naturally. Replaces the destructive `.prev.md` rename scheme that only preserved one previous iteration.
- **`learnings.md` is now append-only.** New entries are prepended (newest on top), structured as `## <date> — <slug>` blocks. Previous entries are never overwritten. Future sessions see every feature's learnings in chronological order.
- **Orchestrator state machine** updated to read `CURRENT` first, operate on `features/<CURRENT>/*`, and create a new feature directory + update `CURRENT` when a new request arrives after a completed pipeline.
- **Architect** now has the `Skill` tool in its frontmatter and an explicit "browse specialist skills" step in Phase 1 research (Read `skills/<domain>/*/SKILL.md` before writing the spec so the plan references existing patterns instead of inventing new ones). Architect also reads past feature directories and `learnings.md` for project history.
- **Implementor, evaluator, debugger** updated to read/write from `features/<CURRENT>/` instead of flat `.coding-agent/` files. Evaluator's regression check now looks for the most recent past feature's `review.md` (by mtime or name) instead of the old `review.prev.md`.
- **`verify-stage.sh`** updated: resolves the active feature via `.coding-agent/CURRENT`, validates artifacts in `features/<current>/`, and falls back to the legacy flat layout with a warning for backward compatibility. Tested with 4 scenarios (new layout pass, legacy pass, missing state, broken pointer).

## [1.0.0] - 2026-04-08

First public release.

### Architecture

- **5 agents, 1 level deep** — orchestrator, architect, implementor, evaluator, debugger
- **54 specialist skills** across frontend, mobile, backend, data, infra, and practices domains
- **7 MCP servers** — context7, exa, deepwiki, playwright, chrome-devtools, xcodebuild, ios-simulator
- **Deterministic pipeline gates** via `verify-stage.sh` script
- **Task size classification** — Micro/Small/Medium/Large with appropriate pipeline paths
- **Mandatory evaluator** after every implementor dispatch with lightweight mode for small changes
- **Reflection step** writes `learnings.md` after review PASS for cross-session knowledge
- **Human approval gates** — architect must get user approval before returning spec and plan

### Agents

- `orchestrator` (opus) — state machine, dispatches subagents, validates artifacts
- `architect` (opus) — research + design, two mandatory human gates, uses real library docs via MCP
- `implementor` (sonnet) — writes code by domain, tests first, mandatory structured logging
- `evaluator` (opus) — builds project, runs tests, tests running app via Playwright/simulator
- `debugger` (opus) — root-cause analysis when bugs survive a fix attempt

### Skills

**Frontend:** react-specialist, nextjs-specialist, css-tailwind-specialist, testing-specialist, ui-design, ui-excellence, tanstack, generative-ui-specialist, assistant-chat-ui, react-patterns, composition-patterns, accessibility, performance

**Mobile:** ios-swiftui-specialist, ios-testing-debugging

**Backend:** nodejs-specialist, python-specialist, go-specialist, typescript-specialist, agent-frameworks-specialist, llm-integration, api-design, auth-patterns

**Data:** postgres-specialist, redis-specialist, migration-safety

**Infra:** aws-specialist, docker-specialist, docker-best-practices, terraform-specialist, deployment-patterns, ci-cd-patterns

**Practices:** tdd, code-review, security-checklist, config-management, observability, service-architecture, error-handling, e2e-testing, integration-testing, dependency-evaluation, shared-contracts, release, publish-ready, project-docs, pipeline-verification, research-cache, project-detection, ideation-council, coordination-templates, migration-safety

**General:** debugging, documentation, git-workflow

### Documentation

- README.md — architecture overview and quick start
- CONTRIBUTING.md — contribution guidelines
- ACKNOWLEDGMENTS.md — credits to skills.sh, Anthropic skills, OSS projects
- AGENTS.md — dev workflow for working on the plugin itself
- LICENSE — MIT
- GitHub templates for issues and PRs
- CI workflow for plugin structure validation
