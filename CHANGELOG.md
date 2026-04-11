# Changelog

All notable changes to this plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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
