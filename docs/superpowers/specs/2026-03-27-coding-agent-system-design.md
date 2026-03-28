# codingAgent — Multi-Agent Software Development System

**Date:** 2026-03-27
**Status:** Design approved, pending implementation

## Overview

A Claude Code plugin that provides a layered hierarchy of AI agents for building software applications end-to-end. Supports both greenfield (from scratch) and brownfield (existing codebase) projects. The system is general-purpose and extensible — new domains and specialists are added by creating markdown files.

The plugin is fully self-contained. It builds its own agents, skills, and coordination conventions from scratch. It uses external MCP servers (Context7, Exa, Chrome DevTools) as tools but has no dependencies on other Claude Code plugins. Inspiration is drawn from existing plugins (superpowers, feature-dev, etc.) for patterns, not code.

## Architecture: Phase Agents + Domain Leads

Four layers plus shared utilities.

### Layer 1 — Phase Agents

Invoked by the human sequentially. Each owns one phase of the development lifecycle.

| Agent | Model | Responsibility | Produces |
|---|---|---|---|
| **Brainstormer** | Opus | Explores ideas, refines requirements through dialogue, identifies scope | `docs/agents/spec.md` |
| **Planner** | Opus | Decomposes spec into tasks with dependencies, assigns domains, identifies parallelism | `docs/agents/plan.md` |
| **Scaffolder** | Sonnet | Sets up project structure, config, tooling (greenfield) or analyzes existing codebase (brownfield) | Project files + `docs/agents/scaffold-log.md` |
| **Impl Coordinator** | Opus | Reads plan, dispatches domain leads, manages parallelism (max 3-4 concurrent), tracks progress, resolves cross-domain blockers | `docs/agents/progress.md` |
| **Reviewer** | Opus | Independent cross-cutting review: security, consistency, integration, quality | `docs/agents/review.md` |

### Layer 2 — Domain Leads

Dispatched by the Impl Coordinator. Each understands their domain deeply, breaks work into specialist tasks, reviews specialist output before reporting completion.

| Agent | Model | Domain |
|---|---|---|
| **Frontend Lead** | Sonnet | UI, components, styling, accessibility, browser behavior |
| **Backend Lead** | Sonnet | APIs, business logic, data layer, server-side |
| **Infra Lead** | Sonnet | Cloud services, CI/CD, deployment, containerization |
| **Data Lead** | Sonnet | Database design, migrations, pipelines, caching |
| *+ extensible* | — | Add any new domain lead by creating a markdown file |

### Layer 3 — Specialist Workers

Dispatched by domain leads. Focused, single-task execution with deep technology-specific knowledge.

Examples (not exhaustive — extensible by adding files):

- **Frontend:** React, Next.js, CSS/Tailwind, Vue, Svelte
- **Backend:** Node.js, Python, Go, Rust, Java
- **Infra:** AWS, Docker, Terraform, Kubernetes, GitHub Actions
- **Data:** Postgres, Redis, MongoDB, Prisma

Model: Sonnet for complex work, Haiku for simple/focused tasks.

### Utility Agents

Available at all levels. Workers call them directly without approval. Domain leads and coordinators can also use them.

| Agent | Model | Purpose | Constraint |
|---|---|---|---|
| **Researcher** | Sonnet | Docs lookup, web search, codebase exploration, library comparison | Read-only. Never writes code. |
| **Debugger** | Sonnet | Error diagnosis, stack trace analysis, root cause identification | Returns diagnosis, not fixes. |
| **Doc Writer** | Sonnet | README, API docs, inline documentation, changelog | Writes docs only, not application code. |

## Context & Coordination

### The Artifact Chain

Agents coordinate through files on disk. No message bus, no shared memory. Each phase reads upstream artifacts and writes its own.

```
Brainstormer  → docs/agents/spec.md
Planner       → docs/agents/plan.md        (reads spec.md)
Scaffolder    → project files               (reads spec.md, plan.md)
Impl Coord    → docs/agents/progress.md     (reads plan.md, updates continuously)
Reviewer      → docs/agents/review.md       (reads everything + the code)
```

### Three Tiers of Context

