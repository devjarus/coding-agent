# coding-agent

**Evidence-gated software delivery for Claude Code and Codex.**

coding-agent turns a coding request into a controlled delivery loop: frame the
intent, resolve consequential architecture with the user, build, prove, review,
ship, and observe. Claims advance only when executable gates can find current
evidence.

[![Version](https://img.shields.io/badge/version-7.0.0-blue)]()
[![Agents](https://img.shields.io/badge/agents-6-green)]()
[![Skills](https://img.shields.io/badge/skills-60-green)]()
[![Gates](https://img.shields.io/badge/gates-8-green)]()
[![License](https://img.shields.io/badge/license-MIT-blue)]()

---

## What you get

- **One durable control loop.** A conductor reads the ledger, runs the next gate,
  and dispatches the smallest worker move that can clear it.
- **Ceremony that scales with risk, proof that doesn't.** A quick lane for small
  fixes, a standard lane for features, and a deep lane for one-way doors. Every
  lane needs the same proof; the quick lane can't be used to dodge review,
  because `reviewed?` measures the diff.
- **One writer, specialist judgment.** The conductor builds quick and standard
  changes itself (no hand-off re-reading the code). Separate agents contribute
  what a second mind is for: independent review, architecture options,
  diagnosis, the design surface, deployment.
- **Measured against native Claude Code.** `bench/` runs identical tasks
  through both and scores them with hidden acceptance tests
  ([bench/GOAL.md](bench/GOAL.md)).
- **Architecture as dialogue.** Before a consequential ADR is written, the
  planner can pause and return one to three system- or component-level questions.
  The conductor asks you, records your answers, and then resumes planning.
- **Evidence instead of narration.** Tests, reviews, design approval, deploys,
  and health checks are recorded against the current source tree. “It passed”
  without a matching evidence entry does not clear a gate.
- **A commit wall.** While a feature is active, a git pre-commit gate refuses any
  commit that lands past an unmet gate, whatever the commit message says.
- **Human authority at one-way doors.** Intent, irreversible architecture,
  visual approval, destructive actions, deployment, and push stay with you.
- **Engineering depth on demand.** 60 scoped skills cover frontend, backend,
  data, mobile, infrastructure, testing, security, documentation, research, and
  architecture diagrams.
- **Portable technical documentation.** Consumer projects get high-level
  topology and dataflow plus focused component contracts for substantial
  boundaries; the documents remain useful without this plugin.

## How it works

```text
                              You
                               │
                    intent + architecture choices
                               │
                               ▼
                        ┌─────────────┐
                        │  Conductor  │  sole writer: ledger, product memory,
                        └──────┬──────┘  and code in quick/standard lanes
                               │ ca next → first unmet gate
          ┌────────────┬───────┼─────────┬────────────┐
          ▼            ▼       ▼         ▼            ▼
      Planner      Developer  Designer  Diagnostician  Deployer
   frame/architect  review     design      diagnose   ship/observe
     (deep, ADRs) (+build deep)
          └────────────┴───────┼─────────┴────────────┘
                               │
                               ▼
                  ledger + evidence.jsonl + gates
```

The runtime has three primitives:

| Primitive | Purpose |
|---|---|
| **Ledger** | Durable intent, plan, decisions, log, and feature status |
| **Evidence** | Append-only records of commands, exits, output hashes, and tree hashes |
| **Gate** | Executable predicate that returns `pass`, `block`, or `n/a` |

Roles and skills act on those primitives; they are not additional state models.
See [Architecture](ARCHITECTURE.md) and [Primitives](docs/concepts/primitives.md).

## The delivery arc

```text
Frame → [Architect] → [Design] → Build → Prove → Review → [Ship → Observe]
  │          │            │         │       │        │        │       │
framed? architected? designed?      proven? reviewed? clean? shipped? observed?
```

Brackets mark conditional stages. A documentation-only change does not need a UI
design; a routine reversible change does not need an ADR; a local change does not
need deployment gates. The gate sequence stays fixed while applicability flexes.

| Lane | Use when | Builds | Review |
|---|---|---|---|
| quick | small fix, no UI / architecture / deploy | conductor | skipped only while the measured diff stays ≤ 150 lines |
| standard | features, services, multi-file changes | conductor | one read-only reviewer |
| deep | user asks, or a one-way door | developer workers | reviewer (+ dimension fan-out) |

| Gate | What it requires |
|---|---|
| `framed?` | A non-empty intent carrying the user’s recorded agreement |
| `architected?` | A live ADR for consequential work; explicit agreement for a one-way door |
| `designed?` | The human's browser verdict still matches `design.html` byte-for-byte (re-checked on every run), or the user declined visual review in their own words |
| `proven?` | Every declared verification tier green at the current tree |
| `reviewed?` | A current qualitative review with zero blocking findings (quick lane: a measured small, low-risk diff) |
| `clean?` | No coordinator state, hardcoded secrets, or debugger statements in the staged diff |
| `shipped?` | Successful deployment evidence when deployment is in scope |
| `observed?` | Successful post-deploy health evidence at the same tree |

## Architecture dialogue

The planner works at two altitudes before committing the project to a costly
direction:

- **System level:** boundaries, data ownership, public contracts, security model,
  deployment topology, external dependencies, and migrations.
- **Component level:** responsibility, public interfaces, dependencies, failure
  behavior, observability, test seams, and rollout compatibility.

If an answer changes the shape of the solution, the planner returns
`needs-input`. The conductor asks the questions in the main conversation and
redispatches the planner with your verbatim answers. Discovery does not count as
a failed gate. The completed ADR still requires a separate agreement when it
contains a one-way door.

## Runtime state

Project coordination lives under `.coding-agent/` and is gitignored:

```text
.coding-agent/
├── CURRENT                 active-feature stack
├── product.md              product memory + live ADRs + learnings
└── <feature>/
    ├── ledger.md           intent, plan, status, and append-only log
    ├── evidence.jsonl      append-only measured evidence
    ├── review.md           qualitative review artifact
    ├── design.html         UI look-contract, when applicable
    └── design-verdict.json SHA-bound human verdict, when applicable
```

The ledger is written only by the conductor. Evidence is written only by
`lib/record.sh`; a hook rejects direct edits and obvious shell or interpreter
writes. Gate results can be recomputed after session restart or context
compaction.

`ledger.sh init` also installs a small git `pre-commit` shim. While a feature is
active it runs `framed?` through `clean?` and refuses the commit at the first
block; with no active feature it does nothing. It never overwrites a hook it did
not write and skips repositories that use `core.hooksPath` (husky and similar),
telling you to call `hooks/pre-commit.sh` from your own hook instead.

## Install

### Codex

```bash
codex plugin marketplace add /path/to/coding-agent
codex plugin add coding-agent@coding-agent-local
```

Start a new task, then invoke the delivery skill:

> Use `$coding-agent:delivery-pipeline` to implement this feature end to end.

The main Codex task becomes the conductor and delegates bounded moves through
Codex subagents.

### Claude Code

```bash
git clone https://github.com/devjarus/coding-agent ~/.claude/plugins/coding-agent
claude --plugin-dir ~/.claude/plugins/coding-agent
```

The manifest registers `conductor`, `planner`, `developer`, `diagnostician`,
`designer`, and `deployer`, with the conductor selected by `settings.json`.

Optional MCP integrations are configured in `.mcp.json`: Context7, Exa,
Playwright, XcodeBuildMCP, and iOS Simulator MCP. Set `EXA_API_KEY` in your shell
when using Exa.

## Example

```text
You: Build a notes API with Node and SQLite. Add POST /notes and GET /notes?tag.

Conductor  → picks the standard lane and asks you to confirm the frame
Planner    → asks one data-ownership question, then records the chosen ADR
Conductor  → writes tests and implementation; `ca prove` records each tier
Developer  → reviews the diff read-only and writes review.md; `ca verdict`
Conductor  → `ca commit` stages only attributable paths, runs clean?, commits
             (the pre-commit gate re-checks every gate before the commit lands)
Conductor  → refreshes affected project docs and asks before push/deployment
```

## Documentation

| Start here | Contents |
|---|---|
| [Architecture](ARCHITECTURE.md) | High-level topology and component contracts |
| [Concepts: primitives](docs/concepts/primitives.md) | Ledger, evidence, and gate semantics |
| [Concepts: workflow](docs/concepts/workflow.md) | Control loop, dialogue, dispatch, and gate routing |
| [Concepts: lifecycle](docs/concepts/lifecycle.md) | Feature, evidence, interruption, deploy, and recovery lifecycle |
| [Contributor guide](AGENTS.md) | Repository structure, invariants, validation, and release workflow |
| [Docs index](docs/README.md) | Canonical documentation map |

## Development

No build step is required. After changing agents, gates, hooks, skills, scripts,
templates, or docs:

```bash
./scripts/validate.sh
evals/run.sh 00-smoke
evals/run.sh 08-wall-integrity
bench/selftest.sh
```

Whether the plugin beats native Claude Code is measured, not claimed: see
[bench/GOAL.md](bench/GOAL.md).

See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) before making a
release-affecting change.

## License

MIT — see [LICENSE](LICENSE).
