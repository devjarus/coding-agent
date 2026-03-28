# codingAgent

A Claude Code plugin that provides a layered hierarchy of AI agents for building software applications end-to-end.

## What It Does

Takes a project from idea to implementation through a structured agent pipeline:

1. **Brainstormer** explores your idea and produces a spec
2. **Planner** decomposes the spec into tasks with dependencies
3. **Scaffolder** sets up the project structure
4. **Impl Coordinator** dispatches domain leads to build in parallel
5. **Reviewer** performs cross-cutting quality review

## Agent Hierarchy

```
Human
  |
  v
Phase Agents (Opus) ---- Brainstormer → Planner → Scaffolder → Impl Coordinator → Reviewer
  |
  v
Domain Leads (Sonnet) -- Frontend Lead | Backend Lead | Infra Lead | Data Lead
  |
  v
Specialists (Sonnet) --- React, Next.js, CSS/Tailwind, Node.js, Python, Go,
                         AWS, Docker, Terraform, Postgres, Redis

Utility Agents (Sonnet) - Researcher | Debugger | Doc Writer
  (available at all levels)
```

## Installation

```bash
# From a marketplace
/plugin install codingAgent

# Or load locally for development
claude --plugin-dir /path/to/codingAgent
```

## Usage

```bash
# Start a new project
# The brainstormer will ask questions and produce a spec
claude "I want to build a task management API with real-time updates"

# After spec approval, plan the implementation
claude "Plan the implementation" # invokes the Planner

# Scaffold the project (greenfield)
claude "Scaffold the project" # invokes the Scaffolder

# Build it
claude "Start implementation" # invokes the Impl Coordinator
```

## MCP Servers

The plugin configures these MCP servers (must have API keys set up):

- **Context7** — library documentation lookup
- **Exa** — web search and code search

Chrome DevTools MCP is used by frontend agents when available in the environment.

## Extending

Add new capabilities by creating markdown files:

| Want to add... | Create... |
|---|---|
| New domain | `agents/leads/mobile-lead.md` + `agents/specialists/mobile/` |
| New specialist | `agents/specialists/backend/rust.md` |
| New utility | `agents/utility/profiler.md` |
| New skill | `skills/backend/graphql/SKILL.md` |

## Structure

```
codingAgent/
├── .claude-plugin/plugin.json     # Plugin manifest
├── agents/
│   ├── phase/                     # Brainstormer, Planner, Scaffolder, Impl Coordinator, Reviewer
│   ├── leads/                     # Frontend, Backend, Infra, Data leads
│   ├── specialists/               # Tech-specific workers (React, Node.js, AWS, etc.)
│   └── utility/                   # Researcher, Debugger, Doc Writer
├── skills/
│   ├── practices/                 # TDD, code review, error handling, security
│   ├── frontend/                  # Accessibility, React patterns, performance
│   ├── backend/                   # API design, auth patterns
│   ├── infra/                     # Docker, CI/CD
│   └── general/                   # Git workflow, debugging, documentation
├── .mcp.json                      # MCP server configuration
├── settings.json                  # Default settings
└── hooks/hooks.json               # Lifecycle hooks
```

## How It Works

Agents coordinate through **file-based artifacts** — no message bus needed:

- `.coding-agent/spec.md` — Brainstormer output (what to build)
- `.coding-agent/plan.md` — Planner output (how to build it)
- `.coding-agent/progress.md` — Impl Coordinator tracks status
- `.coding-agent/review.md` — Reviewer findings

Human approves at three gates: after spec, after plan, and after final review.
