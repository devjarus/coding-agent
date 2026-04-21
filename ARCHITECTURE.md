# Architecture

The coding-agent plugin (v2) is a multi-agent software-development pipeline built from four primitives. This document maps the primitive relationships, dispatch topology, artifact flow, and gate/check placement. For formal primitive definitions see `docs/redesign/primitives.md`; for the canonical happy-path flow see `docs/redesign/workflow-spec.md`.

## High-level topology

```
                              ┌─────────┐
                              │  USER   │ ← owns Intent, approves gates
                              └────┬────┘
                                   │  types request, answers AskUserQuestion
                                   ▼
  ┌────────────────────────────────────────────────────────────────┐
  │                       ORCHESTRATOR                             │
  │                   (main-thread, state machine)                 │
  │                                                                │
  │   ┌──────────────┐   ┌────────────┐   ┌───────────────┐        │
  │   │ reads state  │→→ │ classifies │→→ │ runs Checks   │        │
  │   └──────────────┘   └────────────┘   └───────┬───────┘        │
  │                                               │ ok             │
  │                                               ▼                │
  │                                        ┌──────────────┐        │
  │                                        │  dispatches  │        │
  │                                        └──────┬───────┘        │
  └───────────────────────────────────────────────┼────────────────┘
                                                  │
                ┌───────────────┬─────────────────┼──────────────┐
                ▼               ▼                 ▼              ▼
          ┌──────────┐   ┌──────────────┐   ┌──────────┐   ┌──────────┐
          │ARCHITECT │   │ IMPLEMENTOR  │   │EVALUATOR │   │ DEBUGGER │
          │  opus    │   │   sonnet     │   │  opus    │   │   opus   │
          └────┬─────┘   └──────┬───────┘   └────┬─────┘   └────┬─────┘
               │                │                │              │
               │ writes         │ writes         │ writes       │ writes
               │ spec.md        │ source + tests │ review.md    │ diagnosis.md
               │ plan.md        │                │ screenshots/ │
               │ (as draft)     │                │              │
               ▼                ▼                ▼              ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │            .coding-agent/features/<slug>/   (user project)       │
  │                                                                  │
  │  intent.md  spec.md  plan.md  work.md  review.md  diagnosis.md   │
  │  screenshots/                                                    │
  └──────────────────────────────────────────────────────────────────┘
```

**Single dispatch tool** — only the Orchestrator has the `Agent` tool. Subagents return artifacts + structured YAML payloads; they never call each other. Subagent AskUserQuestion does NOT reach the real user (stays in subagent context), which is why only the Orchestrator gates user approvals.

## The four primitives

```
┌─────────────────────────────────────────────────────────────────────┐
│                           PRIMITIVES                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ACTOR       produces work       User + 5 agents                    │
│  ARTIFACT    durable typed state intent/spec/plan/work/review/...   │
│  SKILL       scoped knowledge    domain / practice / protocol-help  │
│  CHECK       deterministic verify bash scripts, JSON output         │
│                                                                     │
│  Composites (not primitives, just compositions):                    │
│  PROTOCOL    named {Actor→Artifact}+Checks workflow                 │
│  SESSION     live Protocol instance                                 │
│  PIPELINE    default Protocol for shipping features                 │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Pipeline (the default Protocol)

```
                  intake
                    │
                    │ AskUserQuestion (Gate 1: Intent)
                    ▼
  intent.md (state: approved, approved_by: user)
                    │
                    │ dispatch Architect (phase=SPEC)
                    ▼
               spec-writing
                    │
                    │ architect writes spec.md (state: draft)
                    │ orchestrator prints spec in chat
                    │ AskUserQuestion (Gate 2: Spec)
                    ▼
   spec.md (state: approved, approved_by: user, IMMUTABLE forever)
                    │
                    │ dispatch Architect (phase=PLAN)
                    ▼
               plan-writing
                    │
                    │ architect writes plan.md (state: draft)
                    │ orchestrator prints plan in chat
                    │ AskUserQuestion (Gate 3: Plan)
                    ▼
   plan.md (state: approved, approved_by: user, IMMUTABLE forever)
                    │
                    │ orchestrator creates work.md (active)
                    │ dispatch Implementor(s) (serial or parallel per plan)
                    ▼
              implementation
                    │
                    │ implementor returns structured updates
                    │ orchestrator applies to work.md
                    │
                    │ revisions (status: pending)? ───→ revision classify
                    │                                        │
                    │ ◄───────────── approve / architect / user ┘
                    ▼
                  review
                    │
                    │ evaluator runs npm test / integration / e2e
                    │ evaluator drives Playwright for UI (required)
                    │ writes review.md (PASS | FAIL)
                    ▼
              ┌─────┴─────┐
              ▼           ▼
           PASS         FAIL ────→ fix-round (Round 1 → 2 → 3)
              │
              │ close-out (8 steps)
              │  1. freeze feature dir → archived
              │  2. distill to learnings.md
              │  3. update AGENTS.md (if conventions changed)
              │  4. update ARCHITECTURE.md (if architecture changed)
              │  5. clear CURRENT
              │  6. update session.md Checkpoint
              │  7. append close-out entry to Action Log
              │  8. run all close-out checks
              ▼
          commit gate (Gate 4: Push)
              │
              │ orchestrator shows diff + commit message
              │ AskUserQuestion (approve push / local-only / redo)
              ▼
            DONE
