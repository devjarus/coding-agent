# coding-agent — Claude Code Plugin

A multi-agent software development system distributed as a Claude Code plugin. 26 agents, 25 skills, 4 MCP servers. The **dispatcher** agent is configured as the default entry point in `settings.json` — it reads project state and auto-routes to the correct phase.

## Project Structure

```
codingAgent/
├── .claude-plugin/plugin.json        # Plugin manifest (name: coding-agent)
├── agents/                           # 26 agent definitions (auto-discovered by Claude Code)
│   ├── phase/                        # dispatcher, brainstormer, planner, scaffolder, impl-coordinator, reviewer
│   ├── leads/                        # frontend-lead, backend-lead, infra-lead, data-lead
│   ├── specialists/                  # Tech workers organized by domain/ (13 total)
│   │   ├── frontend/                 # react, nextjs, css-tailwind, testing
│   │   ├── backend/                  # nodejs, python, go, typescript
│   │   ├── infra/                    # aws, docker, terraform
│   │   └── data/                     # postgres, redis
│   └── utility/                      # researcher, debugger, doc-writer
├── skills/                           # 25 reusable skills (auto-discovered by Claude Code)
│   ├── practices/                    # tdd, code-review, error-handling, security-checklist,
│   │                                 # config-management, e2e-testing, integration-testing,
│   │                                 # release, project-detection, parallel-git-strategy,
│   │                                 # shared-contracts, dependency-evaluation, observability,
│   │                                 # migration-safety
│   ├── frontend/                     # react-patterns, composition-patterns, accessibility, performance
│   ├── backend/                      # api-design, auth-patterns
│   ├── infra/                        # docker-best-practices, ci-cd-patterns
│   └── general/                      # git-workflow, debugging, documentation
├── scripts/                          # Validation and setup (3 scripts)
│   ├── validate.sh                   # Full validation suite (9 checks)
│   ├── post-edit-validate.sh         # PostToolUse hook for auto-validation
│   └── setup-external-skills.sh      # Install ecosystem skills
├── hooks/hooks.json                  # Plugin lifecycle hooks
├── .mcp.json                         # MCP server config (Context7, Exa, Playwright, Chrome DevTools)
├── settings.json                     # Default agent: dispatcher (auto-routes by project state)
├── .gitignore                        # Ignores .coding-agent/ and .superpowers/
├── CLAUDE.md                         # Project conventions (this file)
└── README.md                         # User-facing documentation
```

## Runtime Artifacts

All coordination files are written to `.coding-agent/` in the **target project** (not this repo). This directory is gitignored.

```
.coding-agent/
├── spec.md            # Brainstormer output — requirements specification
├── plan.md            # Planner output — implementation tasks with dependencies
├── progress.md        # Impl Coordinator — tracks task status and blockers
├── review.md          # Reviewer output — findings by severity and domain
├── scaffold-log.md    # Scaffolder output — what was set up and why
├── agent-log.txt      # Hook output — timestamped agent dispatch log
└── domains/           # Domain conventions for the target project
    ├── frontend.md
    ├── backend.md
    └── ...
```

**Never use `docs/agents/` for artifact paths.** Always use `.coding-agent/`.

## Agent File Format

Every agent is a markdown file with YAML frontmatter:

```markdown
---
name: kebab-case-name
description: One-line description of what the agent does and when to use it
model: opus | sonnet | haiku | inherit
tools: Read, Write, Edit, Bash, Glob, Grep
---

# Agent Name

System prompt content...
```

Required frontmatter fields: `name`, `description`, `model`
Optional: `tools` (omit to inherit defaults), `color`

### Model Tier Conventions

| Role | Model | Rationale |
|------|-------|-----------|
| Dispatcher | sonnet | Routing logic only — reads state, dispatches to phase, no heavyweight reasoning needed |
| Phase agents (brainstormer, planner, impl-coordinator, reviewer) | opus | High-stakes decisions — architecture, decomposition, quality judgment |
| Scaffolder | sonnet | Execution-focused, follows the plan |
| Domain leads | sonnet | Domain expertise, code review, specialist dispatch |
| Specialist workers | sonnet | Focused task execution with clear instructions |
| Utility agents | sonnet | Narrow, well-defined capabilities |

