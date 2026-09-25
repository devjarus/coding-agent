# Architecture

coding-agent is a Markdown-and-shell plugin for Claude Code and Codex. It has no
application server and no build step. The product is a control system made of
role prompts, durable project state, executable evidence gates, reusable skills,
and optional tool integrations.

This document owns both architecture altitudes:

- **High level:** runtime topology, control flow, state ownership, and trust
  boundaries.
- **Component level:** contracts for the conductor, workers, ledger, evidence
  recorder, gates, hooks, design surface, skills, and platform adapters.

Detailed behavior lives in [Workflow](docs/concepts/workflow.md),
[Lifecycle](docs/concepts/lifecycle.md), and [Primitives](docs/concepts/primitives.md).

## 1. System topology

```text
┌──────────────────────────────── Host: Claude Code or Codex ───────────────────────────────┐
│                                                                                            │
│  User conversation                                                                         │
│          │                                                                                 │
│          ▼                                                                                 │
│  ┌────────────────┐       bounded dispatch       ┌────────────────────────────────────┐   │
│  │   Conductor    │─────────────────────────────►│ planner · developer · diagnostician│   │
│  │ sole state     │◄─────────────────────────────│ designer · deployer                 │   │
│  │ writer         │       structured return      └────────────────────────────────────┘   │
│  └───────┬────────┘                                                                         │
│          │ reads/runs/writes                                                               │
│          ▼                                                                                 │
│  ┌──────────────────────────────── Consumer project ────────────────────────────────────┐  │
│  │ source + tests + docs                                                                │  │
│  │ .coding-agent/product.md                                                             │  │
│  │ .coding-agent/CURRENT                                                                │  │
│  │ .coding-agent/<feature>/{ledger.md,evidence.jsonl,review.md,design.*}                │  │
│  └──────────────────────────────────────────────────────────────────────────────────────┘  │
│          ▲                   ▲                         ▲                                     │
│          │                   │                         │                                     │
│      lib/*.sh           gates/*.sh              hooks/*.sh                                 │
│   state/evidence         predicates          safety + resume                               │
└──────────┬───────────────────┬─────────────────────────┬─────────────────────────────────────┘
           │                   │                         │
           ▼                   ▼                         ▼
     skills/**           scripts/design-*          MCP servers
  scoped knowledge       review surface      Context7 · Exa · Playwright
                                             XcodeBuild · iOS Simulator
```

The plugin contributes capabilities; the consumer repository remains the source
of truth for product code, tests, commands, conventions, and committed technical
documentation.

## 2. Control plane

The conductor runs one ordered loop:

```text
read durable state
       │
       ▼
run first applicable unmet gate
       │
       ├── pass/n-a ───────────────► next gate
       │
       └── block ─► dispatch owner ─► verify return ─► record log ─► rerun gate
                                                                  │
                                                                  └─ two same blocks → user
```

The sequence is fixed:

```text
framed → architected → designed → proven → reviewed → clean → shipped → observed
```

Applicability is data-driven. Intent tags turn architecture, design, and deploy
stages on or off; they do not create alternate pipelines.

## 3. Role architecture

The six files under `agents/` are six registered roles. A dispatch creates a
separate worker instance; roles are not mode switches on one shared worker.

| Role | Kinds | Writes | Must not write |
|---|---|---|---|
| **Conductor** | coordination | ledger, product memory, user-approved state, explicit git staging | product code, direct evidence |
| **Planner** | `frame`, `architect` | returned intent/plan/ADR artifact | ledger, source, user answers |
| **Developer** | `build`, `prove`, `review` | scoped source/tests; one aggregate `review.md` | ledger, product memory |
| **Diagnostician** | `diagnose` | scoped fix and tests | ledger, speculative fixes without repro |
| **Designer** | `design` | look-contract and design-review artifacts | approval verdict on the user’s behalf |
| **Deployer** | `ship`, `rollback` | external deployment state via declared commands | source, deployment authority decisions |

Different `developer` dispatches can implement, prove, and review. Review stays
independent by dispatch contract: read-only dimension reviewers cannot modify
the implementation, and only one aggregate reviewer writes `review.md`.

## 4. State model

