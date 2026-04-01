# coding-agent — Claude Code Plugin

A multi-agent software development system distributed as a Claude Code plugin. 5 agents, 45 skills, 4 MCP servers. The **orchestrator** is the main thread — it dispatches subagents (brainstormer, planner, domain-lead, reviewer) one level deep to build software end-to-end.

## Dispatch Architecture

The system uses a **single orchestrator** pattern:

1. **Orchestrator reads state** (checks `.coding-agent/` for artifacts)
2. **Orchestrator dispatches one subagent** (e.g., brainstormer)
3. **Subagent does its work and returns** (writes artifact, returns to orchestrator)
4. **Orchestrator reads the artifact, dispatches next subagent**
5. **Repeat** until pipeline reaches completion

**Only the orchestrator has the Agent tool.** All other agents do their work and return. Max nesting depth: 1 level.

**Research is self-service.** Agents use MCP tools (Context7, Exa, DeepWiki) from `.mcp.json` directly.

## Project Structure

```
codingAgent/
├── .claude-plugin/plugin.json        # Plugin manifest
├── agents/                           # 5 agents (flat, no subdirectories)
│   ├── orchestrator.md               # Main thread — dispatches all subagents
│   ├── brainstormer.md               # Expands ideas into specs
│   ├── planner.md                    # Decomposes specs into plans
│   ├── domain-lead.md                # Implements code (adapts by domain)
│   └── reviewer.md                   # Independent code review
├── skills/                           # 45 reusable skills
│   ├── practices/                    # tdd, code-review, security-checklist, etc.
│   ├── frontend/                     # react-specialist, ui-design, etc.
│   ├── backend/                      # nodejs-specialist, llm-integration, etc.
│   ├── data/                         # postgres-specialist, redis-specialist
│   ├── infra/                        # docker-specialist, deployment-patterns, etc.
│   └── general/                      # git-workflow, debugging, documentation
├── scripts/validate.sh               # Validation suite
├── hooks/hooks.json                  # SubagentStart logging, PostToolUse validation
├── .mcp.json                         # MCP servers (Context7, Playwright, Chrome DevTools, DeepWiki)
├── settings.json                     # Default agent: orchestrator
└── README.md
```

## Runtime Artifacts

All coordination files are written to `.coding-agent/` in the **target project**:

| File | Producer | Purpose |
|------|----------|---------|
| `spec.md` | Brainstormer | Requirements specification |
| `plan.md` | Planner | Feature slices, tasks, dependencies |
| `progress.md` | Orchestrator | Task status tracking |
| `review.md` | Reviewer | Findings by severity |
| `scaffold-log.md` | Orchestrator | What was scaffolded (greenfield) |
| `agent-log.txt` | Hook | Timestamped agent dispatch log |

## Agent Summary

| Agent | Model | Tools | Role |
|-------|-------|-------|------|
| orchestrator | opus | Read, Write, Edit, Bash, Glob, Grep, **Agent**, AskUserQuestion | Main thread. Dispatches all subagents. Tracks progress. |
| brainstormer | opus | Read, Write, Bash, Glob, Grep, AskUserQuestion | Asks questions, researches, writes spec.md. Returns. |
| planner | opus | Read, Write, Bash, Glob, Grep | Writes plan.md with vertical slices. Returns. |
| domain-lead | sonnet | Read, Write, Edit, Bash, Glob, Grep | Implements code by domain. Applies specialist skills. Returns. |
| reviewer | opus | Read, Write, Glob, Grep, Bash | Reviews code, runs tests, writes review.md. Returns. |

**Only the orchestrator has the Agent tool.** No other agent dispatches subagents.

## Plugin Constraints

Plugin agents **cannot** use these frontmatter fields (silently ignored):
- `mcpServers` — use `.mcp.json` instead (session-level, available to all agents)
- `hooks` — use `hooks/hooks.json` instead
- `permissionMode` — inherits from session

## MCP Servers

All defined in `.mcp.json`, available to every agent at session level:

| Server | Purpose |
|--------|---------|
| Context7 | Library/framework documentation |
| Playwright | Browser testing, screenshots |
| Chrome DevTools | Lighthouse, performance, network |
| DeepWiki | GitHub repo documentation |

Exa (web search) is available from user's global config.

## Key Design Decisions

- **Single orchestrator, flat dispatch** — one agent dispatches everything, max 1 level deep. No nesting.
- **Prompt expansion** — brainstormer expands "build me a chat app" into 100+ lines of concrete requirements.
- **Vertical feature slices** — planner creates foundation wave + feature slices, each testable end-to-end.
- **Generator-Evaluator separation** — reviewer is independent from builder. Prevents self-evaluation bias.
- **File-based handoffs** — agents coordinate via `.coding-agent/` artifacts. Simple. No message passing.
- **Spec over implementation details** — specs focus on what/why. Over-specifying how causes cascading errors.
- **Every harness component encodes an assumption** — stress-test as models improve. Remove what becomes unnecessary.

## Development

```bash
./scripts/validate.sh         # Structure, frontmatter, cross-refs
claude plugin validate .       # Official validator
claude --plugin-dir .          # Load locally
```
