---
name: coordination-templates
description: Progress tracking structure for impl-coordinator. Defines the progress.md schema used for task coordination and session recovery.
---

# Coordination Templates

## When to Apply
- Impl Coordinator initializing progress.md
- Resuming a session from existing progress.md

## Progress.md Structure

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

## Plan Revisions (in plan.md, not progress.md)

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
- Trivial deviations (rename, refactor within the same design) go in progress.md's `### Deviations`, NOT plan.md.
- Anything that touches evaluation criteria, task contracts, or downstream waves is a **material** revision and goes in plan.md.
- Evaluator reads the revisions log as authoritative; approved revisions supersede original wave text.
- Orchestrator must resolve any `Status: pending` revision before dispatching the next wave — otherwise downstream work inherits an inconsistent plan.

## Session Recovery

When resuming after `/clear` or a new session, read in this order:
1. `.coding-agent/features/<CURRENT>/session-state.md` — where we left off, what was tried
2. `.coding-agent/features/<CURRENT>/handoff.md` — what failed and what's ruled out (if in fix rounds)
3. `.coding-agent/features/<CURRENT>/progress.md` — task completion status
4. `.coding-agent/features/<CURRENT>/spec.md` + `plan.md` — requirements and tasks
5. `.coding-agent/learnings.md` — project-level gotchas

This ordering is deliberate: session-state.md and handoff.md tell you what happened recently (high value, small file), so you avoid re-reading large artifacts unnecessarily.

**Precedence when both `session-state.md` and `handoff.md` exist:** session-state.md is the more recent checkpoint — its `Current Phase` field tells you where you are. Read it first. Only read handoff.md if the phase is a fix round; otherwise handoff.md is historical and can be skipped.

## Context Health Signals

Watch for these in progress.md updates:

| Signal | Meaning | Action |
|--------|---------|--------|
| 3+ `failed` tasks | Multiple approaches failing | Write handoff.md, consider debugger |
| Same task toggling `in-progress` → `failed` repeatedly | Stuck in a loop | Compact, then dispatch debugger |
| 5+ dispatches logged in decisions log | Session getting deep | Compact with steering before next dispatch |