```text
.coding-agent/
├── CURRENT                     stack; last non-empty line is active
├── product.md                  product-wide memory
│   ├── vision/current state
│   ├── decisions               append-only live/superseded ADRs
│   ├── learnings               accumulated operational knowledge
│   └── shipped                 closed-feature rollups
└── <feature>/
    ├── ledger.md               single-writer feature record
    ├── evidence.jsonl          append-only measured evidence
    ├── review.md               review contract
    ├── design.html             optional look-contract
    ├── design-comments.json    optional comment batch
    └── design-verdict.json     optional SHA-bound human verdict
```

`.coding-agent/` is deliberately gitignored. Committed project docs are separate
and vendor-neutral: README, AGENTS, PRODUCT, DESIGN, `docs/architecture.md`,
`docs/dataflow.md`, optional `docs/components/*.md`, and deployment guidance.

### Ownership invariants

1. The conductor is the only writer of `ledger.md`, `product.md`, and `CURRENT`.
2. `lib/record.sh` is the only writer of `evidence.jsonl`.
3. Workers return structured changes; the conductor checks them against their
   pre-dispatch scope and snapshot.
4. User approval is recorded from the user’s actual reply, never inferred.
5. `.coding-agent/` is never staged.

## 5. Evidence binding

Each evidence line records:

```text
id · kind · tier · command · exit · stdout_sha · tree_sha · head · timestamp
```

`tree_sha` hashes the content and paths of tracked and untracked project files
while excluding `.coding-agent/`. It is stable across staging and committing
byte-identical content, but changes when source changes. This lets gates reject a
green result from an older tree.

For `kind=test`, `record.sh` accepts only the exact command declared as
`test-command-<tier>` in the frozen intent. The `proven?` gate requires a current
green entry for every declared tier, preventing a convenient unit command from
standing in for integration or end-to-end coverage.

## 6. Architecture decisions

Consequential work sets `consequential: yes`, enabling `architected?`.

```text
Planner inspects system + component choices
       │
       ├── unresolved design-changing choice
       │        └─► needs-input (1–3 questions)
       │                 └─► conductor asks user and redispatches
       │
       └── settled choices ─► ADR with options, trade-offs, decision, consequences
                                  │
                                  └─ one-way door? yes ─► explicit user agreement
```

ADRs live under `product.md ## decisions` and carry a stable `feature: <slug>`
anchor. Superseded ADRs remain readable but stop satisfying the gate.

## 7. Component contracts

### 7.1 `agents/conductor.md`

- **Input:** user request, gate results, worker returns, durable state.
- **Output:** user questions, bounded dispatches, ledger/product updates, explicit
  staging/commit actions when authorized.
- **Invariant:** no code writing and no claim-based advancement.
- **Failure behavior:** log every block; after two same-gate blocks with no new
  evidence, stop and ask the user.

### 7.2 Worker prompts in `agents/`

- **Input:** kind, gate, feature slug, scoped brief, relevant state slice,
  allowed paths, pre-dispatch snapshot, named skills.
- **Output:** `did`, `changed_paths`, `evidence_ids`, `gate_status`,
  `open_questions`, and `skipped_or_assumed`.
- **Invariant:** stateless between dispatches; no nested delegation; no ledger or
  product-memory writes.

### 7.3 `lib/ledger.sh`

- Initializes product and feature records from templates.
- Implements feature interruption as a stack in `CURRENT`.
- Freezes intent only when given the user’s recorded answer.
- Supports revision markers, incident framing, rollback lookup, block history,
  and feature rollup/close.
- On `init`, installs the git pre-commit gate (see 7.6).

### 7.4 `lib/record.sh`

- Runs a command and preserves its real exit status.
- Restricts evidence kinds and tier syntax.
- Binds tests to frozen commands and all evidence to the source tree.
- Serializes concurrent appends with an atomic directory lock.

### 7.5 `gates/`

- Shell predicates source `gates/lib.sh` and emit one JSON verdict.
- `pass` and `n/a` exit zero; `block` exits non-zero.
- Gate scripts observe state; they do not repair it.
- `gates/lib.sh` owns root resolution, ledger parsing, hashing, evidence lookup,
  declared tiers, intent tags, strict design-verdict verification, and the
  pre-commit gate installer.
