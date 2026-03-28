# coding-agent

A Claude Code plugin that provides a layered hierarchy of AI agents for building software applications end-to-end. Supports greenfield and brownfield projects.

## What It Does

Takes a project from idea to shipped code through a structured agent pipeline:

1. **Brainstormer** — explores your idea, asks clarifying questions, produces a spec
2. **Planner** — decomposes the spec into tasks with dependencies and domain assignments
3. **Scaffolder** — sets up project structure, config, tooling (greenfield) or analyzes existing code (brownfield)
4. **Impl Coordinator** — dispatches domain leads in parallel, tracks progress, manages dependencies
5. **Reviewer** — independent cross-cutting review: security, integration, quality, browser validation

## Agent Hierarchy

```
Human (approves at gates: spec, plan, final review)
  │
  ▼
Phase Agents (Opus) ─── Brainstormer → Planner → Scaffolder → Impl Coordinator → Reviewer
  │
  ▼
Domain Leads (Sonnet) ─ Frontend Lead │ Backend Lead │ Infra Lead │ Data Lead
  │
  ▼
Specialists (Sonnet) ── React, Next.js, CSS/Tailwind, Node.js, Python, Go,
                        AWS, Docker, Terraform, Postgres, Redis

Utility Agents (Sonnet) ─ Researcher │ Debugger │ Doc Writer
  (available at all levels — workers call directly, no approval needed)
```

## Installation

```bash
# Load locally for development
claude --plugin-dir /path/to/codingAgent

# Or from a marketplace
/plugin install coding-agent

# Install recommended external skills
./scripts/setup-external-skills.sh
```

### Validate the Plugin

```bash
# Custom validation (structure, frontmatter, cross-refs, model tiers)
./scripts/validate.sh

# Official Claude Code validator
claude plugin validate /path/to/codingAgent
```

## Usage

```bash
# Start a new project — brainstormer asks questions, produces spec
claude "I want to build a task management API with real-time updates"

# After spec approval, create the plan
claude "Plan the implementation"

# Scaffold the project (greenfield)
claude "Scaffold the project"

# Build it — coordinator dispatches domain leads in parallel
claude "Start implementation"
```

## Agents (23)

### Phase Agents (5) — Lifecycle Orchestration
| Agent | Model | Purpose |
|-------|-------|---------|
| brainstormer | opus | Idea → spec through collaborative dialogue |
| planner | opus | Spec → task plan with dependencies and domain assignments |
| scaffolder | sonnet | Project setup, config, tooling, CLAUDE.md creation |
| impl-coordinator | opus | Dispatches domain leads, manages parallelism (max 3-4), tracks progress |
| reviewer | opus | Cross-cutting review: security, integration, quality, browser validation |

### Domain Leads (4) — Domain Expertise & Review
| Agent | Model | Domain | Specialists |
|-------|-------|--------|-------------|
| frontend-lead | sonnet | UI, components, styling, a11y | react, nextjs, css-tailwind |
| backend-lead | sonnet | APIs, business logic, data layer | nodejs, python, go |
| infra-lead | sonnet | Cloud, CI/CD, containers | aws, docker, terraform |
| data-lead | sonnet | Database, migrations, caching | postgres, redis |

### Specialists (11) — Focused Implementation
| Domain | Agents |
|--------|--------|
| Frontend | react, nextjs, css-tailwind |
| Backend | nodejs, python, go |
| Infra | aws, docker, terraform |
| Data | postgres, redis |

### Utility Agents (3) — Self-Service Support
| Agent | Purpose | Constraint |
|-------|---------|------------|
| researcher | Docs lookup, web search, codebase exploration | Read-only, never writes code |
| debugger | Error diagnosis, root cause analysis | Returns diagnosis, not fixes |
| doc-writer | README, API docs, changelogs | Writes docs only, never app code |

## Skills (20)

### Practices (8)
| Skill | What It Covers |
|-------|---------------|
| tdd | RED-GREEN-REFACTOR cycle, test design, when to break the rules |
| code-review | 6-section checklist: correctness, security, performance, conventions, tests, maintainability |
| error-handling | Patterns at boundaries, business logic, infrastructure. Anti-patterns. |
| security-checklist | OWASP top 10, auth, data protection, API security, dependencies |
| config-management | Single config module, startup validation (Zod/Pydantic/envconfig), env strategy |
| e2e-testing | Playwright MCP + Chrome DevTools MCP patterns for browser testing |
| integration-testing | API emulation, contract testing, service containers, network failure testing |
| release | Automated release — version bump, changelog, tag, push from conventional commits |
| project-detection | 7-step tech stack detection before starting work |

### Frontend (4)
| Skill | What It Covers |
|-------|---------------|
| react-patterns | 40 priority-ranked rules (RBP-01→RBP-40): waterfalls, bundles, server perf, hooks, re-renders |
| composition-patterns | 13 rules (COMP-01→COMP-13): compound components, variants, state isolation, React 19 |
| accessibility | WCAG 2.1 AA: perceivable, operable, understandable, robust + common UI patterns |
| performance | Core Web Vitals, loading, rendering, bundle size, perceived performance |

