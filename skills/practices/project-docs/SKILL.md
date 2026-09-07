---
name: project-docs
description: Generates and maintains portable project docs, including high-level architecture and optional component contracts, with each fact owned in one cross-linked file. Reads the real codebase rather than boilerplate.
---

# Project Documentation Set

Creates and keeps current a portable documentation set that lets **any** coding agent work on the project — built from what's really in the codebase, never boilerplate. Grounded in three published, vendor-neutral conventions: the [agents.md spec](https://agents.md) (AGENTS.md), the [google design.md format](https://github.com/google-labs-code/design.md) (DESIGN.md), and the [Open Knowledge Format](https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing) (link-not-copy, single-source-of-truth, a `docs/` bundle with `index.md`).

## The one rule: each fact lives in exactly ONE file

Duplication guarantees drift. Every fact has a single owning file; every other mention is a **Markdown link**, never a copy. A doc may summarize in one sentence and link (orientation) — it must never carry a second authoritative copy.

## The set + ownership (single source of truth)

Generate from these templates (`${CLAUDE_PLUGIN_ROOT}/templates/<name>`). Two entry points: humans start at README, agents start at AGENTS.

| File | Template | Single source of truth — owns ONLY this | Never contains (link instead) |
|------|----------|------------------------------------------|-------------------------------|
| `README.md` | `readme.template.md` | install/run quick-start, **pinned** versions, directory tree, Documentation Map | product why, architecture, dataflow, design tokens, deploy commands |
| `AGENTS.md` | `agents.template.md` | build/test/lint **commands**, conventions, contribution mechanics, gotchas | versions (README pins), tree body, stack rationale, deploy values, product why |
| `PRODUCT.md` | `product-doc.template.md` | current-state what/why/for-whom, core flows, non-goals, maturity | build commands, architecture, the strategy Evolution Log (runtime-only) |
| `DESIGN.md` (UI only) | `design-doc.template.md` | design tokens, component look-contracts, guardrails | component file wiring (→ architecture), build commands |
| `docs/architecture.md` | `architecture.template.md` | topology, Data **Model** (schema), key components, stack rationale | data **flow** traces (→ dataflow), run commands, product why |
| `docs/dataflow.md` | `dataflow.template.md` | flow traces, state transitions, external boundaries, persistence | schema columns, component inventory (→ architecture) |
| `docs/components/<name>.md` (optional) | `component-doc.template.md` | one substantial component's interface, internal structure, invariants, failures, security, observability, and test seams | system topology/schema (→ architecture), end-to-end flows (→ dataflow), visual tokens (→ DESIGN) |
| `docs/index.md` | `docs-index.template.md` | the `docs/` table-of-contents (links only) | any architecture/flow content itself |
| `deployment.md` | `deployment-doc.template.md` | deploy/CI-CD **procedure**, rollback | secrets, env-var values, per-deploy history, runtime state |

