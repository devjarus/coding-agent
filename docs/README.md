# Documentation

Canonical reference docs for `coding-agent`. Start at the project [README](../README.md) if you're new.

## Concepts

The "what" and "why" of the design. Read in order if you're trying to understand the system from the ground up.

| Doc | Reading time | Read when |
|-----|--------------|-----------|
| [**primitives.md**](concepts/primitives.md) | 12 min | You want to understand the four primitives (Actor, Artifact, Skill, Check) and the invariants they obey. The foundation. |
| [**workflow.md**](concepts/workflow.md) | 20 min | You want to follow a real session step-by-step (T=0 → T=10) — discovery, gates, parallel dispatch, fix rounds, close-out. The canonical flow. |
| [**lifecycle.md**](concepts/lifecycle.md) | 15 min | You want details on artifact states, ownership, the close-out 8-step protocol, fix-round escalation, recovery, and session hygiene. The state machines. |

These three together describe the entire system. If you only read one, read primitives.md.

## Why the design is shaped this way

| Doc | For |
|-----|-----|
| [**retrospective.md**](retrospective.md) | The honest story of v1 failures and how v2 addresses them. Written so future contributors don't re-introduce the patterns that broke. ~15 min read. |

## Reference

For day-to-day use you'll mostly look at the project root:

| Path | What lives there |
|------|------------------|
| [`../ARCHITECTURE.md`](../ARCHITECTURE.md) | Topology diagrams, agent dispatch graph, artifact flow, model tier, MCP routing. The "where everything lives." |
| [`../agents/`](../agents/) | The 5 agent prompts (orchestrator, architect, implementor, evaluator, debugger) |
| [`../protocols/`](../protocols/) | The 9 named workflows agents reference at runtime |
| [`../checks/`](../checks/) | The 9 deterministic verification scripts (+ `lib.sh`) |
| [`../templates/`](../templates/) | The 8 artifact frontmatter templates |
| [`../skills/`](../skills/) | 54 scoped knowledge modules (domain specialists + practices + general) |

## Contributing & operations

| Doc | For |
|-----|-----|
| [`../AGENTS.md`](../AGENTS.md) | Working on the plugin itself — adding skills, modifying agents, validating changes |
| [`../CONTRIBUTING.md`](../CONTRIBUTING.md) | Contributing back to this project |
| [`../CHANGELOG.md`](../CHANGELOG.md) | Version history with rationale per change |
| [`../ACKNOWLEDGMENTS.md`](../ACKNOWLEDGMENTS.md) | Credits + inspirations |

## How the docs are organized

This split is intentional:

- **`README.md`** (project root) — what + why + quickstart for **users**
- **`ARCHITECTURE.md`** (project root) — how the pieces fit, with diagrams (still user-facing for advanced users)
- **`docs/concepts/`** — formal definitions and state machines for **deep readers**
- **`AGENTS.md`** (project root) — meta-dev guide for **plugin contributors**
- **`agents/` / `protocols/` / `templates/` / `checks/` / `skills/`** — the actual runtime files

Three audiences (user / contributor / runtime), three doc tiers, no duplication.
