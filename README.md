# coding-agent

> A Claude Code plugin for building software end-to-end — from idea to shipped code.

**5 agents** · **54 skills** · **7 MCP servers** · **Deterministic pipeline gates**

The plugin turns a vague prompt like "build me a blog with comments" into a structured pipeline: research → spec (you approve) → plan with evaluation criteria (you approve) → parallel implementation by domain → independent review with real UI testing → commit.

## Why

Most AI coding agents happily generate 500 lines that compile but break at runtime. They skip the design step, hallucinate library APIs, never actually launch the app to verify the UI, silently swallow errors, and forget everything about the project the moment you come back tomorrow.

coding-agent is a reaction to those failures:

- **Separate agents for separate jobs** — the builder is different from the reviewer (generator-evaluator separation prevents self-evaluation bias)
- **Deterministic gates** — scripts verify each pipeline stage, not prompts
- **Real runtime testing** — the evaluator builds the project, starts the servers, and drives the UI via Playwright or iOS simulator
- **Research from real docs** — architect uses Context7/DeepWiki/Exa to fetch current library docs, not training data
- **Human gates where they matter** — you approve the spec and plan before any code is written
- **Knowledge persists** — AGENTS.md and learnings.md mean session #2 already knows the project

## Quick Start

### Install

```bash
# Clone into Claude Code's plugins directory
git clone https://github.com/your-username/coding-agent ~/.claude/plugins/coding-agent

# Or use --plugin-dir flag
claude --plugin-dir /path/to/coding-agent
```

### Enable in a project

Add to `.claude/settings.local.json`:

```json
{
  "agent": "coding-agent:orchestrator",
  "enabledPlugins": {
    "coding-agent@/path/to/coding-agent": true
  }
}
```

### Use it

```
You: "Build a todo API with Express and SQLite"

Orchestrator (classifies: Large feature → full pipeline)
  ↓
Architect asks: "Should tasks have tags? Priority levels? User auth?"
You answer → Architect writes spec.md → You approve
Architect writes plan.md with evaluation criteria per wave → You approve
  ↓
Implementor (parallel waves): foundation → CRUD endpoints → validation → tests
  ↓
Evaluator: builds, runs tests, curls endpoints, writes review.md with findings
  ↓
PASS → Commit + generate README.md, ARCHITECTURE.md, AGENTS.md
```

## Architecture

```
Orchestrator (main thread) — state machine, dispatches, validates, never writes code
  │
  ├── Architect — asks user → spec.md (Gate 1) → plan.md with eval criteria (Gate 2)
  ├── Implementor(s) — writes code by domain, tests first, applies specialist skills
  ├── Evaluator — independent review, builds, runs tests, tests running app
  └── Debugger — root-cause analysis when bugs survive fix attempts
```

### 5 Agents

| Agent | Model | Role |
|-------|-------|------|
| **orchestrator** | opus | State machine. Classifies tasks by size. Dispatches subagents. Only agent with the `Agent` tool. |
| **architect** | opus | Research + design. Must ask the user discovery questions before writing. Two blocking approval gates. Uses Context7/DeepWiki/Exa MCP for real docs. |
| **implementor** | sonnet | Writes code by domain (frontend/backend/data/mobile/infra). Tests first (TDD). Mandatory structured logging. Applies specialist skills. |
| **evaluator** | opus | Independent reviewer. Builds project, runs tests, tests running app via Playwright/simulator MCP. Writes review.md with findings. |
| **debugger** | opus | Root-cause analysis when a bug survives a fix attempt. Reproduce → isolate → trace → diagnose. Writes diagnosis.md, never code. |

### Task Size Classification

The orchestrator classifies every request before dispatching:

| Size | Heuristic | Pipeline |
|------|-----------|----------|
| **Micro** | ≤2 files, ≤30 lines, no new logic | Orchestrator writes directly → tests → commit |
| **Small** | 2-5 files, clear scope | Implementor → Evaluator (lightweight) |
| **Medium** | Design decisions needed | Architect (plan only) → Implementor → Evaluator |
| **Large** | New feature, architectural | Full pipeline (spec+plan+implement+review) |

**Bright line:** if you're about to touch >2 files OR write >30 new lines of logic → dispatch an Implementor.

### Deterministic Pipeline Gates

Every stage is gated by a script that exits 0 or 1. Agents can't skip it.

```bash
./skills/practices/pipeline-verification/scripts/verify-stage.sh spec     # after architect
./skills/practices/pipeline-verification/scripts/verify-stage.sh plan     # after architect
./skills/practices/pipeline-verification/scripts/verify-stage.sh build    # after implementor
./skills/practices/pipeline-verification/scripts/verify-stage.sh tests    # after implementor
./skills/practices/pipeline-verification/scripts/verify-stage.sh review   # after evaluator
```

## Skills (54)

Skills are scoped knowledge modules. Implementor routes by domain:

### Domain Specialists

