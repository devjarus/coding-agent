# coding-agent — Claude Code Plugin

A multi-agent software development system. 5 agents, 56 skills, 7 MCP servers. The **orchestrator** drives the pipeline, dispatching architect, implementor, evaluator, and debugger as subagents — all 1 level deep.

## Architecture

```
Orchestrator (main thread) — state machine, dispatches, validates, never writes code
  │
  ├── Architect — asks user → spec.md (Gate 1) → plan.md with eval criteria (Gate 2)
  ├── Implementor(s) — writes code by domain, tests first, applies specialist skills
  ├── Evaluator — independent review, builds, runs tests, tests running app
  └── Debugger — root-cause analysis when bugs survive fix attempts
```

**Constraints:**
- Subagents cannot spawn subagents → all dispatches are 1 level deep
- Plugin agents cannot use mcpServers/hooks/permissionMode in frontmatter → all MCP in `.mcp.json`
- Subagents cannot use Agent(Explore) → they use Read/Glob/Grep directly
- Only the orchestrator has the Agent tool

## Orchestrator State Machine

The orchestrator classifies every request by size before dispatching:

| Size | Pipeline |
|------|----------|
| Micro (≤2 files, ≤30 lines, no new logic) | Orchestrator writes directly → tests → commit |
| Small (2-5 files, clear scope) | Implementor → Evaluator (lightweight) |
| Medium (design decisions needed) | Architect (plan) → Implementor → Evaluator |
| Large (new feature, architectural) | Architect (spec+plan) → Implementor → Evaluator |

```
Classify → Dispatch by size
  → Implementor → Evaluator (mandatory after every dispatch)
  → review.md FAIL → Fix Round 1 → Round 2 (Debugger) → Round 3 (Escalate)
  → review.md PASS → Fix minor findings → Reflect → Generate docs → Commit
```

Pipeline complete + new message → reflect, archive, classify, restart.

## Artifact Protocol

| Artifact | Producer | Consumed by |
|----------|----------|-------------|
| `spec.md` | Architect | Implementor, Evaluator |
| `plan.md` | Architect | Implementor, Evaluator |
| `progress.md` | Orchestrator | Orchestrator |
| `review.md` | Evaluator | Orchestrator |
| `diagnosis.md` | Debugger | Implementor |
| `handoff.md` | Orchestrator | Implementor, Debugger (what was tried, why it failed, what's ruled out) |
| `session-state.md` | Orchestrator | Orchestrator (session checkpoint for recovery after /clear) |
| `learnings.md` | Orchestrator | Future sessions (gotchas, decisions, patterns) |
| `README.md` | Implementor (project-docs) | Humans |
| `ARCHITECTURE.md` | Implementor (project-docs) | Humans, Agents (ASCII diagrams) |
| `AGENTS.md` | Implementor (project-docs) | All agents |

## Agents

| Agent | Model | Key Behavior |
|-------|-------|-------------|
| **orchestrator** | opus | State machine. Dispatches only. Never writes code/specs/reviews. |
| **architect** | opus | MUST ask user before writing. MUST get approval before returning. Verifies dependencies. |
| **implementor** | sonnet | Tests first (including integration). No silent error suppression. Pins dependency versions. |
| **evaluator** | opus | Builds first. Runs tests. Tests running app (Playwright/simulator). Runtime mandatory. |
| **debugger** | opus | Reproduce → isolate → trace → diagnose. Writes diagnosis.md, never code. |

## Skills (51)

### Implementor skill routing by domain

| Domain | Specialist Skills |
|--------|------------------|
| frontend | react-specialist, nextjs-specialist, css-tailwind-specialist, testing-specialist, ui-design, ui-excellence, tanstack, generative-ui-specialist, assistant-chat-ui, react-patterns, composition-patterns, accessibility, performance |
| mobile | ios-swiftui-specialist, ios-testing-debugging |
| backend | nodejs-specialist, python-specialist, go-specialist, typescript-specialist, agent-frameworks-specialist, llm-integration, api-design, auth-patterns |
| data | postgres-specialist, redis-specialist, migration-safety |
| infra | aws-specialist, docker-specialist, docker-best-practices, terraform-specialist, deployment-patterns, ci-cd-patterns |

### Practices (applied across domains)

| Skill | Applied By |
|-------|-----------|
| tdd | Implementor (preloaded) |
| code-review | Implementor, Evaluator (preloaded) |
| security-checklist | Implementor, Evaluator (preloaded) |
| config-management | Implementor |
| observability | Implementor |
| error-handling | Implementor |
| e2e-testing | Evaluator |
| integration-testing | Implementor |
| dependency-evaluation | Architect |
| shared-contracts | Implementor |
| release | Orchestrator |
| publish-ready | Implementor (before public release) |
| ci-testing-standard | Implementor (after first feature ships) |
| service-architecture | Implementor (apps with external clients/services) |
| context-management | Orchestrator |
| project-detection | Architect |

### Pipeline skills (preloaded into agents)

| Skill | Preloaded In |
|-------|-------------|
| coordination-templates | Orchestrator |
| pipeline-verification | Orchestrator |
| context-management | Orchestrator |
| ideation-council | Architect |
| project-docs | Implementor (after review PASS) |
| research-cache | — (optional, architect saves findings) |

### General

debugging, documentation, git-workflow

## MCP Servers (`.mcp.json`)

| Server | Purpose |
|--------|---------|
| context7 | Library documentation (architect, implementor) |
| exa | Web search — blog posts, release notes, migration guides (architect) |
| playwright | Browser UI testing (evaluator) |
| chrome-devtools | Console/network inspection (evaluator) |
| deepwiki | Dependency research (architect) |
| xcodebuild | iOS build/test/debug (evaluator) |
| ios-simulator | iOS simulator control (evaluator) |

## Development

```bash
./scripts/validate.sh && claude plugin validate .
```
