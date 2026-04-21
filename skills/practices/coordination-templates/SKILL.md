---
name: coordination-templates
description: Progress tracking structure for the orchestrator. Defines the work.md schema used for task coordination and session recovery. v2.
---

# Coordination Templates

## When to Apply
- Orchestrator initializing `work.md` at the start of implementation
- Resuming a session from existing `work.md`

For the canonical template, see `${CLAUDE_PLUGIN_ROOT}/templates/work.template.md`.

## work.md Structure (v2)

Canonical schema — matches `${CLAUDE_PLUGIN_ROOT}/templates/work.template.md`:

```markdown
---
artifact: work
feature: <slug>
writer: orchestrator
mutability: single-writer-mutable
state: active
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

## Findings (mid-implementation)
_None_

## Nits (deferred fixes)
_None_

## Handoff (for fix rounds — populated only when transferring between agents)
_None_
```

Task states: `ready`, `in-progress`, `complete`, `blocked`, `failed`, `needs-revision`.

## Plan Revisions — supersession rule

Approved `plan.md` is immutable forever. When an implementor hits a blocker or discovers the plan's approach won't work mid-wave, they return a structured `revisions:` entry; the orchestrator appends it to `work.md § Plan Revisions`:

```markdown
### R-1 — <YYYY-MM-DD> — by <implementor|architect> (wave <W>, task <T-ID>)
- **Supersedes:** plan.md §<section reference>
- **Change:** <what the new behavior is>
- **Why:** <reason>
- **Downstream impact:** <which tasks/criteria change, or "none">
- **Status:** pending | approved by orchestrator | approved by architect | approved by user | rejected
```

**Rules:**
- Trivial deviations (rename, refactor within the same design) go in `work.md § Deviations`, NOT `§ Plan Revisions`.
- Material changes (evaluation criteria, task contracts, downstream waves) go in `§ Plan Revisions`. `plan.md` itself is never edited.
- Evaluator reads `plan.md` for the original contract AND `work.md § Plan Revisions` for approved amendments. Approved revisions supersede original wave text.
- Orchestrator must resolve any `Status: pending` revision before dispatching the next wave — otherwise downstream work inherits an inconsistent plan.

## Session Recovery (v2)

When resuming after `/compact`, `/clear`, or a new session, read in this order:
1. `.coding-agent/session.md § Checkpoint` — phase, active_feature, last_completed, resume_hint
2. `.coding-agent/session.md § Action Log` tail — last ~20 entries for context
3. `.coding-agent/features/<CURRENT>/work.md` — task ledger (including `§ Handoff` and `§ Plan Revisions` if present)
4. `.coding-agent/features/<CURRENT>/spec.md` + `plan.md` — requirements and tasks (immutable)
5. `.coding-agent/learnings.md` — project-level gotchas

**v2 difference from v1:** `handoff.md`, `session-state.md`, `in-flight.md`, `nits.md` do NOT exist as separate files. All collapsed into `work.md` sections (`§ Handoff`, `§ Nits`) or `session.md` (`§ Checkpoint`, `§ Action Log`).

## Context Health Signals

Watch for these in `work.md` task states and `session.md` Action Log:

| Signal | Meaning | Action |
|--------|---------|--------|
| 3+ `failed` tasks in `work.md § Tasks` | Multiple approaches failing | Populate `work.md § Handoff`, dispatch Debugger |
| Same task toggling `in-progress` → `failed` repeatedly | Stuck in a loop | Suggest /compact to user, then Debugger full mode |
| 5+ `dispatch` events in action log since last compact | Session getting deep | Suggest /compact with phase-steered text before next dispatch |
