# coding-agent

A Claude Code plugin for building software end-to-end. 4 agents, 45 skills.

```
You: "Build me a task management API"
  │
Orchestrator
  ├── Architect — asks questions, writes spec (you approve), writes plan with eval criteria (you approve)
  ├── Implementor — writes code + tests per domain (frontend/backend/data/infra)
  ├── Evaluator — independent review against spec + eval criteria
  └── Commits → done
```

## Install

```bash
claude --plugin-dir /path/to/codingAgent
```

## Agents

| Agent | Role |
|-------|------|
| **Orchestrator** | Dispatches agents, validates artifacts, tracks progress. Never writes code. |
| **Architect** | Expands ideas → spec → plan with evaluation criteria. Two human approval gates. |
| **Implementor** | Writes code by domain. Applies specialist skills (react, nodejs, postgres, etc.). Tests first. |
| **Evaluator** | Independent review. Tests against plan's eval criteria. Finds what builders missed. |

## How Artifacts Flow

```
Architect writes spec.md → Human approves → Architect writes plan.md → Human approves
  → Implementor reads plan, writes code → Evaluator reads spec + plan, reviews code
  → PASS: commit | FAIL: Implementor fixes → Evaluator re-reviews
```

All artifacts in `.coding-agent/`. Orchestrator validates each before advancing.

## Skills (45)

Implementor adapts by domain:
- **Frontend:** react, nextjs, css-tailwind, testing, ui-design, generative-ui, assistant-chat-ui
- **Backend:** nodejs, python, go, typescript, agent-frameworks, llm-integration
- **Data:** postgres, redis, migration-safety
- **Infra:** aws, docker, terraform, deployment-patterns
- **Always:** tdd, code-review, security-checklist, observability
