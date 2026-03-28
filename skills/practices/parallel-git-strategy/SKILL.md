---
name: parallel-git-strategy
description: Git branching and merge strategy for parallel agent work — worktree isolation, branch-per-domain, conflict prevention, and merge protocols. Use when the Impl Coordinator dispatches multiple domain leads concurrently.
---

## When to Apply
- Impl Coordinator dispatching 2+ domain leads concurrently
- Any parallel agent work that modifies files

## Strategy: Branch-Per-Domain

### Setup (Impl Coordinator does this before dispatching)
1. Create a feature branch from main: `feat/<project-name>`
2. For each domain lead, create a sub-branch: `feat/<project-name>/frontend`, `feat/<project-name>/backend`, etc.
3. Each domain lead works on its own branch — no conflicts possible

### During Implementation
- Each specialist commits to the domain branch
- Domain leads review on their branch
- If a specialist needs to READ files from another domain (e.g., shared types), they read from the parent branch

### Merge Protocol (Impl Coordinator does this after all domains complete)
1. Merge domain branches back to feature branch one at a time
2. Order: data → backend → frontend → infra (dependencies flow left to right)
3. If merge conflicts occur: coordinator resolves or dispatches relevant lead
4. After all merged: run full test suite on feature branch
5. Feature branch is what gets reviewed

### Rules
- GIT-01 (CRITICAL): Never have two domain leads commit to the same branch simultaneously
- GIT-02 (CRITICAL): Merge in dependency order — data before backend, backend before frontend
- GIT-03 (HIGH): Each domain lead creates atomic commits — one logical change per commit
- GIT-04 (HIGH): Run tests after each domain merge to catch integration issues early
- GIT-05 (MEDIUM): If using worktrees (`git worktree add`), clean up after merge

### Fallback: Sequential Mode
If the project is small (< 5 tasks) or domains are tightly coupled, skip branching and run domain leads sequentially on a single branch. The overhead of branching isn't worth it for small changes.

### Decision Tree
```
Tasks across 2+ domains AND domains are independent?
├── YES, > 5 tasks → Branch-per-domain
├── YES, ≤ 5 tasks → Sequential on single branch
└── NO (tightly coupled) → Sequential on single branch
```
