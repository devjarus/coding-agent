# coding-agent — Claude Code Plugin

A multi-agent software development system distributed as a Claude Code plugin. 7 agents, 45 skills, 3 MCP servers. The **dispatcher** loops through phases by detecting state and dispatching one agent at a time. One **domain-lead** agent adapts to any domain via skill routing.

## Dispatch Architecture

The system uses a **dispatcher loop** pattern, not agent-to-agent chaining:

1. **Dispatcher dispatches one agent** (e.g., brainstormer)
2. **Agent does its work and returns** (writes artifact, returns to dispatcher)
3. **Dispatcher re-detects state** (checks `.coding-agent/` for new artifacts)
4. **Dispatcher dispatches next agent** (e.g., planner)
5. **Repeat** until pipeline reaches a human gate or completion

**Only two agents have the Agent tool:**
- **Dispatcher** — dispatches phase agents one at a time in sequence
- **Impl Coordinator** — dispatches multiple domain-leads in parallel (multiple Agent calls in one message)

**All other agents (brainstormer, planner, scaffolder, reviewer) do their work and RETURN.** They do not dispatch subagents. They do not chain to the next phase. They write their artifact and return control to the dispatcher.

**Max nesting depth: 2 levels** — dispatcher -> impl-coordinator -> domain-leads.

**Research is self-service.** Agents that need external information use their own MCP tools (Context7, Exa, DeepWiki) directly. No agent dispatches "Explore" or "researcher" subagents.

## Project Structure

