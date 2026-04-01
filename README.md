# coding-agent

A Claude Code plugin for building software end-to-end. 5 agents, 45 skills.

## How It Works

```
You: "Build me a task management API with a React dashboard"
  │
Orchestrator (main thread)
  ├── Brainstormer — asks questions, writes spec → you approve
  ├── Planner — creates feature slices → you approve
  ├── Scaffolds project (greenfield)
  ├── Domain Lead (backend) ─┐
  ├── Domain Lead (frontend) ─┼── implements code, writes tests
  ├── Domain Lead (data) ────┘
  ├── Reviewer — tests the app, reviews code
  └── Commits → done
```

One orchestrator, flat dispatch, max 1 level of subagents. File-based handoffs via `.coding-agent/`.

## Install

```bash
claude --plugin-dir /path/to/codingAgent
```

Or enable in a project (`.claude/settings.local.json`):
```json
{
  "agent": "coding-agent:orchestrator",
  "enabledPlugins": { "coding-agent@/path/to/codingAgent": true }
}
```

## Agents

| Agent | Role |
|-------|------|
| **orchestrator** | Main thread. Dispatches everything. Never writes code. |
| **brainstormer** | Expands ideas → spec. Asks structured questions. |
| **planner** | Spec → plan with vertical feature slices. |
| **domain-lead** | Implements code. Adapts by domain (frontend/backend/data/infra). |
| **reviewer** | Independent review. Tests running app. Finds what builders missed. |

## Skills (45)

Domain leads apply specialist skills based on their assigned domain:
- **Frontend:** react, nextjs, css-tailwind, testing, ui-design, generative-ui, assistant-chat-ui
- **Backend:** nodejs, python, go, typescript, agent-frameworks, llm-integration
- **Data:** postgres, redis
- **Infra:** aws, docker, terraform, deployment-patterns
- **Always applied:** tdd, code-review, security-checklist, observability

## Validation

```bash
./scripts/validate.sh && claude plugin validate .
```
