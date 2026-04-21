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

```markdown
# Implementation Progress

## Domain Status
| Domain | Status | Tasks Assigned | Tasks Done | Blocker |
|--------|--------|----------------|------------|---------|

## Task Status
| Task ID | Title | Domain | Status | Depends On | Notes |
|---------|-------|--------|--------|------------|-------|

## Active Blockers
_None_

## Decisions Log
| When | Decision | Rationale |
|------|----------|-----------|

## Plan Amendments
_None_

## Deviations
_None_
```

Status values — domains: `not-started`, `in-progress`, `complete`, `blocked`. Tasks: `ready`, `in-progress`, `complete`, `blocked`, `failed`, `needs-revision`.

## Plan Revisions (in plan.md, not work.md)

When an implementor hits a blocker or discovers the plan's approach won't work mid-wave, they append a revision block to `features/<CURRENT>/plan.md`:

```markdown
## Plan Revisions

### Revision <N> — <YYYY-MM-DD> — by <implementor|architect> (wave <W>, task <T-ID>)
- **Original:** <quote or ref to original wave/criterion>
- **New:** <what the approach/criterion becomes>
- **Why:** <discovery, blocker, ops constraint — be specific>
- **Downstream impact:** <which tasks/criteria change, or "none">
- **Status:** pending orchestrator approval | approved by orchestrator | approved by architect | rejected
```

**Rules:**
- Trivial deviations (rename, refactor within the same design) go in work.md's `### Deviations`, NOT plan.md.
- Anything that touches evaluation criteria, task contracts, or downstream waves is a **material** revision — it goes in `work.md § Plan Revisions`, NOT in plan.md. Approved plan.md is immutable forever.
- Evaluator reads the revisions log as authoritative; approved revisions supersede original plan.md wave text.
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
