---
artifact: work
feature: <slug>
writer: orchestrator
mutability: single-writer-mutable
state: active                    # → archived at close-out
supersedes: null
---

# Work Ledger

## Tasks
| ID | Title | State | Assignee | Started | Finished |
|----|-------|-------|----------|---------|----------|

## Decisions Log
| When | Who | Decision | Why |
|------|-----|----------|-----|

## Deviations (trivial — no approval needed)
_None_

## Plan Revisions (material — supersede plan.md sections; plan.md immutable)
_None_
<!--
Canonical format when populated:

### R-1 — <YYYY-MM-DD> — <by orchestrator|architect>
- **Supersedes:** plan.md §<section reference>
- **Change:** <what the new behavior is>
- **Why:** <reason>
- **Downstream:** <which tasks/criteria affected>
- **Status:** pending | approved by orchestrator | approved by architect | approved by user | rejected

The `revisions-resolved.sh` check matches any of these on the Status line:
  - `Status: pending`
  - `- Status: pending`
  - `- **Status:** pending`
  - `**Status**: pending`
  - Prose suffixes are OK: `- **Status:** pending user decision`
What matters: the word `pending` immediately follows the `Status:` key.
Add freeform prose AFTER `pending` if useful (e.g., `pending user decision`).
-->

## Findings (mid-implementation)
_None_

## Nits (deferred fixes)
_None_

## Handoff (for fix rounds — populated only when transferring between agents)
_None_