| Domain | Skills |
|--------|--------|
| **Frontend** | react-specialist, nextjs-specialist, css-tailwind-specialist, testing-specialist, ui-design, ui-excellence, tanstack, generative-ui-specialist, assistant-chat-ui, react-patterns, composition-patterns, accessibility, performance |
| **Mobile** | ios-swiftui-specialist, ios-testing-debugging |
| **Backend** | nodejs-specialist, python-specialist, go-specialist, typescript-specialist, agent-frameworks-specialist, llm-integration, api-design, auth-patterns |
| **Data** | postgres-specialist, redis-specialist, migration-safety |
| **Infra** | aws-specialist, docker-specialist, docker-best-practices, terraform-specialist, deployment-patterns, ci-cd-patterns |

### Cross-Cutting Practices

| Skill | Purpose |
|-------|---------|
| **observability** | Structured logging for Java/Node/Python/Go/Swift, framework patterns, cloud platforms (CloudWatch, Datadog, OpenTelemetry) |
| **config-management** | Typed config, validation, composition root, lightweight dependency injection |
| **service-architecture** | Singleton clients, connection pools, retry/timeout wrappers, graceful shutdown |
| **publish-ready** | package.json exports, LICENSE, GitHub templates, release workflows (inspired by Next.js, Vite, tRPC patterns) |
| **project-docs** | Generates README.md, ARCHITECTURE.md (ASCII diagrams), AGENTS.md from real codebase |
| **pipeline-verification** | The deterministic script that gates every pipeline stage |
| **research-cache** | Persistent research knowledge base — prevents redundant re-research |
| **tdd** | Test-first development |
| **code-review**, **security-checklist** | Quality gates applied by implementor and evaluator |

## MCP Servers

Configured in `.mcp.json`, available to all agents:

| Server | Purpose |
|--------|---------|
| **context7** | Current library documentation (architect, implementor) |
| **exa** | Web search — blog posts, release notes, migration guides (architect) |
| **deepwiki** | GitHub repo deep-dives (architect) |
| **playwright** | Browser UI testing (evaluator) |
| **chrome-devtools** | Console/network inspection (evaluator) |
| **xcodebuild** | iOS build/test/debug (evaluator) |
| **ios-simulator** | iOS simulator control (evaluator) |

## Artifacts

The pipeline produces these files in `.coding-agent/`:

| Artifact | Producer | Purpose |
|----------|----------|---------|
| `spec.md` | Architect | Requirements (FR-*), technical approach, non-goals, technical risks |
| `plan.md` | Architect | Tasks by domain/wave, evaluation criteria per wave |
| `progress.md` | Orchestrator | Task status tracking |
| `review.md` | Evaluator | PASS/FAIL status, findings with file:line, build result, runtime verification |
| `diagnosis.md` | Debugger | Root cause, evidence, recommended fix (when invoked) |
| `learnings.md` | Orchestrator | Gotchas, architecture decisions, patterns — for future sessions |
| `research/` | Architect | Cached library findings, codebase patterns |

Plus project-root files generated after first PASS:
- `README.md`, `ARCHITECTURE.md` (ASCII diagrams), `AGENTS.md`

## Design Decisions

- **5 agents, 1 level deep** — Claude Code subagents can't spawn other subagents. Only the main-thread orchestrator has the `Agent` tool.
- **Generator-evaluator separation** — reviewer is independent from builder to prevent self-evaluation bias.
- **Short agent prompts** — each agent is under ~800 words so they actually read their instructions. Long prompts get skipped.
- **Deterministic gates** — scripts verify pipeline stages, not prompt instructions.
- **Task sizing** — micro-tasks the orchestrator does directly; anything larger is dispatched. This was the biggest fix learned from real use.
- **Mandatory runtime testing** — the evaluator builds the project and drives the UI. "Code that compiles" ≠ "code that works."
- **Research from real docs** — architect uses MCP tools to fetch current library documentation, not training data.

## Status

Used on real projects: blog platforms, a deep research agent, an iOS app. Each iteration has been shaped by real failures — see `docs/` for retrospectives and design evolution.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Acknowledgments

Inspiration and patterns from:

- **[skills.sh](https://skills.sh)** — the agent skills ecosystem. Specifically inspired by: `anthropics/skills/frontend-design`, `vercel-labs/web-design-guidelines`, `wshobson/agents/mobile-ios-design`, `avdlee/swiftui-expert-skill`, `twostraws/swiftui-pro`, `jezweb/claude-skills/tanstack-query`
- **[Anthropic's official skills](https://github.com/anthropics/skills)** — the scripts-in-skill-folder pattern, progressive disclosure via `rules/` subdirectories
- **[Anthropic's harness design principles](https://www.anthropic.com/research/building-effective-agents)** — generator-evaluator separation, sprint contracts, file-based handoffs
- **[Top OSS projects](https://github.com/vercel/next.js)** — Next.js, Vite, shadcn/ui, Tailwind CSS, tRPC — patterns for the `publish-ready` skill

See [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md) for the full list.

## License

MIT — see [LICENSE](LICENSE).
