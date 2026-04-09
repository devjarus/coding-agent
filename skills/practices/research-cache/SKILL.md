---
name: research-cache
description: Persistent research knowledge base — stores findings from codebase exploration, library research, and architectural decisions. Lookup before researching. Expire stale entries. Prevents redundant research across pipeline runs.
---

# Research Cache

A file-based knowledge base at `.coding-agent/research/` that persists across pipeline runs. Check here BEFORE doing new research — if a recent entry exists, use it instead of re-researching.

## When to Apply

- Before any research step (codebase exploration, library docs, competitor analysis)
- After completing research (save findings for future use)
- When the architect or implementor needs context about decisions already made

## Directory Structure

```
.coding-agent/research/
├── index.md              # Topic index with freshness dates
├── codebase-patterns.md  # How the existing codebase is structured
├── stack-decisions.md    # Tech stack choices and rationale
├── library-{name}.md     # Library-specific research (e.g., library-shadcn.md)
├── api-{name}.md         # External API research
└── topic-{name}.md       # General topic research
```

## Lookup Process

**Before researching anything:**

1. Read `.coding-agent/research/index.md` (if it exists)
2. Check if your topic has an entry
3. Check the `updated` date against freshness rules:

| Category | Fresh if | Reason |
|----------|----------|--------|
| **Codebase patterns** | < 1 day | Code changes frequently during development |
| **Stack decisions** | < 30 days | Tech choices are stable once made |
| **Library docs** | < 7 days | APIs change with releases |
| **Competitor analysis** | < 14 days | Competitors move slowly |
| **Architecture decisions** | < 30 days | Architecture is stable once decided |

4. If **fresh**: read the cached file, skip research
5. If **stale**: re-research, update the file
6. If **not found**: research, create a new file

## Save Process

**After completing any research:**

1. Write findings to the appropriate file in `.coding-agent/research/`
2. Use this frontmatter format:

```markdown
---
topic: Shadcn/UI component patterns
category: library
updated: 2026-04-05
sources:
  - Context7 docs
  - Existing codebase usage in client/src/components/ui/
freshness: 7 days
---

## Key Findings

[Structured findings here]

## Decisions Made

[Any choices or recommendations based on this research]

## Relevance

[When this research is useful — what questions it answers]
```

3. Update `index.md` with the new/updated entry

## Index Format

`.coding-agent/research/index.md`:

```markdown
# Research Index

| Topic | File | Category | Updated | Fresh Until |
|-------|------|----------|---------|-------------|
| Codebase structure | codebase-patterns.md | codebase | 2026-04-05 | 2026-04-06 |
| Shadcn/UI usage | library-shadcn.md | library | 2026-04-05 | 2026-04-12 |
| Express vs Fastify | stack-decisions.md | architecture | 2026-04-03 | 2026-05-03 |
```

## Rules

1. **Always check before researching** — read index.md first
2. **Always save after researching** — future agents benefit from your work
3. **Include sources** — so future agents can verify or update
4. **Include decisions** — not just facts, but what was decided and why
5. **Be specific** — "React 18.3 with RSC" not "React"
6. **Codebase patterns expire daily** — code changes fast during active development
7. **Don't cache trivial lookups** — only research that took significant effort