- Most gates bind evidence to the current tree. `designed?` is the exception by
  design: it re-verifies the human's verdict against `design.html` on every run,
  so approval survives the build that implements it but not an edit to the
  look-contract.

### 7.6 `hooks/`

- `session-start.sh` ensures `.coding-agent/` is ignored before state is written,
  refreshes the pre-commit gate in projects already using the runtime, then
  injects the active ledger tail on resume.
- `evidence-wall.sh` (PreToolUse) denies Edit/Write to `evidence.jsonl` and Bash
  commands that name it alongside a write mechanism (redirection, `tee`, in-place
  editors, file-moving tools, interpreter writes). It catches accidents, not a
  determined forger: an indirectly built path still gets through.
- `pre-commit.sh` is a git hook, not a lifecycle hook. The shim `ledger.sh init`
  installs calls it; while a feature is active it runs `framed?` through
  `clean?` and refuses the commit at the first block. It never overwrites a
  foreign hook and skips a managed `core.hooksPath`.
- Codex runs no lifecycle hooks: the `delivery-pipeline` skill runs
  `session-start.sh` explicitly, and the git gate works there unchanged.
- Hooks are safety rails; workflow transitions remain visible in gates.

### 7.7 Design-review surface

`scripts/design-review.sh` controls a localhost Python server and browser app.
The user can leave anchored comments and approve exact bytes. The verdict stores
SHA-256 digests plus a zero-open-comments proof. Approval binds to
`design.html`, the look-contract: editing it reopens `designed?`. The verdict
also carries a `ledger.md` digest for audit only, because the conductor keeps
appending to the ledger after approval.

### 7.8 Skills and templates

Skills are scoped craft and domain knowledge loaded by worker need. Templates
define runtime artifacts and portable consumer documentation. Neither owns
workflow state; the conductor, ledger, evidence recorder, and gates do.

### 7.9 Platform adapters

- **Claude Code:** `.claude-plugin/plugin.json` registers agents and hooks;
  `settings.json` selects the conductor.
- **Codex:** `.codex-plugin/plugin.json` exposes the skill tree and MCP servers;
  `skills/general/delivery-pipeline/SKILL.md` maps role instructions onto Codex
  collaboration tools while keeping the main task as conductor.

Both adapters consume the same prompts, scripts, gates, templates, and state
model.

## 8. Trust boundaries

| Boundary | Threat | Control |
|---|---|---|
| Agent prose → gate | fabricated or stale success | evidence lookup bound to current tree and frozen test command |
| Agent → `evidence.jsonl` | hand-written green lines | `record.sh` sole writer; evidence-wall hook (accident guard, not a hard boundary) |
| Worker → shared workspace | claiming another change | scoped paths + pre-dispatch snapshot |
| Agent → human authority | forged approval | verbatim answer markers; `designed?` re-verifies the user-owned verdict instead of trusting a recorded command |
| Parallel workers → evidence | interleaved JSON or duplicate ids | serialized append lock |
| Source → commit | commit past an unmet gate | git pre-commit gate runs `framed?` … `clean?` |
| Source → commit | secret/debug leakage, tracked coordinator state | staged-diff `clean?` gate |
| Deploy attempt → production health | treating “deployed” as “healthy” | separate `deploy` and `observe` evidence |

## 9. Repository layout

```text
coding-agent/
├── agents/                 conductor + five worker roles
├── gates/                  eight executable predicates + shared library
├── lib/                    ledger and evidence recorder
├── hooks/                  evidence wall, resume preflight, git pre-commit gate
├── skills/                 60 scoped knowledge packages
├── templates/              runtime + portable project-doc templates
├── scripts/                validation, skill freshness, design-review surface
├── evals/                  artifact-based scenario harness
├── docs/concepts/          canonical design documentation
├── .claude-plugin/         Claude Code manifest
├── .codex-plugin/          Codex manifest
└── .mcp.json               optional MCP integrations
```

## 10. Intentional constraints

- Markdown + Bash, with a Python-standard-library localhost review server.
- No database, service process, or build system inside the plugin.
- Three runtime primitives only: ledger, evidence, gate.
- Prompt changes express craft; gates enforce claims that must be mechanical.
- Coordinator state remains local and disposable from Git’s perspective; product
  code and portable docs remain ordinary repository content.
