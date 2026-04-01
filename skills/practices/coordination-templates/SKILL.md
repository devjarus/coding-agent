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
