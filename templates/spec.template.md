---
artifact: spec
feature: <slug>
writer: architect
mutability: immutable
state: draft                     # architect writes as draft; orchestrator flips to approved after real user approves
approved_by:                     # leave blank — ONLY the orchestrator sets this, ONLY after user answers AskUserQuestion
approved_at:                     # leave blank — ONLY the orchestrator sets this
supersedes: null
---

# Spec — <feature name>

## Tech Stack
| Area | Chosen | Alternatives | Why (tradeoff) |
|------|--------|--------------|----------------|
|      |        |              |                |

## Test Infrastructure
| Dep | Tool | Why (tradeoff) | Source consulted |
|-----|------|----------------|------------------|
|     |      |                |                  |

## Requirements
FR-1: <one sentence, testable>
FR-2: ...

## Flows
<!-- optional but strongly preferred for anything with >1 step or actor —
     mermaid renders as an SVG diagram in the design-review surface -->
```mermaid
flowchart LR
  User -->|action| System --> Outcome
```

## Technical Risks
- <risk + mitigation>

## Performance Budgets
- <only if relevant: page load, API p99, etc.>

## Non-Goals
- <what we are explicitly NOT doing>
