---
name: prototype-first
description: Build a disposable clickable mock (real frontend, fixture/JSON backend) to find product direction BEFORE speccing the real feature. Use when the user can't yet say what the product should be or feel like. Covers quarantine, mock-backend technique, round loop, graduation.
scope: any
trigger: on-match
category: practice
---

# Prototype First

A prototype answers ONE question: **"is this the right product?"** It is not an MVP, not a foundation, not "version 0." It is a disposable instrument for extracting product decisions from a user who can't articulate them in text — they can only recognize them by clicking.

## When (and when not)

| Signal | Route |
|--------|-------|
| User: "prototype it", "mock it first", "not sure what I want", "let's see how it feels" | prototype mode |
| User answers "I don't know" to the architect's product-shape discovery questions | orchestrator OFFERS prototype mode (never auto-enters) |
| Direction is known, user can evaluate a spec by reading it | normal pipeline — a prototype here is waste |
| Question is technical feasibility ("can we even do X?") | NOT this mode — that's a spike; decision memo, not a clickable UI (out of scope here) |

## Quarantine — the non-negotiables

The classic failure: the prototype quietly becomes production. Mechanics:

1. **Everything lives in top-level `prototype/`** — its own self-contained app (own package.json, own dev server). Nothing outside it changes.
2. **`prototype/README.md` first line:** `# DISPOSABLE PROTOTYPE — judged, never shipped. Do not extend into production. Do not import from this directory.`
3. **Production code NEVER imports from `prototype/`.** Copying a snippet into `src/` consciously is allowed — it then faces the real gates (review, tests). Importing is not.
4. **Graduation deletes `prototype/`** in a normal commit. Git history is the archive — no archive dir, no "just keeping it around."
5. The orchestrator refuses to run feature close-out on source living in `prototype/`.

## Build shape

- **Frontend: real.** Use the project's intended UI stack if known (the feel must be honest), else the fastest familiar stack (e.g. Vite + React). Load the relevant frontend specialist skills.
- **Backend: fake, declared, deterministic.**
  - Static fixture JSON imported directly — default; zero moving parts.
  - `msw` (route-level mocking in the browser) — when request/response *shape* matters to the feel (latency, errors, optimistic updates).
  - `json-server` — when the user should feel persistence across clicks (CRUD that sticks).
  - Seed data is committed and deterministic — every round, same data, so feedback diffs cleanly round-over-round.
- **The fixture shapes ARE the proto-contract.** Design them as if they were the API: real field names, realistic values, error and empty variants. At graduation they seed the real spec's API section — this is the prototype's second-most-valuable output after the product decisions.
- **Skip:** TDD, evaluator review, spec/plan gates, `docs-current`. **Keep:** one self-check per round — the app builds and renders without console errors (a user clicking a dead app wastes the round, the scarcest resource in this mode).

## Round loop

Each round: build/revise → user clicks around → feedback (chat, or the design-review surface pointed at the prototype's screens) → orchestrator logs decisions → next round. Every round ends with ONE forcing question:

> **continue** (what to change) / **pivot** (different concept, same quarantine) / **graduate** / **abandon**

Log each answer to `work.md § Decisions` — "round 2: killed dashboard concept, sidebar nav won." These lines are the product. At round 4+, the orchestrator must ask: "what's still unknown that another round answers?"

## Graduation checklist

1. **Distill decisions** from `work.md § Decisions` into the real feature's `intent.md` — what won, what died, why.
2. **Lift fixture JSON shapes** into the spec's API/contract section (architect refines, doesn't reinvent).
3. **Screenshot the winning screens** — they seed `design.html` (the look contract) for the real feature.
4. **Note stack verdicts** — anything learned about the UI stack goes to `learnings.md`.
5. **Delete `prototype/`** (normal commit: `proto: graduate <slug> — prototype removed, decisions distilled`).
6. **Run the real pipeline** — intake → spec → plan → implement. The spec cites the prototype's decisions; the implementor starts from `src/`, empty.

## Commits

Commit each round (`proto(round-N): <what changed>`). Cheap rollback, diffable rounds, and history preserves the whole exploration after deletion. Never claim "verified" — nothing here is.