### Backend (2)
| Skill | What It Covers |
|-------|---------------|
| api-design | REST conventions: URLs, methods, status codes, pagination, versioning, error format |
| auth-patterns | Session, JWT, OAuth 2.0, RBAC, resource-based auth, security requirements |

### Infra (2)
| Skill | What It Covers |
|-------|---------------|
| docker-best-practices | 20 rules (DOC-01→DOC-20), multi-stage templates (Node/Python), production compose, BuildKit |
| ci-cd-patterns | Pipeline structure, testing in CI, deployment strategies, secrets management |

### General (3)
| Skill | What It Covers |
|-------|---------------|
| git-workflow | Branching, conventional commits, PR conventions |
| debugging | 4-step systematic process: reproduce, understand, hypothesize, verify |
| documentation | README structure, writing style, code comments, API docs |

## MCP Servers (4)

| Server | Package | Purpose | Agents |
|--------|---------|---------|--------|
| Context7 | `@upstash/context7-mcp` | Library/framework docs | Domain leads, specialists, researcher, scaffolder |
| Exa | `exa-mcp-server` | Web search, code search | Brainstormer, researcher, planner |
| Playwright | `@playwright/mcp` | Browser testing, assertions, tracing | Frontend lead, frontend specialists, reviewer |
| Chrome DevTools | `chrome-devtools-mcp` | Lighthouse, performance, network, memory | Frontend lead, reviewer, debugger |

## External Skills (Ecosystem)

The plugin is self-contained but designed to complement these ecosystem skills:

```bash
npx skills add vercel-labs/agent-skills --all -g -y -a claude-code  # React, web design, deploy
npx skills add shadcn/ui -g -y -a claude-code                       # shadcn/ui components
npx skills add vercel-labs/emulate -g -y -a claude-code              # API emulators for testing
npx skills add anthropics/skills -g -y -a claude-code                # Playwright testing, frontend design
```

Or run `./scripts/setup-external-skills.sh` to install all at once.

## How It Works

### Coordination

Agents coordinate through **file-based artifacts** in `.coding-agent/` (gitignored):

| File | Produced By | Purpose |
|------|------------|---------|
| `spec.md` | Brainstormer | Requirements specification |
| `plan.md` | Planner | Tasks, dependencies, domain assignments |
| `progress.md` | Impl Coordinator | Task status, blockers, decisions |
| `review.md` | Reviewer | Findings by severity and domain |
| `scaffold-log.md` | Scaffolder | What was set up and why |
| `domains/*.md` | Scaffolder | Per-domain conventions for the target project |

### Human Gates

Three mandatory approval points:
1. After Brainstormer produces spec
2. After Planner produces plan
3. After Reviewer completes review

Plus escalation when the agent chain can't resolve a blocker.

### Escalation Path

Worker → Domain Lead → Impl Coordinator → Human. Each level adds what was tried before escalating.

## Extending

Add new capabilities by creating markdown files — no code changes needed:

| Want to add... | Create... |
|---|---|
| New domain (e.g., Mobile) | `agents/leads/mobile-lead.md` + `agents/specialists/mobile/` |
| New specialist (e.g., Rust) | `agents/specialists/backend/rust.md` |
| New utility (e.g., Profiler) | `agents/utility/profiler.md` |
| New skill (e.g., GraphQL) | `skills/backend/graphql/SKILL.md` |

## Validation & Testing

```bash
# Full validation suite (9 checks)
./scripts/validate.sh

# Official plugin validator
claude plugin validate .

# Load and test locally
claude --plugin-dir .

# Hot-reload during development
/reload-plugins

# Debug plugin loading
claude --debug --plugin-dir .

# Check for errors
/doctor
```

## Project Structure

```
codingAgent/
├── .claude-plugin/plugin.json        # Plugin manifest (name: coding-agent)
├── agents/                           # 23 agent definitions
│   ├── phase/                        # brainstormer, planner, scaffolder, impl-coordinator, reviewer
│   ├── leads/                        # frontend-lead, backend-lead, infra-lead, data-lead
│   ├── specialists/                  # frontend/ backend/ infra/ data/ (11 total)
│   └── utility/                      # researcher, debugger, doc-writer
├── skills/                           # 20 skill definitions
│   ├── practices/                    # tdd, code-review, error-handling, security-checklist,
│   │                                 # config-management, e2e-testing, integration-testing,
│   │                                 # release, project-detection
│   ├── frontend/                     # react-patterns, composition-patterns, accessibility, performance
│   ├── backend/                      # api-design, auth-patterns
│   ├── infra/                        # docker-best-practices, ci-cd-patterns
│   └── general/                      # git-workflow, debugging, documentation
├── scripts/                          # Validation & setup
│   ├── validate.sh                   # Full validation suite
│   ├── post-edit-validate.sh         # Auto-validation hook
│   └── setup-external-skills.sh      # Install ecosystem skills
├── hooks/hooks.json                  # PostToolUse auto-validation, SubagentStart logging
├── .mcp.json                         # Context7, Exa, Playwright, Chrome DevTools
├── settings.json                     # Default agent: impl-coordinator
├── .gitignore                        # .coding-agent/, .superpowers/
├── CLAUDE.md                         # Project conventions (this file)
└── README.md                         # User-facing documentation
```