```

**Four user gates** total per medium feature: Intent, Spec, Plan, Push. Plus Architect's discovery-Q&A bundle (one `AskUserQuestion` at start of spec-writing). Touch-up skips Gate 2 and Gate 3. Micro skips all but intent + push.

## Artifact lifecycle and mutability

```
    ┌──────────┐  author signs   ┌────────────┐  work begins  ┌──────────┐  close-out  ┌──────────┐
    │  draft   │ ─────────────► │  approved  │ ─────────────►│  active  │ ───────────►│ archived │
    └──────────┘                 └────────────┘                └──────────┘              └──────────┘
       mutable                    IMMUTABLE                   mutable per                IMMUTABLE
                                                              mutability class           forever
```

Mutability class is declared in each artifact's frontmatter:

| Class | Rule | Examples |
|-------|------|----------|
| `immutable` | Never written after state transition | spec.md, plan.md, intent.md (approved); review.md, diagnosis.md (active); any archived artifact |
| `append-only` | Writes only add content; never modify existing | learnings.md, session.md Action Log |
| `single-writer-mutable` | One declared writer can edit any part | work.md, session.md Checkpoint, cache.json, CURRENT |
| `composite` | Multiple sections, each with own class | session.md |

### Supersession (how to change an immutable artifact)

Approved `spec.md` / `plan.md` are immutable **forever**. If wave work reveals the plan needs to change, we do NOT edit `plan.md` — the change goes into `work.md § Plan Revisions` with `Supersedes: plan.md §<section>` as a pointer. Readers (next Implementor, Evaluator) consult both: `plan.md` for the base contract, `work.md` for approved amendments. Original signatures stay meaningful.

```
  plan.md (approved_by: user, IMMUTABLE)
     ▲
     │ supersedes
     │
  work.md § Plan Revisions
     R-1: Supersedes: plan.md §Wave 2 T-5
          Change: use in-memory LRU instead of Redis
          Why: target env has no managed Redis
          Status: approved by user   ← orchestrator signs after AskUserQuestion
```

## Where Checks fire

```
         ┌──────────── Input (before an actor runs) ─────────────┐
         │                                                       │
         │   intent-approved ─────────────┐                      │
         │                                │ before architect dispatch
         │   spec-approved ───────────────┤                      │
         │                                │ before implementor dispatch
         │   plan-approved ───────────────┤                      │
         │                                │                      │
         │   revisions-resolved ──────────┘ before next wave     │
         │                                                       │
         └───────────────────────────────────────────────────────┘

         ┌──────────── Output (after an actor returns) ──────────┐
         │                                                       │
         │   review-has-required-sections                        │
         │   tests-actually-committed                            │
         │   no-raw-print (on changed files)                     │
         │                                                       │
         └───────────────────────────────────────────────────────┘

         ┌──────────── Invariant (continuous) ───────────────────┐
         │                                                       │
         │   active-feature-consistent                           │
         │   action-logged                                       │
         │                                                       │
         └───────────────────────────────────────────────────────┘

         ┌──────────── Evidence (guards a transition) ───────────┐
         │                                                       │
         │   ui-evidence   ─── required before review PASS       │
         │                       on UI projects                  │
         │   close-out-complete ─ required before commit gate    │
         │                                                       │
         └───────────────────────────────────────────────────────┘
```

All checks exit 0 (ok) or 1 (fail) with a JSON line to stdout. Failed checks block transitions.

## Fix-round escalation

```
  review FAIL  ─────────────────► Round 1: re-implement with findings
                                     │
                                     │ FAIL again (same symptom)
                                     ▼
                                  Round 2: debugger
                                     │
                                     ├── inspection mode ──→ 10-line note, orchestrator applies
                                     └── full mode      ──→ diagnosis.md, implementor re-dispatched
                                     │
                                     │ FAIL again
                                     ▼
                                  Round 3: escalate
                                     │
                                     │ orchestrator writes session.md checkpoint
                                     │ AskUserQuestion: take over / new direction /
                                     │                  abandon / /clear and resume
                                     ▼
                                  USER decides
