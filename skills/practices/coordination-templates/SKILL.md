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
```

Status values — domains: `not-started`, `in-progress`, `complete`, `blocked`. Tasks: `ready`, `in-progress`, `complete`, `blocked`, `failed`.

## Session Recovery

When resuming after `/clear` or a new session, read in this order:
1. `.coding-agent/features/<CURRENT>/session-state.md` — where we left off, what was tried
2. `.coding-agent/features/<CURRENT>/handoff.md` — what failed and what's ruled out (if in fix rounds)
3. `.coding-agent/features/<CURRENT>/progress.md` — task completion status
4. `.coding-agent/features/<CURRENT>/spec.md` + `plan.md` — requirements and tasks
5. `.coding-agent/learnings.md` — project-level gotchas

This ordering is deliberate: session-state.md and handoff.md tell you what happened recently (high value, small file), so you avoid re-reading large artifacts unnecessarily.

## Context Health Signals

Watch for these in progress.md updates:

| Signal | Meaning | Action |
|--------|---------|--------|
| 3+ `failed` tasks | Multiple approaches failing | Write handoff.md, consider debugger |
| Same task toggling `in-progress` → `failed` repeatedly | Stuck in a loop | Compact, then dispatch debugger |
| 5+ dispatches logged in decisions log | Session getting deep | Compact with steering before next dispatch |
