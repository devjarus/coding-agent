---
artifact: intent
feature: <slug>                  # YYYY-MM-DD-short-name
writer: orchestrator
mutability: immutable            # once approved, NEVER edit — not even to "promote" size/mode on escalation
state: draft                     # → approved when user signs
approved_by:                     # set to "user" on approval
approved_at:                     # ISO-8601 timestamp on approval
supersedes: null
mode: feature                    # feature | touch-up | refactor — the original user-approved intent
size: medium                     # micro | small | medium | large — the original classification
---

<!--
Escalation note: if a Micro needs to become Touch-up, or Touch-up to Small,
the escalation adds a plan.md / spec.md to the feature dir; the existing
intent.md stays signed at its original mode/size. The approved user intent
never changes retroactively.
-->


# Intent

## Request (verbatim)
"<user's exact message>"

## Restated
<one paragraph: what user wants, constraints, context from AGENTS.md>

## Path
Gates: Intent | Spec | Plan | Push     # mark passed gates with ✓
Waves: <estimated count>
