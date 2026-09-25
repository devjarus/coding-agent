# Runtime primitives

coding-agent is built on exactly three state-and-control primitives: **ledger**,
**evidence**, and **gate**. Roles, skills, hooks, and workflows operate on these
primitives; they do not introduce another state model.

## Ledger

A ledger is the durable account of what a feature means and what happened to it.

```text
.coding-agent/
├── product.md          product-wide decisions, learnings, and shipped rollups
├── CURRENT             active-feature stack
└── <feature>/
    └── ledger.md       intent, plan, status, and chronological log
```

Properties:

- **Single writer:** only the conductor edits ledger state.
- **Human agreement is quoted:** freezing intent requires the user’s actual
  reply, not an agent-authored `approved: true` field.
- **Revisions are visible:** a revision marker reopens a frozen section until
  the user agrees again.
- **Interruptions are stacked:** an incident can become active without losing
  the feature it interrupted.
- **Closure rolls knowledge forward:** summary and learnings move into
  `product.md` so the next worker receives durable context.

The ledger records decisions and transitions. It does not prove that a command
ran successfully.

## Evidence

Evidence is an append-only JSONL record written exclusively by `lib/record.sh`.

```json
{"id":7,"kind":"test","tier":"e2e","cmd":"npm run test:e2e","exit":0,"stdout_sha":"…","tree_sha":"…","head":"…","at":"…"}
```

Every entry carries:

| Field | Meaning |
|---|---|
| `id` | Monotonic feature-local identifier |
| `kind` | `test`, `review`, `design`, `deploy`, `observe`, or `run` |
| `tier` | Named verification tier such as `unit`, `integration`, or `e2e` |
| `cmd` / `exit` | Exact command and real process result |
| `stdout_sha` | Digest of captured output |
| `tree_sha` | Content identity of the project tree the result covers |
| `head` / `at` | Git commit and UTC timestamp at execution |

Test evidence is accepted only when its command exactly matches the frozen
intent’s `test-command-<tier>` contract. The evidence-wall hook rejects direct
edits and obvious shell or interpreter writes, and concurrent recorders
serialize their append. The wall guards against accidents; it is not a hard
security boundary, so gates still check every line against the current tree
and frozen command.

Evidence proves execution. It does not decide whether the result is sufficient
to advance.

## Gate

A gate is an executable predicate over current ledger, evidence, artifacts, and
Git state.

```json
{"gate":"proven","status":"block","reason":"no passing test at current tree for tier: e2e"}
```

Every gate returns one of:

- `pass` — applicable and satisfied;
- `block` — applicable but missing or contradictory evidence;
- `n/a` — not applicable to this feature.

Gates are read-only. They report what is missing; the conductor routes work to
the owning role and reruns the predicate.

## Composition

```text
ledger says what was agreed
        +
evidence says what actually ran
        +
gate decides whether the current claim is justified
        =
safe transition to the next delivery stage
```

The delivery workflow, agent roles, and skills are compositions around this
equation:

- A **role** is a bounded actor contract.
- A **skill** is reusable knowledge loaded when relevant.
- A **hook** protects an invariant at a tool or git boundary: the evidence wall
  at tool calls, the pre-commit gate at `git commit`.
- A **workflow** is the conductor repeatedly running ordered gates and routing
  blocked work.

They are useful concepts, but the durable runtime can always be reconstructed
from the three primitives.

## Why only three

More artifact types and protocol-specific state make recovery harder: after a
long session, the coordinator must remember which file and which transition was
authoritative. Here, recovery is mechanical:

1. Read `CURRENT` and the active ledger.
2. Read `evidence.jsonl`.
3. Run gates in order.
4. Resume at the first applicable block.

No conversational memory is required to determine where work stands.
