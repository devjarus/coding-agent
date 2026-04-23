# Workflow Spec

The canonical session flow for the redesigned plugin, expressed in terms of the four primitives (`docs/concepts/primitives.md`). This is the authoritative reference for how a feature ships from request to commit.

## Overview

```
User typed request
      │
      ▼
  Intake ─── (approval) ───> Intent signed
      │
      ▼
  Spec-writing ── (approval) ───> spec.md signed
      │
      ▼
  Plan-writing ── (approval) ───> plan.md signed
      │
      ▼
  Implementation (serial by default; parallel only where plan declares)
      │
      ▼
  Review ── PASS ───> Close-out ───> Commit local ── (approval) ───> Push
           │
           └── FAIL ───> Fix-round ───> Review
```

Four User-facing gates: **Intent, Spec, Plan, Push**. Everything else is automated with deterministic Checks.

## Session Start (T=0)

### What loads automatically

| Artifact | Scope | Purpose |
|----------|-------|---------|
| `~/.coding-agent/profile.md` | Global | User preferences, default stacks per domain |
| `.coding-agent/session.md` | Project | Where we left off |
| `.coding-agent/CURRENT` | Project | Active feature slug (empty if none) |
| Last `features/<recent>/review.md` | Project | Yesterday's outcome |
| `.coding-agent/learnings.md` | Project | Cumulative project gotchas |
| `AGENTS.md` (project root) | Project | Stack, conventions, test commands |

### First output

Orchestrator emits a five-line summary:

```
Resumed. Last: shipped notifications-v1 (2026-04-19, 3 findings fixed, 0 nits).
Active: none. Project: deep-research-agent (Next 15, shadcn, TanStack, Postgres).
Profile: devjarus-default. Open PRs: 0. Ready.
```

### Checks at session start

- `session-state-consistent` — `CURRENT` points to an existing feature dir or is empty
- `profile-loaded` — `~/.coding-agent/profile.md` exists; if missing, Orchestrator prompts User to initialize on first feature

---

## T=1 — Intake

User types a request. Orchestrator responds with:

1. **Restatement** (one paragraph): "You want X, constrained by Y, in the context of Z (from AGENTS.md)."
2. **Path proposal**:
   - Mode: `feature` / `touch-up` / `refactor`
   - Size: `micro` / `small` / `medium` / `large`
   - Gates this pass: Intent → Spec → Plan → Push (or reduced for touch-up)
   - Estimated waves
3. **`AskUserQuestion`** — approve / redirect / cancel.

### Intent artifact

On approval, Orchestrator writes `intent.md`:

```markdown
---
artifact: intent
feature: notifications-v1
writer: orchestrator
mutability: immutable
state: approved
approved_by: user
approved_at: 2026-04-20T14:32:00Z
supersedes: null
mode: feature
size: medium
---

# Intent

## Request (verbatim)
"add notifications to the app"

## Restated
Add push + in-app notifications for comment replies and mentions. Must persist
read state per-user. Existing Postgres user schema is the source of truth.

## Path
Gates: Intent ✓ | Spec | Plan | Push
Waves: ~3 (schema, API, UI+realtime)
```

### Check

- `intent-approved` — `intent.md` has `approved_by: user` footer before Architect is dispatched

### Touch-up mode

Collapses to: restate → `AskUserQuestion` → direct Implementor dispatch → Evaluator smoke → commit-local → push approval. No spec/plan gates. Still writes `intent.md` (keeps audit trail).

---

## T=2–3 — Spec-writing

### Step A — Profile-driven discovery

Architect reads the profile. For any unknown the profile can't answer, bundles all questions into one `AskUserQuestion` with profile defaults bolded:

> *I'll build this with: **Next 15** (profile default), **shadcn** (profile), **TanStack Query** (profile), **json-render** if AI output ✓. Decisions needed:*
> *(1) Delivery — **push + in-app** / email / push only?*
> *(2) Read state — **per-user with last-read timestamps** / thread-level?*
> *(3) Backfill old users — **dual-write 1 week** / hard cutover?*
> *Confirm or change in one reply.*

### Step B — Test infrastructure research

Architect researches the right test tools for each external dep via MCPs (Context7, Exa, DeepWiki). Records:

```markdown
## Test Infrastructure

| Dep | Tool | Why (tradeoff) | Source |
|-----|------|----------------|--------|
| Postgres | testcontainers | Catches migration bugs; ~3s CI overhead | Context7 (drizzle), Exa 2026 |
| WebSocket realtime | in-process ws + test client | No sandbox needed; avoids fake drift | Context7 (ws) |
| Push provider (FCM) | recorded fixtures via msw | FCM has no dev sandbox | Exa 2026 |
```