**Tier 1 — Universal (all agents read):**
- `CLAUDE.md` — project conventions, coding standards, tech stack, repo structure. Auto-loaded by Claude Code.
- `docs/agents/spec.md` — what we're building (source of truth for requirements)
- `docs/agents/plan.md` — how we're building it (source of truth for tasks)

**Tier 2 — Role-scoped (domain agents read):**
- `docs/agents/domains/<domain>.md` — domain-specific conventions for the current project. E.g., `frontend.md` contains component patterns, design tokens, styling approach. Backend agents don't read frontend conventions.

**Tier 3 — Task-scoped (passed at dispatch time):**
- The **task contract** (Coordinator → Domain Lead) or **work order** (Domain Lead → Specialist) passed in the Agent tool prompt. Contains only the relevant slice: assigned tasks, constraints, acceptance criteria, file paths.

### Dispatch Protocols

**Impl Coordinator → Domain Lead (Task Contract):**
```
- Which tasks from plan.md to implement (by ID)
- Relevant spec context (just their domain's section)
- Tech stack constraints and patterns to follow
- Path to progress.md for status updates
- List of available specialists
```

**Domain Lead → Specialist Worker (Work Order):**
```
- Single focused task description
- File paths to create or modify
- Patterns to follow (from existing code or scaffold)
- Acceptance criteria from the plan
- Domain conventions to respect
```

**Any Agent → Utility Agent (Self-Service):**
```
- Specific question or error to investigate
- Relevant context (file paths, error messages, what was tried)
- No approval needed — caller decides when to invoke
```

### Escalation Path

When a worker gets stuck and utility agents can't help:

1. Worker returns to **Domain Lead** with: what it tried, what failed, what it needs
2. Domain Lead attempts to resolve (may have broader context). If it can't →
3. Domain Lead escalates to **Impl Coordinator** with: the blocker, what was tried at both levels
4. Impl Coordinator attempts to resolve (may involve another domain). If it can't →
5. Impl Coordinator escalates to **Human** with: full context chain

Each level adds what it tried before escalating. The human never gets a raw "I'm stuck" — they get a complete picture.

## Tools & MCP Assignment

### MCP Servers

| MCP Server | Purpose | Assigned To |
|---|---|---|
| **Context7** | Current library docs, framework APIs, version-specific syntax | Domain Leads, Specialist Workers, Researcher, Scaffolder |
| **Exa** | Web search, code search, finding examples and patterns | Brainstormer, Researcher, Planner |
| **Chrome DevTools** | Browser interaction, screenshots, UI testing, Lighthouse audits | Frontend Lead, Frontend Specialists, Reviewer |

### Tools Per Agent

| Agent | Tools |
|---|---|
| Brainstormer | Read, Glob, Grep, Agent (Researcher) |
| Planner | Read, Glob, Grep, Agent (Researcher) |
| Scaffolder | Read, Write, Edit, Bash, Glob, Grep |
| Impl Coordinator | Read, Glob, Grep, Agent (Domain Leads), TaskCreate/Update |
| Domain Leads | Read, Write, Edit, Bash, Glob, Grep, Agent (Specialists + Utilities) |
| Specialist Workers | Read, Write, Edit, Bash, Glob, Grep, Agent (Utilities only) |
| Reviewer | Read, Glob, Grep, Bash (tests/linters only) |
| Researcher | Read, Glob, Grep, WebSearch, WebFetch |
| Debugger | Read, Glob, Grep, Bash |
| Doc Writer | Read, Write, Edit, Glob, Grep |

Key principle: agents only get the tools they need. Phase agents that don't write code don't get Write/Edit. The Reviewer can run tests but can't modify code. Utility agents have narrow, well-defined capabilities.

## End-to-End Workflow

### Greenfield Flow