```
codingAgent/
├── .claude-plugin/plugin.json        # Plugin manifest (name: coding-agent)
├── agents/                           # 7 agent definitions (auto-discovered by Claude Code)
│   ├── phase/                        # dispatcher, brainstormer, planner, scaffolder, impl-coordinator, reviewer
│   └── leads/                        # domain-lead (single agent, adapts by domain via skill routing)
├── skills/                           # 45 reusable skills (auto-discovered by Claude Code)
│   ├── practices/                    # tdd, code-review, error-handling, security-checklist,
│   │                                 # config-management, e2e-testing, integration-testing,
│   │                                 # release, project-detection, coordination-templates,
│   │                                 # shared-contracts, dependency-evaluation, observability,
│   │                                 # migration-safety
│   ├── frontend/                     # react-patterns, composition-patterns, accessibility, performance,
│   │                                 # ui-design, react-specialist, nextjs-specialist,
│   │                                 # css-tailwind-specialist, testing-specialist
│   ├── backend/                      # api-design, auth-patterns, nodejs-specialist,
│   │                                 # python-specialist, go-specialist, typescript-specialist
│   ├── data/                         # postgres-specialist, redis-specialist
│   ├── infra/                        # docker-best-practices, ci-cd-patterns, aws-specialist,
│   │                                 # docker-specialist, terraform-specialist
│   └── general/                      # git-workflow, debugging, documentation
├── scripts/                          # Validation and setup (3 scripts)
│   ├── validate.sh                   # Full validation suite (9 checks)
│   ├── post-edit-validate.sh         # PostToolUse hook for auto-validation
│   └── setup-external-skills.sh      # Install ecosystem skills
├── hooks/hooks.json                  # Plugin lifecycle hooks
├── .mcp.json                         # MCP server config (Context7, Playwright, Chrome DevTools)
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
| Domain lead | sonnet | Single agent — adapts by domain, applies specialist skills, writes code, self-reviews |

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

### Skills Inventory (45 total)

**Practices (15):** tdd, code-review, error-handling, security-checklist, config-management, e2e-testing, integration-testing, release, project-detection, coordination-templates, shared-contracts, dependency-evaluation, observability, migration-safety, ideation-council

**Frontend (11):** react-patterns, composition-patterns, accessibility, performance, ui-design, react-specialist, nextjs-specialist, css-tailwind-specialist, testing-specialist, generative-ui-specialist, assistant-chat-ui

**Backend (8):** api-design, auth-patterns, nodejs-specialist, python-specialist, go-specialist, typescript-specialist, agent-frameworks-specialist, llm-integration

**Data (2):** postgres-specialist, redis-specialist

**Infra (6):** docker-best-practices, ci-cd-patterns, aws-specialist, docker-specialist, terraform-specialist, deployment-patterns

**General (3):** git-workflow, debugging, documentation

## MCP Servers

| Server | Package | Purpose | Which Agents |
|--------|---------|---------|--------------|
| **Context7** | `@upstash/context7-mcp` | Current library/framework docs | Domain leads, scaffolder |
| **Exa** | (global config) | Web search, code search | Brainstormer, planner (available globally via user config) |
| **Playwright** | `@playwright/mcp` | Browser testing, assertions, tracing | Frontend lead, reviewer |
| **Chrome DevTools** | `chrome-devtools-mcp` | Lighthouse audits, performance profiling, network/memory inspection | Frontend lead, reviewer |

- **DeepWiki** — AI-powered documentation for GitHub repositories. Understanding dependencies and open-source patterns.
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
| react-best-practices | Frontend lead |
| composition-patterns | Frontend lead |
| web-design-guidelines | Reviewer (frontend pass), Frontend lead |
| shadcn | Frontend lead |
| deploy-to-vercel | Infra lead, Scaffolder |
| emulate | All domain leads (integration tests) |
| webapp-testing | Reviewer, Frontend lead |
| frontend-design | Frontend lead |

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
5. **Cross-references** — skills referenced in leads exist
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

### New Specialist Skill

1. Create `skills/<category>/<name>-specialist/SKILL.md` following the skill file format
2. Add the skill reference to the relevant domain lead's "Skills" section
3. Run `./scripts/validate.sh` — must pass
4. Commit with: `feat: add <name>-specialist skill`

### New Domain Lead

1. Create `agents/leads/<domain>-lead.md`
2. Create specialist skills for the domain in `skills/<domain>/`
3. Validate and commit

### New Skill

1. Create `skills/<category>/<name>/SKILL.md` following the skill file format
2. Include: frontmatter, "When to Apply", priority-ranked rules with ID prefixes, code examples
3. Keep under 500 lines
4. Run `./scripts/validate.sh`
5. Commit with: `feat: add <name> skill`

## Workflow Audit

After any structural change (adding/removing agents or skills, changing dispatch flow, modifying coordinator logic), run a workflow audit to verify the pipeline works end-to-end.

### How to Audit

Trace a concrete scenario through the full agent chain. Use two scenarios:

**Greenfield:** "Build me a [new app] with [frontend] and [backend]" in an empty directory.
**Brownfield:** "Add [feature] to this existing project" in a project with source code.

### What to Check at Each Agent

For every agent in the flow, verify:

1. **Reads** — Does it read the correct `.coding-agent/` paths? No stale `docs/` references?
2. **Writes** — Does it produce the expected output file(s)?
3. **Tools** — Does it have the right tools? Only dispatcher and impl-coordinator have Agent tool. Others must not dispatch subagents.
4. **Returns** — Does it write its artifact and return? No chaining to the next phase.
5. **References** — No references to agents that don't exist (deleted specialists, utility agents)?
6. **Skills** — Are referenced skills present in `skills/`?
7. **Brownfield** — Does it handle existing code (read before write, edit over create, respect patterns)?
8. **Research** — Does it use its own MCP tools (Context7, Exa, DeepWiki) for research, not dispatch subagents?

### Audit Checklist

```
[ ] Dispatcher loops correctly: dispatch -> agent returns -> re-detect state -> dispatch next
[ ] Dispatcher routes correctly for all 7 states in the routing table
[ ] Brainstormer writes .coding-agent/spec.md and RETURNS (no subagent dispatch)
[ ] Planner writes .coding-agent/plan.md and RETURNS (no subagent dispatch)
[ ] Scaffolder reads .coding-agent/spec.md + plan.md (not docs/) → writes scaffold-log.md and RETURNS
[ ] Impl Coordinator dispatches domain-leads in parallel (multiple Agent calls in one message)
[ ] Task contracts include: assigned tasks, spec context, constraints, brownfield directives
[ ] Domain leads apply specialist skills (not dispatch specialist agents)
[ ] Domain leads have Edit-over-Write rule for brownfield
[ ] No agent references researcher, debugger, or doc-writer agents (removed — use skills/MCP instead)
[ ] Only dispatcher and impl-coordinator have the Agent tool
[ ] Max nesting is 2 levels (dispatcher → coordinator → domain-leads)
[ ] Reviewer produces .coding-agent/review.md and RETURNS
[ ] Impl Coordinator handles verification, review dispatch, and commit internally
[ ] validate.sh passes
[ ] claude plugin validate . passes
```

### When to Audit

- After adding or removing any agent
- After adding specialist skills that leads reference
- After changing dispatch flow or coordinator logic
- After modifying the dispatcher's routing table
- Before major commits that touch multiple agents

## Key Design Decisions

- **Dispatcher loop, not agent chaining** — the dispatcher is the only orchestrator at the top level. It dispatches one phase agent, that agent returns, dispatcher re-detects state, dispatches next. No agent chains to the next phase. This keeps control centralized and state transitions explicit.
- **Two-level nesting maximum** — dispatcher -> impl-coordinator -> domain-leads. No deeper. The coordinator is the only agent that dispatches multiple subagents in parallel.
- **Agents return, not chain** — brainstormer, planner, scaffolder, and reviewer write their artifact and return. They never dispatch the next agent. The dispatcher handles all phase transitions.
- **Self-service research** — agents use their own MCP tools (Context7, Exa, DeepWiki) for research. No "Explore" or "researcher" subagent dispatches. This eliminates unnecessary nesting.
- **File-based coordination** — agents share context via `.coding-agent/` artifacts, not message passing. Each dispatch is a context reset — leads start fresh and read only what they need.
- **Prompt expansion** — humans underspecify. The brainstormer's job is to expand "build me a chat app" into 100+ lines of concrete, testable requirements. Be ambitious about scope.
- **Generator-Evaluator separation** — the reviewer is intentionally independent from the builder. Agents skew positive when grading their own work. Separation prevents rubber-stamping.
- **Spec over implementation details** — specs focus on what and why, not how. Over-specifying implementation upstream causes cascading errors. Let leads figure out the how.
- **Single domain-lead agent** — one agent adapts to any domain via a skill routing table
- **Every harness component encodes an assumption** — about what the model can't do on its own. Stress-test assumptions as models improve. Components that become unnecessary should be removed.
- **Plugin is self-contained** — no dependencies on other Claude Code plugins
- **Validation on every change** — PostToolUse hook + validate.sh + claude plugin validate