### Step C — Write spec.md

```markdown
---
artifact: spec
feature: notifications-v1
writer: architect
mutability: immutable
state: approved
approved_by: user
approved_at: 2026-04-20T14:45:00Z
supersedes: null
---

# Spec

## Tech Stack
| Area | Chosen | Alternatives | Why |
|------|--------|--------------|-----|
| Realtime | WebSocket via Fastify | SSE, polling | Bidirectional, lower latency |
| Push | FCM | APNS-only, OneSignal | Free tier, Android priority |
| Persist | Postgres (existing users table + new notifications, notification_reads) | Redis-only | Source of truth stays where user schema lives |

## Requirements
FR-1: System emits a notification when user is mentioned in a comment.
FR-2: Notifications are delivered via push (if device token) and in-app (always).
FR-3: Read state persists per (user, notification) pair.
...

## Technical Risks
- FCM device tokens expire silently → invalidation path needed
- WebSocket reconnect storm on deploy → graceful shutdown protocol required

## Non-Goals
- Email delivery (deferred to v2)
- Notification grouping / digest (deferred)
```

### Step D — Print + approve

Architect prints the spec in chat, calls `AskUserQuestion`. User approves or requests changes.

### Checks

- `stack-justified` — `spec.md` has `## Tech Stack` with ≥1 alternative per row
- `test-infra-declared` — `spec.md` has `## Test Infrastructure` with ≥1 row per external dep
- `spec-approved` — footer present

---

## T=4 — Plan-writing

Architect writes `plan.md` with per-task Skill manifests and per-wave Test requirements.

```markdown
---
artifact: plan
feature: notifications-v1
writer: architect
mutability: immutable
state: approved
approved_by: user
approved_at: 2026-04-20T15:10:00Z
supersedes: null
---

# Plan

## Wave 1 — Schema & Config (serial)
### T-1 — notifications + notification_reads migration
domain_tags: [data, postgres]
skills: [postgres-specialist, migration-safety, tdd]
acceptance:
  - Migration applies on empty DB and existing DB (with users)
  - Rollback migration exists and is idempotent
evaluation:
  - Unit: column types, constraints via SQL assertions
  - Integration: testcontainers postgres, migration + rollback
  - E2E: N/A (no user-facing surface yet)

### T-2 — env config for FCM keys
domain_tags: [backend, config]
skills: [config-management, nodejs-specialist, tdd]
...

## Wave 2 — API (parallel subsets allowed)
Serial by default. Parallel subsets:
  parallel: [T-3 signing-helper, T-4 route-handler-structure]  # disjoint files

### T-3 — FCM client adapter
domain_tags: [backend, nodejs, http-client]
skills: [nodejs-specialist, api-design, test-doubles-strategy, tdd, observability]
acceptance:
  - Wrapper interface PushGateway; only file importing fcm-admin
  - Token invalidation path implemented
evaluation:
  - Unit: mock PushGateway at boundary
  - Integration: msw with recorded FCM fixtures
  - E2E: N/A

### T-4 — notification route handlers
... (similar structure)

### T-5 — websocket realtime channel
... (depends on T-3 and T-4 complete; not in parallel set)

## Wave 3 — UI & flow (serial)
### T-6 — shadcn notification bell + popover
domain_tags: [frontend, react, shadcn]
skills: [react-specialist, nextjs-specialist, css-tailwind-specialist, ui-excellence, tdd]
acceptance:
  - Bell count updates in realtime
  - Read state persists across reload
evaluation:
  - Unit: component state transitions
  - Integration: MSW-mocked API
  - E2E: Playwright flow — comment mention → bell increments → click → read persists
```

### Checks

- `test-tiers-covered` — each wave's tasks have unit + integration rows; e2e if UI touched (or explicit `e2e: N/A` with reason)
- `plan-approved` — footer present
- `skills-match-domain` — every task's `skills:` row references real skills for its `domain_tags`

---

## T=5 — Implementation

### Dispatch policy

- **Default: serial.** Tasks within a wave run in dispatch order.
- **Parallel: only when plan's `parallel:` block declares it.** Orchestrator fans out those tasks in one message.

### Progress tracking

Orchestrator maintains `work.md` in the feature directory. Sections:

