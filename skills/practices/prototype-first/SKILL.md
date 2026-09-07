---
name: prototype-first
description: Build a disposable clickable mock to answer unresolved product-shape questions before committing production architecture. Quarantined, evidence-recorded, and explicitly graduated or abandoned.
scope: any
trigger: on-match
category: practice
---

# Prototype First

A prototype answers one question: **is this the right product direction?** It is
not an MVP or a production foundation. Use it when the user can judge a flow by
clicking but cannot yet settle the shape in words.

## Routing

| Signal | Route |
|---|---|
| “Prototype it”, “mock it”, “let me feel it” | Offer a prototype arc |
| A product-shape question remains unanswerable in architecture dialogue | Offer a prototype arc |
| Direction and acceptance criteria are already clear | Use the normal delivery arc |
| The unknown is technical feasibility | Run a scoped spike and decision record |

The conductor asks before entering prototype work.

## Quarantine

1. Put all prototype source in top-level `prototype/` with its own entry point.
2. Start `prototype/README.md` with:

   `# DISPOSABLE PROTOTYPE — judged, never shipped or imported by production.`

3. Production code never imports from `prototype/`.
4. Use deterministic fixture data and make fake boundaries explicit.
5. Record each build/render command through `lib/record.sh` as `kind=run`; do
   not label prototype checks as production test evidence.
6. Prototype commits are optional and user-authorized. Graduation removes the
   directory; Git history is the archive.

## Build shape

- Use the intended frontend stack when known; otherwise use the smallest
  familiar stack that can answer the product question.
- Prefer static fixture JSON. Use request mocks only when latency, error, or
  optimistic states are part of what the user must judge.
- Include happy, empty, loading, error, and long-content states.
- Treat fixture shapes as candidate contracts, not approved production APIs.

## Round loop

```text
build/revise → record render check → user explores → conductor logs feedback
       ▲                                                   │
       └──── continue / pivot / graduate / abandon ◄───────┘
```

Log each decision in the prototype feature ledger. At round four and beyond,
ask what uncertainty another round would resolve; do not iterate by inertia.

## Graduation

1. Distill what won, what was rejected, and why into a fresh production frame.
2. Carry fixture shapes forward only as candidate component/API contracts.
3. Use screenshots of the winning flow as input to the real design look-contract.
4. Record stack discoveries in product learnings.
5. Remove `prototype/` in the production change set.
6. Run the canonical gates from `framed?`; prototype `run` evidence does not
   satisfy `proven?`.

## Abandonment

Close the prototype feature as abandoned with a concise learning explaining why.
Remove prototype source only when the user asks; otherwise leave it quarantined
and clearly marked.
