# Lifecycle

The lifecycle is durable state plus recomputable gates. Conversation history may
compact or disappear without changing the meaning of an active feature.

## Feature lifecycle

```text
          initialize
              │
              ▼
          ┌────────┐   user agrees   ┌────────┐   gates clear   ┌────────┐
          │ draft  │────────────────►│ frozen │───────────────►│ active │
          └────────┘                 └───┬────┘                └───┬────┘
                                         │ revision                 │
                                         └────────► draft           │
                                                                    ▼
                                                         ┌────────────────────┐
                                                         │ shipped/abandoned │
                                                         │ /superseded       │
                                                         └────────────────────┘
```

- **Draft:** intent or plan can still change.
- **Frozen:** the user’s answer is recorded; `framed?` can pass.
- **Active:** work advances through applicable gates.
- **Closed:** outcome and learnings are rolled into product memory.
- **Abandoned/superseded:** work stops, but the learning is still retained.

## Evidence lifecycle

Evidence is immutable after append, but its usefulness is tree-relative.

```text
command runs ─► evidence appended ─► gate matches current tree ─► pass
                                            │
                               source bytes change
                                            │
                                            ▼
                                          stale
```

Stale evidence remains part of the audit trail; it simply cannot satisfy a gate
for the new tree. The remedy is a fresh recorded run, never editing an old line.

## Decision lifecycle

ADRs are append-only in `product.md ## decisions`.

```text
questions → options → decision → [user agrees to one-way door] → live ADR
                                                               │
                                                     later decision reverses it
                                                               │
                                                               ▼
                                                          superseded-by
```

The stable `feature: <slug>` line connects an ADR to the feature regardless of
heading changes. Supersession preserves history while preventing an obsolete ADR
from satisfying `architected?`.

## Interruption lifecycle

`CURRENT` is a stack, not a single overwriteable pointer.

```text
feature-a active
       │ production incident
       ▼
feature-a
incident-b   ← active
       │ incident closes
       ▼
feature-a    ← resumed
```

The interrupted ledger receives a timestamped marker explaining why work paused.
Closing the interrupting feature pops the stack and restores the previous one.

## Failure lifecycle

```text
gate blocks
   │
   ├─ log reason
   ├─ dispatch owning kind
   ├─ new evidence or attributable change? ─► rerun
   │
   └─ same block twice, no new evidence ─► escalate to user
```

A fresh evidence id is progress even when it is red; it changes what is known.
An identical block with no new evidence is a sign that the current mental model
is not producing information.

Diagnosis uses a stricter red-to-green arc:

1. record the failing reproduction;
2. isolate and name the cause;
3. make the smallest scoped fix;
4. record the identical reproduction going green;
5. rerun every declared test tier because the tree changed.

## Design lifecycle

```text
look-contract → browser comments → revision → human approval
                                          │
                                          ▼
                           sha-bound verdict + zero open comments
                                          │
                            artifact bytes change later
                                          │
                                          ▼
                                   approval invalidated
```

The designer controls iteration but not approval. The user’s verdict is written
by the review surface, then verified and recorded as evidence.

## Deployment lifecycle

```text
prove → review → clean → commit → deploy → observe
                                      │         │
                                      │         └─ unhealthy
                                      │                │
                                      └────────────────┴─► rollback last known-healthy → diagnose
```

A known-healthy rollback target requires both a successful deploy and a later
successful observation at the same tree. The previous commit is not assumed to
be safe merely because it is previous.

## Session recovery

On session start:

1. ensure `.coding-agent/` is gitignored;
2. read the last non-empty `CURRENT` entry;
3. inject the active ledger tail;
4. read its evidence file;
5. run gates from the beginning and stop at the first applicable block.

This is why the runtime does not need a separate recovery protocol. The normal
loop is itself the recovery algorithm.

## Product-memory lifecycle

The product ledger survives across features:

| Section | Growth rule |
|---|---|
| Vision/current state | conductor-owned current snapshot |
| Decisions | append decisions; mark supersession, never erase history |
| Learnings | append concise knowledge future workers can act on |
| Shipped | append feature rollups with outcome and deployment context |

Workers receive only the smallest relevant slice. This keeps long-lived history
durable without flooding each dispatch with every past feature.