```

## Memory scopes

```
┌────────────────────────────────┐          ┌────────────────────────────────┐
│   PROJECT memory               │          │   GLOBAL memory                │
│   .coding-agent/   (gitignored)│          │   ~/.coding-agent/             │
├────────────────────────────────┤          ├────────────────────────────────┤
│                                │          │                                │
│  CURRENT                       │          │  profile.md                    │
│  session.md (checkpoint + log) │          │    - default stack preferences │
│  learnings.md                  │          │    - speed dial                │
│  decisions.md (optional)       │          │    - per-domain defaults       │
│  cache.json                    │          │                                │
│                                │          │                                │
│  features/                     │          │                                │
│    <slug>/                     │          │                                │
│      intent.md   spec.md       │          │                                │
│      plan.md    work.md        │          │                                │
│      review.md  diagnosis.md?  │          │                                │
│      screenshots/              │          │                                │
│                                │          │                                │
└────────────────────────────────┘          └────────────────────────────────┘
          read on every                              read on every
          session start                              session across repos
```

**Cross-project breadcrumbs** — was considered, dropped. Project learnings per repo + global profile is sufficient. May reintroduce later if real usage shows demand.

## Plugin file layout (after v2)

```
coding-agent/
├── .claude-plugin/plugin.json           ← manifest, v2.0.0
├── .mcp.json                            ← 7 MCP servers
├── agents/                              ← 5 rewritten prompts (each ~150 lines)
│   ├── orchestrator.md  architect.md  implementor.md  evaluator.md  debugger.md
├── skills/                              ← ~58 scoped-knowledge modules
│   ├── frontend/  backend/  data/  mobile/  infra/  general/  practices/
├── protocols/                           ← 9 named workflows (one source of truth each)
│   ├── intake.md   spec-writing.md   plan-writing.md   implementation.md
│   ├── review.md   fix-round.md   close-out.md   redirect.md   recovery.md
│   └── README.md
├── checks/                              ← 10 deterministic verification scripts
│   ├── lib.sh
│   ├── intent-approved.sh   spec-approved.sh   plan-approved.sh
│   ├── ui-evidence.sh   no-raw-print.sh   close-out-complete.sh
│   ├── action-logged.sh   active-feature-consistent.sh   revisions-resolved.sh
├── templates/                           ← artifact frontmatter stubs
│   ├── intent.template.md   spec.template.md   plan.template.md
│   ├── work.template.md   review.template.md   diagnosis.template.md
│   ├── session.template.md
├── hooks/hooks.json                     ← SubagentStart logging + PostToolUse validate
├── scripts/
│   ├── setup.sh                         ← one-command per-project installer
│   ├── validate.sh                      ← plugin self-validator
│   └── post-edit-validate.sh
├── docs/
│   └── redesign/                        ← v2 formal design docs
│       ├── primitives.md  workflow-spec.md  lifecycle.md
├── CHANGELOG.md
├── CLAUDE.md
├── README.md
├── ARCHITECTURE.md                      ← this file
└── AGENTS.md
```

## Path resolution

| Reference | Path pattern | When |
|-----------|--------------|------|
| Plugin internal (protocols, checks, templates, design docs) | `${CLAUDE_PLUGIN_ROOT}/...` | Always — survives marketplace caching |
| User project artifacts | `.coding-agent/...` (relative to project root) | During pipeline runs |
| Global memory | `~/.coding-agent/profile.md` | Session start, across repos |

**Never use `../` relative paths** — they break after marketplace caching copies the plugin into `~/.claude/plugins/cache/`.

## Model tier

| Agent | Model |
|-------|-------|
| Orchestrator | `claude-opus-4-7` (pinned) |
| Architect | `opus` |
| Evaluator | `opus` |
| Debugger | `opus` |
| Implementor | `sonnet` |

Model tuning (haiku-orchestrator, sonnet-evaluator-lightweight) is an open optimization — measured after real-run data.

## See also

- `docs/redesign/primitives.md` — formal primitive definitions and invariants
- `docs/redesign/workflow-spec.md` — canonical happy path + edge flows
- `docs/redesign/lifecycle.md` — artifact states, close-out protocol, named protocols table
- `/Users/suraj-devloper/workspace/test-agents/V2-ACCEPTANCE-TESTS.md` — acceptance suite
- `CHANGELOG.md` — version history
