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

## Assumed Defaults
<!-- The architect records ≤2 LOW-STAKES forks it defaulted instead of asking, so
     the user sees + can override them in the SINGLE design-review approval pass.
     Design-changing forks never go here — they are ask_user questions. Empty = none. -->
| Fork | Chosen default | Why | How to override |
|------|----------------|-----|-----------------|
| _none_ | | | |

## Flows
<!-- optional but strongly preferred for anything with >1 step or actor.
     Use an ASCII diagram in a plain code fence (same style as ARCHITECTURE.md) —
     it renders verbatim in the design-review surface and needs no dependencies. -->
```
user → [action] → System → Outcome
                     └──fail──→ error path
```

## Technical Risks
- <risk + mitigation>

## Performance Budgets
- <only if relevant: page load, API p99, etc.>

## Non-Goals
- <what we are explicitly NOT doing>
