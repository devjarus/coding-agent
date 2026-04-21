---
artifact: intent
feature: <slug>                  # YYYY-MM-DD-short-name
writer: orchestrator
mutability: immutable
state: draft                     # → approved when user signs
approved_by:                     # set to "user" on approval
approved_at:                     # ISO-8601 timestamp on approval
supersedes: null
mode: feature                    # feature | touch-up | refactor
size: medium                     # micro | small | medium | large
---

# Intent

## Request (verbatim)
"<user's exact message>"

## Restated
<one paragraph: what user wants, constraints, context from AGENTS.md>

## Path
Gates: Intent | Spec | Plan | Push     # mark passed gates with ✓
Waves: <estimated count>
