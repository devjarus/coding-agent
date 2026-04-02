# coding-agent — Claude Code Plugin

A multi-agent software development system. 4 agents, 45 skills, 4 MCP servers. The **orchestrator** drives the pipeline, dispatching architect, implementor, and evaluator as subagents — all 1 level deep.

## Architecture

```
Orchestrator (main thread) — dispatches, validates artifacts, tracks progress
  │
  ├── Architect — expands ideas → spec.md (Gate 1) → plan.md with eval criteria (Gate 2)
  ├── Implementor(s) — implements code by domain, applies specialist skills
  └── Evaluator — independent review against spec + plan's evaluation criteria
```

**Constraints respected:**
- Subagents cannot spawn subagents → all dispatches are 1 level deep
- Plugin agents cannot use mcpServers/hooks/permissionMode in frontmatter → all MCP in `.mcp.json`
- Subagents cannot use Agent(Explore) → they use Read/Glob/Grep directly for codebase exploration
- Only the orchestrator (main thread) has the Agent tool

## Artifact Protocol

The orchestrator enforces structured handoffs via `.coding-agent/`:

| Artifact | Producer | Validated by Orchestrator | Consumed by |
|----------|----------|--------------------------|-------------|
| `spec.md` | Architect | Has Overview, Requirements (FR-*), Non-Goals | Implementor, Evaluator |
| `plan.md` | Architect | Has tasks with domain/wave/files/criteria, **evaluation criteria per slice** | Implementor, Evaluator |
| `progress.md` | Orchestrator | — | Orchestrator |
| `review.md` | Evaluator | Has Status (PASS/FAIL), Findings with file:line | Orchestrator |

If an artifact is missing required sections, the orchestrator re-dispatches the agent with specific feedback.

## Agents

| Agent | Model | Role | Built-in Tools Used |
|-------|-------|------|-------------------|
| **orchestrator** | opus | Dispatches, validates artifacts, tracks progress. Never writes code. | Agent (only agent that dispatches) |
| **architect** | opus | Expands ideas, researches, designs. Writes spec + plan. | AskUserQuestion, Glob/Grep for research |
| **implementor** | sonnet | Writes code by domain. Applies specialist skills. Tests first. | Glob/Grep for exploration, Bash for tests |
| **evaluator** | opus | Independent review. Tests running app. Finds what builder missed. | Bash for tests, Playwright MCP |

## Pipeline Flow

```
User message → Orchestrator
  ↓
1. No spec.md → Dispatch Architect
   Architect: explores codebase, asks questions, writes spec.md
   Human approves (Gate 1)
  ↓
2. spec.md exists, no plan.md → Dispatch Architect again
   Architect: decomposes into slices, writes plan.md with eval criteria
   Human approves (Gate 2)
  ↓
3. plan.md exists, tasks incomplete → Dispatch Implementor(s)
   Implementor: reads tasks, applies skills, tests first, implements
   (Can dispatch multiple in parallel for independent domains)
  ↓
4. All tasks done → Dispatch Evaluator
   Evaluator: tests against plan's eval criteria + spec requirements
   Writes review.md
  ↓
5. Review PASS → Commit and hand off
   Review FAIL → Dispatch Implementor with findings → re-evaluate
```

## Skills (45)

**Implementor skill routing by domain:**

| Domain | Specialist Skills |
|--------|------------------|
| frontend | react-specialist, nextjs-specialist, css-tailwind-specialist, testing-specialist, ui-design, generative-ui-specialist, assistant-chat-ui |
| backend | nodejs-specialist, python-specialist, go-specialist, typescript-specialist, agent-frameworks-specialist, llm-integration |
| data | postgres-specialist, redis-specialist |
| infra | aws-specialist, docker-specialist, terraform-specialist, deployment-patterns |

**Always applied:** tdd, code-review, security-checklist, config-management, observability

## Key Design Decisions

- **Single orchestrator, flat dispatch** — 1 level deep. No nesting. Respects Claude Code constraints.
- **Artifact protocol** — orchestrator validates every artifact before advancing. Missing sections = re-dispatch.
- **Evaluation criteria in the plan** — architect writes testable criteria BEFORE implementation (sprint contracts from Anthropic's harness design).
- **Generator-Evaluator separation** — evaluator is independent from implementor. Prevents self-evaluation bias.
- **Prompt expansion** — architect expands "build me a chat app" into 100+ lines of concrete requirements.
- **Spec over implementation details** — spec focuses on what/why. Plan focuses on tasks/criteria. Implementation details emerge during coding.
- **Built-in tools welcome** — agents use Explore for codebase research, AskUserQuestion for human interaction, Plan mode concepts naturally.

## Development

```bash
./scripts/validate.sh && claude plugin validate .
```