```markdown
---
artifact: work
feature: notifications-v1
writer: orchestrator
mutability: single-writer-mutable
state: active
supersedes: null
---

# Work Ledger

## Tasks
| ID | Title | State | Assignee | Started | Finished |
|----|-------|-------|----------|---------|----------|
| T-1 | migration | complete | implementor-1 | 14:20 | 14:35 |
| T-3 | fcm-adapter | active | implementor-2 | 14:40 | — |
| T-4 | route-handler | active | implementor-3 | 14:40 | — |

## Decisions Log
| When | Who | Decision | Why |
|------|-----|----------|-----|

## Deviations (trivial)
_None_

## Plan Revisions (material — supersede plan.md sections; plan.md itself stays immutable)
_None_
<!--
Format when populated:
### R-1 — 2026-04-20 — material, approved by user
Supersedes: plan.md §Wave 2 T-5
Change: replace Redis counters with in-memory LRU
Why: target env has no managed Redis
Downstream: T-7 evaluation criterion "survives restart" → "degrades gracefully on restart"
-->


## Nits (deferred fixes)
_None_
```

One file, five sections. Replaces today's `progress.md` + `handoff.md` + `session-state.md` + `in-flight.md` + `nits.md`.

### Parallel failure handling

If one of three parallel Implementors fails:
- The other two continue to completion.
- Orchestrator updates `work.md`: failed task → `state: failed`, others progress normally.
- When all parallel tasks have returned, Orchestrator regroups and dispatches Debugger or re-Implementor for the failure.

### Implementor snag protocol

If mid-task the Implementor hits a design question the plan doesn't answer, it stops and asks the User directly via `AskUserQuestion`. Not plan-revision, not self-decide. One question, 2–3 options, continue on answer.

### Checks

- `work-ledger-consistent` — `work.md` task states match the dispatched Actors
- `revisions-resolved` — no `Status: pending` revisions before next wave dispatch
- `no-raw-print` — Evaluator Output check (but also self-run by Implementor before return)

**Plan revision supersession.** Approved `plan.md` is immutable. If wave work reveals the plan needs to change, the revision lives in `work.md` `## Plan Revisions`, with `Supersedes: plan.md §<section>` referencing the original. Readers (Evaluator, next Implementor dispatch) consult both files — `plan.md` for the base contract, `work.md` for approved amendments. Same applies to spec-level changes (rare, but possible): amendment in `work.md`, spec.md untouched.

**Why not edit plan.md in place.** Because approval semantics would dissolve. Once the User signs `approved_by: user`, that signature must remain meaningful. Editing the approved body rewrites history. Supersession preserves the record of what was approved when, and what was amended by whom.

---

## T=6 — Review

### Default mode: Lightweight

