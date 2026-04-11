# Changelog

All notable changes to this plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