```
1. Human invokes Brainstormer with idea
   → Brainstormer explores, asks questions, writes spec.md
   ⛔ GATE: Human reviews and approves spec

2. Human invokes Planner
   → Planner reads spec.md, decomposes into tasks, writes plan.md
   ⛔ GATE: Human reviews and approves plan

3. Human invokes Scaffolder
   → Scaffolder reads spec + plan, sets up project structure, config, tooling

4. Human invokes Impl Coordinator
   → Coordinator reads plan.md
   → Identifies which domains are needed
   → Dispatches domain leads in parallel (max 3-4 concurrent)
     → Domain leads break work into specialist tasks
     → Specialists do the coding, call utilities when stuck
     → Domain leads review specialist output
     → Coordinator tracks progress in progress.md
   → Unresolved blockers escalate through the chain to human

5. Impl Coordinator invokes Reviewer
   → Reviewer reads all artifacts + code
   → Runs cross-cutting checks (security, consistency, integration)
   → Writes review.md with findings per domain
   → Findings go back to relevant domain leads for fixes
   → Re-review cycle until clean

   ⛔ GATE: Human reviews final output
```

### Brownfield Flow

Same as greenfield except:
- Brainstormer explores the existing codebase before asking questions
- Planner accounts for existing architecture and patterns
- Step 3 (Scaffolder) is skipped or limited to new subsystems
- Specialists are instructed to follow existing patterns

### Smart Parallelism

The Impl Coordinator analyzes task dependencies from plan.md and:
- Dispatches independent domain leads concurrently (max 3-4)
- Sequences dependent tasks (e.g., "backend API must exist before frontend integration")
- Within a domain, the lead decides whether to run specialists in parallel or sequence
- Progress.md is updated as tasks complete, enabling the coordinator to unblock waiting tasks

## Plugin Structure

```
codingAgent/
├── .claude-plugin/
│   └── plugin.json                    # Plugin manifest
│
├── agents/                            # Agent definitions
│   ├── phase/
│   │   ├── brainstormer.md
│   │   ├── planner.md
│   │   ├── scaffolder.md
│   │   ├── impl-coordinator.md
│   │   └── reviewer.md
│   ├── leads/
│   │   ├── frontend-lead.md
│   │   ├── backend-lead.md
│   │   ├── infra-lead.md
│   │   └── data-lead.md
│   ├── specialists/
│   │   ├── frontend/
│   │   │   ├── react.md
│   │   │   ├── nextjs.md
│   │   │   └── css-tailwind.md
│   │   ├── backend/
│   │   │   ├── nodejs.md
│   │   │   ├── python.md
│   │   │   └── go.md
│   │   ├── infra/
│   │   │   ├── aws.md
│   │   │   ├── docker.md
│   │   │   └── terraform.md
│   │   └── data/
│   │       ├── postgres.md
│   │       └── redis.md
│   └── utility/
│       ├── researcher.md
│       ├── debugger.md
│       └── doc-writer.md
│
├── skills/                            # Reusable skills (SKILL.md per subdirectory)
│   ├── practices/
│   │   ├── tdd/SKILL.md              # Test-driven development process
│   │   ├── code-review/SKILL.md      # How to review code systematically
│   │   ├── error-handling/SKILL.md   # Error handling patterns
│   │   └── security-checklist/SKILL.md
│   ├── frontend/
│   │   ├── accessibility/SKILL.md
│   │   ├── react-patterns/SKILL.md
│   │   └── performance/SKILL.md
│   ├── backend/
│   │   ├── api-design/SKILL.md
│   │   └── auth-patterns/SKILL.md
│   ├── infra/
│   │   ├── docker-best-practices/SKILL.md
│   │   └── ci-cd-patterns/SKILL.md
│   └── general/
│       ├── git-workflow/SKILL.md
│       ├── debugging/SKILL.md
│       └── documentation/SKILL.md
│
├── .mcp.json                          # MCP server configurations
├── settings.json                      # Default settings
└── hooks/
    └── hooks.json                     # Lifecycle hooks
```

### Agent File Anatomy

Each agent is a markdown file with YAML frontmatter:

```markdown
---
name: frontend-lead
description: Frontend domain lead — manages UI specialists, reviews frontend output
model: sonnet
tools: Read, Write, Edit, Bash, Glob, Grep, Agent
---

# Frontend Lead

You are the Frontend Domain Lead for the current project.

## Context
- Read `CLAUDE.md` for project conventions
- Read `docs/agents/plan.md` for your assigned tasks
- Read `docs/agents/domains/frontend.md` for frontend conventions (if it exists)

## Responsibilities
1. Break your assigned tasks into specialist work orders
2. Dispatch specialists via Agent tool with focused work orders
3. Review each specialist's output before reporting completion
4. Call utility agents (researcher, debugger) when needed
5. Escalate unresolvable blockers to Impl Coordinator

## Available Specialists
- `agents/specialists/frontend/react.md`
- `agents/specialists/frontend/nextjs.md`
- `agents/specialists/frontend/css-tailwind.md`

## Review Checklist
- Components follow project patterns from CLAUDE.md
- Accessibility requirements met
- Responsive design verified
- No hardcoded values — use design tokens/variables
- Tests written and passing
```