## Skill File Format

Each skill is a `SKILL.md` inside a named subdirectory:

```markdown
---
name: kebab-case-name
description: What this skill teaches and when to use it.
---

# Skill Title

Content...
```

Required frontmatter fields: `name`, `description`

### Skill Design Conventions

- **SKILL.md stays under 500 lines** — use progressive disclosure (link to rules/ subdirectory for detailed content)
- **Priority-ranked rules** with ID prefixes (e.g., DOC-01, CFG-01, RBP-01) — CRITICAL > HIGH > MEDIUM > LOW
- **"When to Apply" section** — explicit trigger conditions so agents know when to activate
- **Code examples** — concrete, not abstract. Show the pattern, not just describe it.
- **Anti-patterns section** — what to avoid and why

### Skills Inventory (25 total)

**Practices (14):** tdd, code-review, error-handling, security-checklist, config-management, e2e-testing, integration-testing, release, project-detection, parallel-git-strategy, shared-contracts, dependency-evaluation, observability, migration-safety

**Frontend (4):** react-patterns, composition-patterns, accessibility, performance

**Backend (2):** api-design, auth-patterns

**Infra (2):** docker-best-practices, ci-cd-patterns

**General (3):** git-workflow, debugging, documentation

## MCP Servers

| Server | Package | Purpose | Which Agents |
|--------|---------|---------|--------------|
| **Context7** | `@upstash/context7-mcp` | Current library/framework docs | Domain leads, specialists, researcher, scaffolder |
| **Exa** | `exa-mcp-server` | Web search, code search | Brainstormer, researcher, planner |
| **Playwright** | `@playwright/mcp` | Browser testing, assertions, tracing | Frontend lead, frontend specialists, reviewer |
| **Chrome DevTools** | `chrome-devtools-mcp` | Lighthouse audits, performance profiling, network/memory inspection | Frontend lead, reviewer, debugger |

- **Playwright** — testing flows, assertions (`browser_verify_*`), recording traces. Uses accessibility tree (token-efficient).
- **Chrome DevTools** — Lighthouse audits, performance traces, memory snapshots, network inspection. Deep browser internals.

## External Skills (Ecosystem)

Our plugin provides orchestration agents and custom skills. External skills from the skills.sh ecosystem provide additional domain expertise and are installed alongside.

### Setup

```bash
# Install all recommended external skills (run once)
./scripts/setup-external-skills.sh
```

Or install individually:

```bash
npx skills add vercel-labs/agent-skills --all -g -y -a claude-code
npx skills add shadcn/ui -g -y -a claude-code
npx skills add vercel-labs/emulate -g -y -a claude-code
npx skills add anthropics/skills -g -y -a claude-code
```

### What Gets Installed

| Source | Skills | What They Do |
|--------|--------|--------------|
| **vercel-labs/agent-skills** | react-best-practices, composition-patterns, web-design-guidelines, deploy-to-vercel | React/Next.js performance rules, component architecture, UI accessibility audit, Vercel deployment |
| **shadcn/ui** | shadcn | Component library management — detects project config, adds/searches components, enforces composition patterns, theming |
| **vercel-labs/emulate** | emulate, github, google, vercel | Local stateful API emulators for integration testing without network access |
| **anthropics/skills** | claude-api, mcp-builder, webapp-testing, frontend-design | Claude API patterns, MCP server building, Playwright testing, production UI design |

### How They Coexist

- **Plugin skills** (bundled): loaded from the plugin cache
- **External skills** (installed): loaded from `~/.claude/skills/`
- Both are available simultaneously — agents use whichever matches the context

### Which Agents Benefit

| External Skill | Agents That Use It |
|---|---|
| react-best-practices | React specialist, Frontend lead (review) |
| composition-patterns | React specialist, Frontend lead |
| web-design-guidelines | Reviewer (frontend pass), Frontend lead |
| shadcn | React specialist, CSS/Tailwind specialist |
| deploy-to-vercel | Infra lead, Scaffolder |
| emulate | All specialists (integration tests), Debugger |
| webapp-testing | Reviewer, Frontend lead |
| frontend-design | Frontend specialists |