Evaluator runs:
1. `npm test` (or project's test command from AGENTS.md)
2. `npm run test:integration`
3. `npm run test:e2e` if UI was touched
4. `no-raw-print` grep on changed files
5. Spec-compliance check for FRs in scope
6. Runtime check **only if UI changed** — Playwright MCP launches, takes named screenshots, writes to `features/<slug>/screenshots/`
7. Write `review.md`

### Mode escalation

- Smoke (Micro) — `npm test` + typecheck only, 50-word reply
- Lightweight (Small, default) — as above
- Full (Medium/Large, or prior-feature regressions) — add full spec-compliance table + regression check against last `review.md`

### No ad-hoc scripts

The Evaluator **invokes committed test suites**. It does not write curl pipelines, openssl signing dances, or `sleep 7` bash. If a test suite doesn't cover a scenario the Evaluator needs to verify, that is itself a finding:

```markdown
| ID | Severity | Finding | Fix direction |
|----|----------|---------|---------------|
| F-4 | **FAIL** | webhook signature verification has no integration test | Add `tests/api/webhook.integration.test.ts` with fastify.inject + real signing helper |
```

### Checks

- `tests-actually-committed` — test files the plan promised exist on disk
- `ui-screenshots-exist` — if UI project, `screenshots/` non-empty; named files
- `review-has-required-sections` — `## Status`, `## Findings`, `## Dispatch Recommendation`

### FAIL branches into fix-round

See `lifecycle.md` (Fix-round Protocol).

---

## T=7 — Close-out & Commit

### Close-out Protocol

On PASS, Orchestrator runs Close-out (see `lifecycle.md` for details):

1. Freeze feature dir (archived state)
2. Distill to `learnings.md` (project memory)
3. Update `AGENTS.md` / `ARCHITECTURE.md` if conventions/architecture changed
4. Clear `CURRENT`
5. Update `session.md`

### Commit

Orchestrator shows diff + commit message in chat. `AskUserQuestion` — approve push / commit-local-only / redo message.

```
feat(notifications): push + in-app for mentions

Ships FR-1 through FR-3. Delivery via FCM (fallback to in-app).
WebSocket reconnect logic handles deploy storms with jittered backoff.

Learnings:
- FCM device tokens silently expire on Android 14 → rebuild on 'token refreshed' event
- Testcontainers Postgres startup adds 3s; acceptable; kept in CI

Co-authored-by: Claude <noreply@anthropic.com>
```

Commit is always local-first. Push only after approval (your T=7c answer).

### Checks

- `close-out-complete` — all 5 close-out steps ran
- `commit-has-learnings` — commit message body contains a `Learnings:` block for Medium/Large features

---

## T=8 — Next feature (same session)

User says: *"now add feature B"*.

- Previous feature is already closed out (from T=7).
- Orchestrator generates new slug, `mkdir features/<new-slug>/`, writes slug into `CURRENT`.
- Context is carried over (your T=8b answer) — learnings.md and last review.md inform Intent.
- If B's Intent restatement touches files/modules that A just changed, Orchestrator notes it explicitly in the restatement ("this overlaps with files touched by `notifications-v1`: X, Y").
- No enforced checkpoint; user chooses whether to `/compact`.

### Checks

- `active-feature-consistent` — `CURRENT` is either empty OR points to a feature directory whose artifacts are in `active` or `draft` state. If `CURRENT` points to a directory whose artifacts are all `archived`, close-out failed to clear `CURRENT` — Orchestrator self-repairs by clearing `CURRENT`. (We never have two active features by construction: close-out runs and clears `CURRENT` before any next-feature dispatch.)

---

## T=9 — Context hygiene (automatic)

Orchestrator silently maintains:
- `session.md` rewritten every 3 dispatches
- Preflights cached in `.coding-agent/cache.json` (MCP availability, UI detection, test commands) — refreshed once per session

Suggests `/compact` only at deep thresholds (12+ dispatches). Does not nag.

---

## T=10 — Next morning

User `cd`s back, runs `claude`.

```
Resumed. Last: shipped notifications-v1 on 2026-04-20.
         Then: shipped search-improvements on 2026-04-20 (same session).
Active: none. Project: deep-research-agent.
Pending: commit 7b5f5e0 is unpushed (you declined push last night).
Ready.
```

The "where we left off" is the first five lines, always. Never a cold start.

---

## Micro inline flow (orchestrator does the work itself)

Used when: single-file mechanical change, no new logic, ≤30 lines. Orchestrator edits directly without dispatching.

```
User: "rename `getUserById` to `findUserById` across the repo"
Orchestrator: [classifies: micro] → restate → AskUserQuestion
User: approves
Orchestrator: appends action-log entry | micro-start | rename refactor, ~14 call sites
              runs grep for all references
              appends action-log entry | action | grepped references (14 sites)
              makes edits via Edit tool
              appends action-log entry | action | edits applied (14 files)
              dispatches Evaluator smoke-mode
Evaluator: smoke | build+test+typecheck PASS
Orchestrator: appends action-log entry | micro | smoke PASS | commit-pending
              shows diff + commit message in chat
User: approves push
Orchestrator: commits, pushes, appends action-log entry | micro | commit <sha> | pushed
```

**Auditability:** Even though no `features/<slug>/` directory is created for Micro work, every action is appended to `session.md` action log. Later auditing "what did the orchestrator do at 16:50?" is answered by grep on the action log.

**Intent still exists.** For a Micro task, the restated intent is captured as the first action-log entry, not as a separate `intent.md`. The `AskUserQuestion` approval is the gate.

**No spec, no plan, no work.md.** Micro tasks are explicitly exempt from the feature dir protocol — their entire lifecycle fits in the action log.

**Checks that fire on Micro:**
- `action-logged` — every Orchestrator action has a corresponding log entry
- Evaluator's smoke-mode output-checks (`tests-passed`, `typecheck-clean`, `no-raw-print`)
- `commit-message-has-context` — commit message body references the micro action description

**Checks that are skipped:**
- `intent-approved` footer check — no intent.md file
- `spec-approved`, `plan-approved` — no spec/plan
- `close-out-complete` — no feature dir to close out

### Micro state machine

```
INTAKE → INLINE-EDIT → SMOKE ──pass──> COMMIT-GATE → DONE
                         │
                         └──fail──> RETRY-INLINE ──pass──> COMMIT-GATE
                                       │
                                       └──fail──> ESCALATE-TO-TOUCH-UP or USER
```

| From | Event | To | Side effect |
|------|-------|-----|-------------|
| `INTAKE` | User approves restate | `INLINE-EDIT` | Append action-log `micro-start` |
| `INLINE-EDIT` | Edits applied | `SMOKE` | Append action-log `micro-edits-applied` |
| `SMOKE` | PASS | `COMMIT-GATE` | Append action-log `micro-smoke-pass` |
| `SMOKE` | FAIL | `RETRY-INLINE` | Append action-log `micro-smoke-fail`. One retry only. |
| `RETRY-INLINE` | PASS | `COMMIT-GATE` | (one retry max) |
| `RETRY-INLINE` | FAIL | `ESCALATE-TO-TOUCH-UP` | Under-specified. Operational meaning: revert any uncommitted edits (`git checkout --` on the changed files); generate a feature slug; create `features/<slug>/`; write `CURRENT`; draft a real `intent.md` (mode: `touch-up`) in `state: draft` from the Micro request captured in the action log; enter Touch-up state machine at `INTAKE` where the orchestrator prints and AskUserQuestion-approves the drafted intent. Append action-log `micro-escalated | drafted intent.md as touch-up`. (The original Micro never had an intent.md — nothing to supersede; the new intent.md is the first signed artifact.) |
| `COMMIT-GATE` | User approves push | `DONE` | Commit + push; append action-log `micro-done`. No close-out (no feature dir). |
| `COMMIT-GATE` | User declines push | `DONE` (local only) | Commit local; update `session.md § Checkpoint.pending_pushes` |
| any | User pivots | (cancelled) | Append action-log `micro-cancelled`; revert if uncommitted (orchestrator runs `git checkout --` on the changed files); route through Redirect |

### Micro resume

If session restarts and last action-log event is `micro-edits-applied` or `micro-smoke-fail` with no follow-up:
1. Orchestrator reads action log tail
2. Finds last `micro-start` with no terminal event (`micro-done` or `micro-cancelled`)
3. Reads the description of the in-flight micro
4. Surfaces: *"Resuming micro: `<description>`. Last event: `<action-log line>`. State of working tree: clean / modified. Continue / abandon (revert) / commit-as-is?"*

### Micro abandonment

If User abandons:
- Orchestrator runs `git checkout --` on the files mentioned in the latest `micro-edits-applied` action-log entry
- Appends action-log `micro-cancelled`
- No artifacts to clean up

---

## Touch-up flow — explicit state machine

Touch-up is for small targeted changes (2–5 files, clear scope, no design decisions). Distinct from Micro (orchestrator inlines) and Small (Implementor + lightweight Evaluator with full plan). Touch-up has its own minimal feature dir with `intent.md` only.

### States

```
INTAKE → IMPLEMENT → VERIFY ──pass──> COMMIT-GATE → DONE
                       │
                       └──fail──> FIX-ROUND-1 ──pass──> COMMIT-GATE
                                       │
                                       └──fail──> ESCALATE-TO-SMALL or USER
```

### State transitions

| From | Event | To | Side effect |
|------|-------|-----|-------------|
| `INTAKE` | User approves restate | `IMPLEMENT` | Write `intent.md` (immutable, approved); create `features/<slug>/`; set `CURRENT`; append action-log `touch-up-start` |
| `IMPLEMENT` | Implementor returns `status: complete` | `VERIFY` | Append action-log `touch-up-implemented` |
| `IMPLEMENT` | Implementor returns `status: needs-input` | (paused) | Orchestrator surfaces question via `AskUserQuestion`; resume on answer |
| `IMPLEMENT` | Implementor returns `status: blocked` | `ESCALATE-TO-SMALL` or `USER` | If blocker is design-level → escalate. If technical (missing dep) → AskUserQuestion. |
| `VERIFY` | Smoke Evaluator PASS | `COMMIT-GATE` | Append action-log `touch-up-verified` |
| `VERIFY` | Smoke Evaluator FAIL | `FIX-ROUND-1` | Update `work.md § Findings` with smoke output; append action-log `touch-up-fix-round-1` |
| `FIX-ROUND-1` | Implementor returns + Smoke PASS | `COMMIT-GATE` | (one fix round only for touch-up; second failure is escalation) |
| `FIX-ROUND-1` | Implementor returns + Smoke FAIL | `ESCALATE-TO-SMALL` | Touch-up was under-specified. Operational meaning: **`intent.md` stays immutable** at its original `mode: touch-up` — the signed user approval remains truthful. Orchestrator dispatches Architect for `plan-writing` only (no `spec.md` — the touch-up intent is the contract). A new `plan.md` appears in the feature dir and the pipeline enters the Small flow from there. Effective mode is `small` by virtue of the plan existing; we do NOT rewrite intent.md. Append action-log `touch-up-escalated | added plan.md to feature <slug>`. |
| `COMMIT-GATE` | User approves push | `DONE` | Commit + push; run minimal close-out (clear `CURRENT`, append to `learnings.md` only if a real lesson was learned, archive feature dir, append action-log `touch-up-done`) |
| `COMMIT-GATE` | User declines push | `DONE` (local only) | Commit local; mark `pending_pushes` in session.md checkpoint |
| any | User pivots / new request | (suspended) | Append action-log `touch-up-suspended`; route through Redirect Protocol |

### Required artifacts

- `features/<slug>/intent.md` (immutable, approved) — only artifact required
- `features/<slug>/work.md` (single-writer-mutable) — created on entry to IMPLEMENT; holds findings if VERIFY fails
- No `spec.md`, no `plan.md` — touch-up is exempt
- `screenshots/` only if `IMPLEMENT` touched UI files

### Resume after restart

If session restarts and last session ended mid-touch-up:
1. Orchestrator reads `session.md § Checkpoint` — if `phase` ∈ {`touch-up-implement`, `touch-up-verify`, `touch-up-fix-round-1`, `touch-up-commit-gate`}, this is a resumable touch-up
2. Reads `CURRENT` for the slug, reads `intent.md` and `work.md`
3. Reads action log tail to find the last touch-up event
4. Resumes at the next state per the table above
5. Surfaces to User: *"Resuming touch-up `<slug>`: `<intent line>`. Last event: `<action-log line>`. Continue / abandon / restart?"*

### Abandonment

If User chooses to abandon a touch-up:
- Append action-log `touch-up-abandoned`
- Mark `intent.md` `state: abandoned` in frontmatter (extends the state vocab for this case)
- Move `features/<slug>/` to `features/<slug>.abandoned/`
- Clear `CURRENT`
- No close-out distillation; the feature dir is retained for forensics but never read again

### Checks specific to touch-up

| Check | Verifies |
|-------|---------|
| `touch-up-has-intent` | `features/<slug>/intent.md` exists with `state: approved` before IMPLEMENT |
| `touch-up-no-spec` | No `spec.md` or `plan.md` in the touch-up feature dir (architectural guard) |
| `touch-up-fix-rounds` | At most one `touch-up-fix-round-1` event between `touch-up-start` and `touch-up-done` (escalation otherwise) |
| `touch-up-resumable` | If `session.md § Checkpoint.phase` is a touch-up state, `CURRENT` and `intent.md` exist |

---

## Fix-round flow (short)

```
Evaluator: Status FAIL, findings F-1..F-3, dispatch_recommendation: re-implement
Orchestrator: updates work.md with findings reference
              → dispatches Implementor with findings + work.md
Implementor: fixes F-1..F-3, runs tests, returns
Evaluator: re-reviews → PASS
Orchestrator: close-out → commit gate
```

Second failure → Debugger.
Third failure → escalate to User with `AskUserQuestion` and a session checkpoint.

---

## Flow coverage summary

| Flow | Covered? |
|------|---------|
| Fresh Tuesday, known project | ✓ (T=0 through T=10) |
| Greenfield new project | Covered — profile loads; AGENTS.md auto-generated at close-out |
| Touch-up | ✓ (short flow above) |
| Multi-feature session | ✓ (T=8) |
| Conversational debugging drift | Fix-round + `repeat-symptom` check |
| Plan revision mid-implementation | work.md revisions section + `revisions-resolved` check |
| Long-running session | T=9 silent hygiene |
| Parallel + one failure | T=5 parallel failure handling |

---

## What this spec deliberately omits

- Hook-based enforcement (user preference: prompt edits + checks, not PreToolUse blockers)
- Self-modifying agents (profile updates require user confirmation)
- Cross-project breadcrumbs (dropped — project Memory is sufficient)
- Fan-out evaluator (one evaluator per review, no parallel critics)

These may be revisited later; they are not in this design.
