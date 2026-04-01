# coding-agent

A Claude Code plugin for building software end-to-end. 7 agents, 45 skills, 3 MCP servers. The **dispatcher** loops through phases by detecting state and dispatching one agent at a time. One **domain-lead** agent adapts to any domain via skill routing.

## Pipeline

1. **Brainstormer** -- researches codebase, asks questions, produces spec, returns
2. **Planner** -- decomposes spec into vertical feature slices, returns
3. **Scaffolder** -- sets up project structure and tooling (greenfield only), returns
4. **Impl Coordinator** -- dispatches domain leads in parallel, tracks progress, drives to completion
5. **Reviewer** -- cross-cutting review: security, integration, quality, returns

## Architecture

```
Human (approves at gates: spec, plan, review)
  |
Dispatcher (Sonnet) -- LOOPS: dispatch agent -> agent returns -> re-detect state -> dispatch next
  |                    Only agent (besides coordinator) with the Agent tool
  |
Phase Agents -- Brainstormer / Planner / Scaffolder / Reviewer
  |              Each does its work and RETURNS. No chaining.
  |
Impl Coordinator (Opus) -- dispatches domain-leads in parallel (multiple Agent calls)
  |                         Max nesting: 2 levels (dispatcher -> coordinator -> leads)
  |
Domain Lead (Sonnet) -- single agent, adapts by domain via skill routing table
  |                     Uses MCP tools (Context7, DeepWiki) for research, not subagents
  |
Skills (45) -- specialist skills (react, nodejs, postgres, aws, ...)
               practice skills (tdd, security, error-handling, ...)
```

## Agents (7)

| Agent | Model | Purpose |
|-------|-------|---------|
| dispatcher | sonnet | Loops: detects state, dispatches one phase agent, re-detects on return. Has Agent tool. |
| brainstormer | opus | Researches codebase, asks questions, produces spec. Returns to dispatcher. |
| planner | opus | Decomposes spec into vertical feature slices. Returns to dispatcher. |
| scaffolder | sonnet | Greenfield project setup. Returns to dispatcher. |
| impl-coordinator | opus | Dispatches domain-leads in parallel (has Agent tool), tracks progress, verify, review, commit |
| reviewer | opus | Cross-cutting review: security, API, tests, quality. Returns to coordinator. |
| domain-lead | sonnet | Adapts to any domain. Skill routing: frontend/backend/data/infra. Uses MCP for research. |

## Domain Lead Skill Routing

| Domain | Specialist Skills |
|--------|------------------|
| frontend | react-specialist, nextjs-specialist, css-tailwind-specialist, testing-specialist, ui-design, generative-ui-specialist |
| backend | nodejs-specialist, python-specialist, go-specialist, typescript-specialist, agent-frameworks-specialist |
| data | postgres-specialist, redis-specialist |
| infra | aws-specialist, docker-specialist, terraform-specialist |

Always applied: tdd, code-review, security-checklist, config-management

## Installation

```bash
claude --plugin-dir /path/to/codingAgent
./scripts/setup-external-skills.sh  # optional ecosystem skills
./scripts/validate.sh && claude plugin validate .
```

Force as default in a project (`.claude/settings.local.json`):
```json
{ "agent": "coding-agent:dispatcher" }
```

## How It Works

**File-based coordination** via `.coding-agent/` (gitignored):

| File | Producer | Purpose |
|------|----------|---------|
| spec.md | Brainstormer | Requirements |
| plan.md | Planner | Feature slices, tasks, dependencies |
| progress.md | Coordinator | Task status, blockers, decisions |
| review.md | Reviewer | Findings by severity |
| scaffold-log.md | Scaffolder | What was set up |

**Human gates:** After spec, after plan, after review.

**Vertical planning:** Wave 1 = foundation (schema, config). Wave 2+ = feature slices (DB -> API -> UI -> test) with verification checkpoints.

**Brownfield:** Scaffolder skipped. Domain leads read existing code and adapt.

## Extending

| Add... | Create... |
|--------|-----------|
| Specialist skill | `skills/<domain>/<name>-specialist/SKILL.md` + add to domain-lead routing table |
| Practice skill | `skills/practices/<name>/SKILL.md` |
| New domain | Add row to domain-lead's skill routing table |

## Validation

```bash
./scripts/validate.sh        # Structure, frontmatter, cross-refs
claude plugin validate .      # Official validator
claude --plugin-dir .         # Load and test
```