`docs/architecture.md` is the project's **only high-level system architecture
surface** — it replaces a root `ARCHITECTURE.md`. Optional component contracts
are subordinate deep dives linked from that map, not competing system
architectures. (The plugin's own `ARCHITECTURE.md` is unrelated and untouched.)

## Cross-link wiring (no orphans)

Wire these in the same pass so both entry points reach everything:

- **README.md** → AGENTS, PRODUCT, docs/architecture, DESIGN, deployment (the Documentation Map).
- **AGENTS.md** → README, PRODUCT, docs/architecture, docs/dataflow, DESIGN, deployment (Where-to-look-next).
- **docs/architecture.md** ↔ **docs/dataflow.md** (bidirectional), plus → docs/index, README.
- **docs/architecture.md** → each applicable component contract; every
  **docs/components/*.md** links back to architecture, dataflow, and docs/index.
- **docs/index.md** → architecture, dataflow, every applicable component
  contract, and README.
- **PRODUCT.md** → README, docs/architecture, DESIGN. **DESIGN.md** → README, PRODUCT, docs/architecture. **deployment.md** → README, AGENTS, docs/architecture.

The `docs-links` close-out check verifies every relative link resolves, each
component contract is discoverable from both architecture and the index, and no
committed doc leaks plugin-runtime references.

## Vendor-neutral — the committed set must be portable

A user must be able to remove this plugin and have every doc keep working for whatever agent they switch to. So in the **committed bodies**:

❌ No `.coding-agent/`, `${CLAUDE_PLUGIN_ROOT}`, protocol/check/skill/role names, or `coding-agent:` instructions
❌ No deploy secrets, env-var values, or per-env runtime state — those live outside version control
✓ Plain Markdown + YAML, links only to each other and to real project artifacts (`.github/workflows`, `package.json`)

`AGENTS.md` follows the agents.md spec (Cursor, Aider, Codex, Gemini CLI, Claude Code, …). If a vendor loader like `CLAUDE.md` exists, make it a one-line pointer to AGENTS.md — never two sources. The single convention any agent must learn is one sentence: *"Start at AGENTS.md (agents) or README.md (humans); each fact lives in one file, follow the links."*

## Where each doc's content comes from

| Doc | Distilled from |
|-----|----------------|
| README / AGENTS / architecture / dataflow / index | the **real codebase** (package.json/go.mod/…, routes, schema, entry points, tests) |
| component contracts | the component's real public interfaces, dependencies, invariants, failure paths, telemetry, and tests |
| DESIGN.md | the project's actual theme/tokens/components + the approved per-feature look-contract (the design-review surface's `design.html`) — distilled, not re-invented |
| PRODUCT.md | the product north-star working notes if direction was shaped, else the spec's problem statement + scope — a **current-state snapshot**, stripped of any strategy log/bets |
| deployment.md | existing CI config + chosen platform |

## Replace scaffold READMEs — they are NOT real content

A `create-vite` / `create-react-app` / `create-next-app` scaffold ships a placeholder README describing *the template*, not *your app*. **A scaffold README must be fully replaced, not preserved.** The `docs-current` close-out check (`checks/docs-current.sh`) blocks close-out while any of these fingerprints remain — keep this list in sync with it:

| Scaffold | Fingerprint phrase |
|----------|--------------------|
| Vite | `This template provides a minimal setup` / `Currently, two official plugins are available` |
| Create React App | `Getting Started with Create React App` |
| Next.js | `bootstrapped with [\`create-next-app\`]` |
| SvelteKit | `npm create svelte@latest` |
| Astro | `npm create astro@latest` / `Welcome to your new Astro project` / `Everything you need to know is in the README` |

The check also fails a README **byte-identical to its first commit while ≥3 source commits have landed** — committed at scaffold time and never touched. Either way: write a real README from the actual codebase.

## Setup flow

**New project** (at first full close-out, after the first feature ships): generate the whole applicable set from the real codebase in one pass, wiring all cross-links. DESIGN.md only if the project has a UI; deployment.md only if CI config exists. If CI is missing, close-out step 4.5 scaffolds it first so deployment.md/AGENTS.md can point at a real workflow.

**Existing (brownfield) project** (run on demand, not gated on a feature):
- **README** — preserve a hand-written one (only fill missing sections + add the Documentation Map); replace a scaffold one wholesale.
- **AGENTS.md** — always create if missing.
- **docs/architecture.md + dataflow.md + index.md** — create from the code. If a legacy root `ARCHITECTURE.md` exists, move its content into `docs/architecture.md` and reduce the root file to a one-line pointer (`Architecture lives in [docs/architecture.md](docs/architecture.md)`) — never two architecture docs.
- **docs/components/*.md** — create only for a substantial boundary: public API/event compatibility, independent data ownership, security isolation, complex recovery behavior, or non-obvious load-bearing invariants. Do not create one file per class or UI component.
- **DESIGN.md** — scan existing tokens/components (UI projects).
- **deployment.md** — from existing CI config.
- **PRODUCT.md** — from the README/spec problem statement.
Incremental adoption is fine: land AGENTS + README first, add the `docs/` bundle + DESIGN/PRODUCT on the next close-out.

## How to generate

### Step 1 — Scan the codebase

- `package.json` / `go.mod` / `Package.swift` / `requirements.txt` → stack + pinned deps
- `spec.md`, `plan.md`, product north-star (if present in `.coding-agent/`) → product + decisions (read-only sources; never referenced by name in the output)
- Route/controller files → API surface; schema/migration files → data model
- Component entry points + public types/events + failure paths + telemetry + tests
  → decide whether a detailed component contract is warranted
- Test files → test commands; entry points (`src/index.*`, `main.*`) → how it starts
- theme/CSS/component files → design tokens; `.github/workflows/` → CI/deploy

### Step 2 — Generate ASCII diagrams

Plain ASCII art — renders everywhere, no dependencies. **No Mermaid, no CDN.**

**System diagram (docs/architecture.md):**
```
┌──────────────┐    HTTP     ┌──────────────┐    SQL     ┌──────────┐
│ React Client │───────────→│ Express API  │──────────→│  SQLite  │
│  :5173       │←───────────│  :3001       │←──────────│          │
└──────────────┘             └──────────────┘           └──────────┘
```

**Data model (docs/architecture.md — schema only):**
```
posts
├── id          INTEGER  PK
├── title       TEXT     NOT NULL
├── slug        TEXT     UNIQUE
└── createdAt   TEXT
```

**Data flow (docs/dataflow.md — movement only):**
```
User → Frontend → POST /api/posts → Validate → INSERT INTO posts → 201 → Redirect to /posts/:slug
```

### Step 3 — Write the files + wire cross-links

Write each file from its template, then wire the Documentation Map / Where-to-look-next / docs bundle links. Keep them skimmable:
- README < 80 lines · AGENTS < 60 · docs/architecture < 120 · others proportionate.

For component documentation, first keep the complete component inventory in
`docs/architecture.md`. Add `docs/components/<name>.md` only when the threshold
above is met, and replace the inventory's detail with a link. If a component's
contract is obvious from its public types plus tests, those remain the canonical
documentation.

## Rules

- **Read the code, don't guess.** Every command, path, and diagram comes from the actual codebase.
- **Pin versions in README only.** AGENTS names tech without versions and links to README.
- **ASCII diagrams required** (architecture + dataflow). No Mermaid.
- **One fact, one file.** Schema → architecture; flow → dataflow; versions → README; commands → AGENTS. When in doubt: name-and-link, don't restate.
- **Two architecture altitudes.** `docs/architecture.md` owns system boundaries
  and the component inventory; `docs/components/*.md` owns deep contracts only
  for substantial components.
- **Committed docs stay portable.** No `.coding-agent/`, no plugin/protocol/role names, no secrets. The `docs-links` check enforces this.
- **Omit empty sections.** A section with nothing useful is worse than no section.