## Development Workflow

### After Any Change

1. Run the validation suite:
   ```bash
   ./scripts/validate.sh
   ```

2. Run the official Claude Code validator:
   ```bash
   claude plugin validate .
   ```

3. Both must pass before committing.

### Auto-Validation

The PostToolUse hook (`scripts/post-edit-validate.sh`) runs automatically after every Write/Edit/MultiEdit on agent or skill files. Checks frontmatter and stale artifact path references.

### Testing Locally

```bash
# Load the plugin in a Claude Code session
claude --plugin-dir /path/to/codingAgent

# Hot-reload after changes (in-session)
/reload-plugins

# Check for loading errors (in-session)
/doctor

# Verbose debug output
claude --debug --plugin-dir /path/to/codingAgent

# View hook configuration (in-session)
/hooks
```

### What validate.sh Checks

1. **Structure** — required directories and files exist
2. **JSON** — all JSON config files parse correctly
3. **Agent frontmatter** — name, description, model present and valid
4. **Skill frontmatter** — name, description present
5. **Cross-references** — specialists referenced in leads actually exist, utility agents exist
6. **Artifact paths** — no stale `docs/agents/` references, all use `.coding-agent/`
7. **Model tiers** — correct model assignments per role
8. **Content quality** — no stub files (agents < 20 lines, skills < 10 lines)
9. **Inventory** — counts of all agents and skills

## Git Conventions

### Commit Messages

Conventional commits format:
```
type: short description

Optional body explaining why.
```

Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`

### What Gets Committed

- Agent definitions (`agents/`)
- Skill definitions (`skills/`)
- Plugin config (`.claude-plugin/`, `settings.json`, `.mcp.json`, `hooks/`)
- Scripts (`scripts/`)
- Documentation (`README.md`, `CLAUDE.md`)

### What Does NOT Get Committed

- `.coding-agent/` — runtime artifacts from target projects
- `.superpowers/` — brainstorming session files
- `node_modules/`, `.env`, or any dependency/secret files

## Adding New Components

### New Specialist

1. Create `agents/specialists/<domain>/<name>.md` following the agent file format
2. Add the specialist reference to the relevant domain lead's "Available Specialists" section
3. Run `./scripts/validate.sh` — must pass
4. Run `claude plugin validate .` — must pass
5. Commit with: `feat: add <name> specialist agent`

### New Domain Lead

1. Create `agents/leads/<domain>-lead.md`
2. Create the `agents/specialists/<domain>/` directory
3. Add at least one specialist for the domain
4. Validate and commit

### New Skill

1. Create `skills/<category>/<name>/SKILL.md` following the skill file format
2. Include: frontmatter, "When to Apply", priority-ranked rules with ID prefixes, code examples
3. Keep under 500 lines
4. Run `./scripts/validate.sh`
5. Commit with: `feat: add <name> skill`

### New Utility Agent

1. Create `agents/utility/<name>.md`
2. Utility agents must have narrow, clearly defined constraints (read-only, diagnosis-only, docs-only)
3. Validate and commit

## Key Design Decisions

- **Dispatcher as default entry point** — configured in `settings.json`; reads `.coding-agent/` state and routes to the right phase without human needing to know where they are
- **File-based coordination** — agents share context via `.coding-agent/` artifacts, not message passing
- **Phase agents invoked by human** — human controls flow, approves at gates (spec, plan, final review)
- **Domain leads between coordinator and specialists** — provides domain expertise and code review layer
- **Parallel-git-strategy** — branch-per-domain pattern allows concurrent agent work without conflicts; coordinator assigns branches, leads own their slice, coordinator merges at the end
- **Shared contracts** — `shared-contracts` skill enforces a single source of truth for types/interfaces consumed by both frontend and backend, preventing drift
- **Plugin is self-contained** — no dependencies on other Claude Code plugins
- **External skills complement, don't replace** — ecosystem skills installed alongside, not bundled
- **Priority-ranked rules** in skills — CRITICAL > HIGH > MEDIUM > LOW with ID prefixes for cross-referencing
- **Validation on every change** — PostToolUse hook + validate.sh + claude plugin validate
