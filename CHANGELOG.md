# Changelog

All notable changes to this plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