### Skill File Anatomy

Each skill is a SKILL.md in a named subdirectory:

```markdown
---
name: tdd
description: Test-driven development — write failing test, make it pass, refactor. Use when implementing any feature or fixing bugs.
---

# Test-Driven Development

## Process
1. RED — Write a failing test that describes the expected behavior
2. GREEN — Write the minimum code to make the test pass
3. REFACTOR — Clean up while keeping tests green

## Rules
- Never write implementation code without a failing test first
- Each test should test one behavior
- Run the full test suite after each green phase
- If you find yourself writing code "just in case" — stop and write a test for it first
```

### Hooks

`hooks/hooks.json` defines lifecycle hooks for the plugin:
- **PostToolUse** — after a specialist completes, trigger domain lead review
- **Stop** — before session ends, update progress.md with current status
- **SubagentStart** — log which agent is being dispatched for observability

Specific hook implementations are defined during the implementation phase.

### Plugin Manifest

```json
{
  "name": "codingAgent",
  "version": "0.1.0",
  "description": "Multi-agent software development system with layered hierarchy",
  "author": {
    "name": "suraj-devloper"
  },
  "agents": "./agents/",
  "skills": "./skills/"
}
```

## Extensibility

Adding new capabilities requires only creating markdown files:

| Want to add... | Create... |
|---|---|
| New domain (e.g., Mobile) | `agents/leads/mobile-lead.md` + `agents/specialists/mobile/` folder |
| New specialist (e.g., Rust) | `agents/specialists/backend/rust.md` |
| New utility (e.g., Profiler) | `agents/utility/profiler.md` |
| New skill (e.g., GraphQL patterns) | `skills/backend/graphql/SKILL.md` |
| New domain conventions | `docs/agents/domains/mobile.md` (per project, not in plugin) |

No code changes. No configuration updates. The Impl Coordinator and Domain Leads discover available specialists from their agent definitions.

## Quality Model

### Dual Review

1. **Domain Lead review** — each domain lead reviews its specialists' output before reporting completion. Catches domain-specific issues: wrong patterns, missing edge cases, convention violations.

2. **Reviewer agent** — independent cross-cutting review after implementation. Catches issues that span domains:
   - Security vulnerabilities (OWASP top 10)
   - Inconsistencies between frontend and backend contracts
   - Missing error handling at integration boundaries
   - Test coverage gaps
   - Performance concerns

### Human Gates

Three mandatory approval points:
1. **Spec approval** — after Brainstormer produces spec.md
2. **Plan approval** — after Planner produces plan.md
3. **Final review** — after Reviewer completes cross-cutting review

Plus escalation-triggered involvement when the agent chain can't resolve a blocker.

## Design Decisions

**Why file-based coordination over message passing?**
Files persist across agent sessions, are human-readable, can be version-controlled, and don't require infrastructure. Claude Code agents naturally read and write files.

**Why phase agents invoked by human rather than auto-chained?**
Human gates between phases are natural. The human decides when to move forward, can edit artifacts between phases, and maintains control of the overall flow.

**Why domain leads between coordinator and specialists?**
Without leads, the coordinator would need to understand every domain deeply to dispatch and review. Leads provide domain expertise, reduce coordinator complexity, and enable domain-specific code review.

**Why Opus for phase agents and Sonnet for workers?**
Phase agents make high-stakes decisions (architecture, decomposition, quality judgment) where reasoning quality matters most. Workers execute well-scoped tasks with clear instructions where speed and cost efficiency matter more.

**Why build from scratch rather than wrapping existing plugins?**
Full control over agent behavior, no version coupling to external plugins, simpler dependency story, and the ability to design the coordination model exactly as needed. Existing plugins serve as inspiration for proven patterns.
