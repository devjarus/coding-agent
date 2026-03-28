# coding-agent — Claude Code Plugin

A multi-agent software development system distributed as a Claude Code plugin.

## Project Structure

```
codingAgent/
├── .claude-plugin/plugin.json     # Plugin manifest (name: coding-agent)
├── agents/                        # Agent definitions (auto-discovered by Claude Code)
│   ├── phase/                     # Lifecycle agents: brainstormer, planner, scaffolder, impl-coordinator, reviewer
│   ├── leads/                     # Domain leads: frontend-lead, backend-lead, infra-lead, data-lead
│   ├── specialists/               # Tech workers organized by domain/
│   │   ├── frontend/              # react, nextjs, css-tailwind
│   │   ├── backend/               # nodejs, python, go
│   │   ├── infra/                 # aws, docker, terraform
│   │   └── data/                  # postgres, redis
│   └── utility/                   # Shared helpers: researcher, debugger, doc-writer
├── skills/                        # Reusable skills (auto-discovered by Claude Code)
│   ├── practices/                 # tdd, code-review, error-handling, security-checklist
│   ├── frontend/                  # accessibility, react-patterns, performance
│   ├── backend/                   # api-design, auth-patterns
│   ├── infra/                     # docker-best-practices, ci-cd-patterns
│   └── general/                   # git-workflow, debugging, documentation
├── scripts/                       # Validation and testing scripts
│   ├── validate.sh                # Full validation suite (run after any change)
│   └── post-edit-validate.sh      # PostToolUse hook for auto-validation
├── hooks/hooks.json               # Plugin lifecycle hooks
├── .mcp.json                      # MCP server config (Context7, Exa)
├── settings.json                  # Plugin default settings
├── .gitignore                     # Ignores .coding-agent/ and .superpowers/
└── README.md                      # User-facing documentation
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

The PostToolUse hook (`scripts/post-edit-validate.sh`) runs automatically after every Write/Edit/MultiEdit on agent or skill files. It checks frontmatter and stale artifact path references inline.

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

## Adding New Agents

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
4. Update the impl-coordinator's documentation if needed
5. Validate and commit

### New Skill

1. Create `skills/<category>/<name>/SKILL.md` following the skill file format
2. Run `./scripts/validate.sh`
3. Commit with: `feat: add <name> skill`

### New Utility Agent

1. Create `agents/utility/<name>.md`
2. Utility agents should have narrow, clearly defined constraints (read-only, diagnosis-only, docs-only)
3. Validate and commit

## Key Design Decisions

- **File-based coordination** — agents share context via `.coding-agent/` artifacts, not message passing
- **Phase agents invoked by human** — human controls flow, approves at gates (spec, plan, final review)
- **Domain leads between coordinator and specialists** — provides domain expertise and code review layer
- **Plugin is self-contained** — no dependencies on other Claude Code plugins
- **MCP servers for external data** — Context7 for docs, Exa for web search, Playwright for testing, Chrome DevTools for performance/debugging

## MCP Servers

| Server | Package | Purpose | Which Agents |
|--------|---------|---------|--------------|
| **Context7** | `@upstash/context7-mcp` | Current library/framework docs | Domain leads, specialists, researcher, scaffolder |
| **Exa** | `exa-mcp-server` | Web search, code search | Brainstormer, researcher, planner |
| **Playwright** | `@playwright/mcp` | Browser testing, assertions, tracing | Frontend lead, frontend specialists, reviewer |
| **Chrome DevTools** | `chrome-devtools-mcp` | Lighthouse audits, performance profiling, network/memory inspection | Frontend lead, reviewer, debugger |

Playwright and Chrome DevTools serve different purposes:
- **Playwright** — testing flows, assertions (`browser_verify_*`), recording traces. Uses accessibility tree (token-efficient).
- **Chrome DevTools** — Lighthouse audits, performance traces, memory snapshots, network inspection. Deep browser internals.
