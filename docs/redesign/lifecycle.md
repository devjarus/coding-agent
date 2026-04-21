# Lifecycle & Protocols

Governs how Artifacts move through states, how features close out, and how the named Protocols invoke primitives. Complements `primitives.md` (the static definitions) and `workflow-spec.md` (the canonical happy path).

## Artifact States

```
draft ──(author signs)──> approved ──(work begins)──> active ──(close-out)──> archived
```

### State rules per category

| Category | Initial | Typical path | Terminal |
|----------|---------|--------------|----------|
| **Intent** | `draft` | `draft → approved → archived` | `archived` at close-out |
| **Plan** (`spec.md`, `plan.md`) | `draft` | `draft → approved → archived` | `archived` at close-out |
| **Work** (`work.md`) | `active` from creation | `active → archived` | `archived` at close-out |
| **Findings** (`review.md`, `diagnosis.md`) | `active` | `active → archived` | `archived` with the feature |
| **Memory** | `active` always | never transitions | N/A (persistent) |

### Transition rules

1. **Approved artifacts are immutable.** Never write to them. Amendments go into `work.md` via the supersession rule (see `primitives.md` § Supersession rule).
2. **Every Artifact has exactly one writer.** Declared in frontmatter. No multi-writer files.
3. **Archived artifacts are read-only.** A feature dir after close-out is a historical record. Never edited.

### Frontmatter format

See `primitives.md` § Frontmatter format for the canonical schema. Every Artifact carries `artifact / feature / writer / mutability / state / (approved_by / approved_at) / supersedes`. Checks read frontmatter only — never prose.

---

## Ownership — Who Writes What

The Orchestrator owns all coordinator state. Agent Actors own only their own output artifacts. This eliminates multi-writer races at the cost of a structured-update step on subagent return.

| Artifact | Writer | Mutability | Notes |
|---|---|---|---|
| `intent.md` | Orchestrator | immutable (after approval) | Orchestrator drafts, User approves via footer, then frozen |
| `spec.md` | Architect | immutable (after approval) | Single direct writer. Post-approval changes go to work.md |
| `plan.md` | Architect | immutable (after approval) | Same rule |
| `work.md` | **Orchestrator only** | single-writer-mutable | Subagents return structured updates; Orchestrator applies |
| `review.md` | Evaluator | immutable (once written) | Findings are not amended; corrections come through next review |
| `diagnosis.md` | Debugger | immutable (once written) | Same |
| `session.md` | Orchestrator | composite (see below) | Checkpoint section + Action Log section |
| `cache.json` | Orchestrator | single-writer-mutable | Session-scoped preflight cache |
| `CURRENT` | Orchestrator | single-writer-mutable | One line, feature slug or empty |
| `learnings.md` | Orchestrator | append-only | Written only during close-out |
| `decisions.md` | Orchestrator | append-only | Written only during close-out |
| `AGENTS.md` / `ARCHITECTURE.md` / `README.md` | Orchestrator (via project-docs skill) | single-writer-mutable | Updated only during close-out |
| `profile.md` (global) | User | single-writer-mutable | Orchestrator proposes updates via `AskUserQuestion` — never writes directly |

Diagnostic: if two Actors would want to write the same file, the design is wrong — re-decompose into distinct artifacts or consolidate through the Orchestrator.

### Subagent structured-return contract

Subagents return a single YAML block alongside their artifact writes. The Orchestrator parses it and applies the declared updates to `work.md` and `session.md` in one atomic step.

```yaml
# Subagent return payload (appended to agent's final message)
return:
  artifacts_written: [spec.md]              # files the subagent wrote directly
  status: complete | blocked | needs-input
  work_updates:                             # applied to work.md by Orchestrator
    task_states: { T-3: complete, T-4: failed }
    deviations:                             # trivial changes
      - task: T-3
        note: "renamed signing-helper to sign-payload for clarity"
    revisions:                              # material amendments (require approval)
      - supersedes: "plan.md §Wave 2 T-5"
        change: "replace Redis with in-memory LRU"
        why: "target env has no managed Redis"
        downstream: "T-7 evaluation criterion adjusted"
        status: pending
    decisions:
      - "chose msw over nock — msw has first-class v2 TS types"
    nits:                                   # deferred style-level items
      - "consider extracting webhook router into its own module (T-4)"
  ask_user:                                 # populated if status == needs-input
    question: ""
    options: []
  notes: "wave 2 api tasks complete; websocket wired; FCM adapter tested with msw fixtures"
```

Orchestrator applies rules:
- `revisions` with `status: pending` → Orchestrator classifies (approve inline / dispatch Architect / escalate to User) before the next wave dispatches
- `deviations` → appended to `work.md § Deviations`
- `decisions` → appended to `work.md § Decisions Log`
- `nits` → appended to `work.md § Nits`
- `task_states` → merged into `work.md § Tasks` table

### Session.md shape (composite artifact)

```markdown
---
artifact: session
feature: global  # session spans features
writer: orchestrator
mutability: composite
state: active
---

## Checkpoint (mutable — overwritten on update)
active_feature: none
phase: idle                              # idle | intake | spec | plan | implement | review | fix-round | close-out
last_completed: notifications-v1 @ 2026-04-20T16:42:00Z
dispatches_since_compact: 0
pending_pushes: 1 (commit 7b5f5e0)
resume_hint: null                        # or "pick up at wave 2 T-4"

## Action Log (append-only — never modified, only appended)
2026-04-20T14:10:00Z | session-start | loaded profile, AGENTS.md, learnings.md
2026-04-20T14:15:00Z | intake | feature classified medium, 3 waves proposed
2026-04-20T14:32:00Z | gate-passed | intent.md approved by user
2026-04-20T14:33:00Z | dispatch | architect (spec-writing)
2026-04-20T14:57:00Z | artifact-written | spec.md (by architect)
2026-04-20T14:58:00Z | gate-passed | spec.md approved by user
...
2026-04-20T16:42:00Z | close-out | notifications-v1 archived
2026-04-20T16:50:00Z | micro | touch-up "fix login button color" | 1 file | smoke PASS | commit 8a2c1d9
2026-04-20T17:05:00Z | micro | touch-up "tweak landing copy" | 2 files | smoke PASS | commit 4f3b7e0
```

Two sections, two mutability classes, one file. Action log is the audit trail; checkpoint is the resume pointer.

**Action log entry format:** `<ISO timestamp> | <event-type> | <one-line description>`. Event types: `session-start`, `intake`, `dispatch`, `artifact-written`, `gate-passed`, `check-failed`, `close-out`, `micro`, `escalation`, `compact-suggested`. The Orchestrator appends before each significant action; the Check `action-logged` fails if an action occurs without a corresponding log line.

---

## Close-out Protocol

Runs automatically on Evaluator PASS, before the Commit gate. Eight steps, all deterministic, all Checked.

### Step 1 — Freeze feature dir

- Mark every artifact's `state: archived` in frontmatter.
- No further writes allowed to `.coding-agent/features/<slug>/`.
- Rename preserved (slug never changes).

### Step 2 — Distill decisions

Extract stack choices, tradeoffs, and rejected options from `spec.md` `## Tech Stack` and `plan.md` `## Test Infrastructure`. Append to `.coding-agent/learnings.md` as a dated section:

```markdown
## 2026-04-20 — notifications-v1

### Decisions
- Realtime: WebSocket (rejected SSE — needed bidirectional), Fastify host
- Push: FCM (rejected APNS-only — Android priority), recorded fixtures via msw
- Persist: Postgres (rejected Redis-only — users schema is source of truth)

### Gotchas
- FCM tokens silently expire on Android 14 — handle "token refreshed" event to rebuild
- Testcontainers Postgres startup ~3s; acceptable; kept in CI
- WebSocket reconnect storms on deploy — jittered backoff required

### Patterns
- PushGateway adapter pattern — only one file imports fcm-admin; tests fake the interface
```

**Learnings file is cumulative** — newest sections at the top, older dated sections below. Never truncated.

### Step 3 — Update AGENTS.md if conventions changed

If this feature established a new project-wide convention (e.g., a logger module, a test directory pattern, a shared adapter), append to `AGENTS.md` under the relevant section. Skipped if no new convention.

### Step 4 — Update ARCHITECTURE.md if architecture changed

If a new service, database, queue, or cross-module dependency was introduced, update the ASCII diagram and narrative. Skipped otherwise.

### Step 5 — Append to decisions.md (if separate file is used)

By default, decisions live in `learnings.md` (one file, see Q1 locked answer). Skipped.

### Step 6 — Clear CURRENT

```bash
: > .coding-agent/CURRENT
```

After this, the repo has no active feature. User can start a new one.

### Step 7 — Update session.md

Overwrite the Checkpoint section only (the Action Log is append-only and untouched). Add one action-log entry for the close-out event.

```markdown
## Checkpoint (mutable)
active_feature: none
phase: idle
last_completed: notifications-v1 @ 2026-04-20T16:42:00Z
dispatches_since_compact: 0
pending_pushes: 1 (commit 7b5f5e0)

## Action Log (append-only) — new entry
2026-04-20T16:42:00Z | close-out | notifications-v1 archived | 3 waves | 7 tasks | 0 nits
```

### Step 8 — Run Checks

Before commit gate is opened:

| Check | Verifies |
|-------|---------|
| `close-out-frozen` | Every artifact in feature dir has `state: archived` |
| `learnings-appended` | `learnings.md` has an entry dated today |
| `current-cleared` | `.coding-agent/CURRENT` is empty |
| `session-updated` | `session.md` Checkpoint timestamp is from this session AND action log has a `close-out` entry |
| `no-draft-artifacts` | No lingering `draft` state in feature dir |
| `action-logged` | Every significant Orchestrator action has a corresponding action-log entry (runs continuously, not just at close-out) |

If any Check fails, Orchestrator self-repairs (re-runs the failed step) or escalates to User.

---

## Fix-Round Protocol

Triggers on `review.md` `Status: FAIL`. Three rounds before escalation.

### Round 1 — Re-implement

```
Evaluator FAIL → Orchestrator updates work.md with findings
              → dispatches Implementor
                 prompt: "findings F-1..F-N, work.md path, plan.md path"
Implementor fixes → Evaluator re-runs → PASS or Round 2
```

### Round 2 — Debugger

Same symptom or related failure recurs after Round 1.

```
Orchestrator writes work.md "## Handoff" section:
  - what was tried in Round 1
  - why it failed (evaluator findings quoted)
  - ruled-out approaches
Dispatches Debugger → writes diagnosis.md
Dispatches Implementor with diagnosis.md as input
Evaluator re-runs → PASS or Round 3
```

### Round 3 — Escalate

```
Orchestrator updates session.md with full context
Orchestrator:
  - AskUserQuestion with options: (a) take over, (b) new direction,
    (c) abandon feature, (d) /clear and resume
  - includes link to diagnosis.md and work.md Handoff section
User decides.
```

### Checks

- `fix-round-count` — tracked in `work.md`; forces Round 2 path on recurrence, not repeated Round 1
- `handoff-written` — work.md has Handoff section before Round 2 dispatch
- `diagnosis-consumed` — Implementor dispatch in Round 2 references diagnosis.md path

---

## Redirect Protocol

When the User sends a new message while a pipeline is active (not after close-out).

### Classify the message

| Kind | Signals | Action |
|------|---------|--------|
| **Feedback on current work** | References in-flight tasks, fixes, corrections | Fold into current fix-round or active wave as additional findings in `work.md`. No new artifact. |
| **Scope change** | Adds a requirement, removes one, changes a tradeoff | Append a `revision` entry to `work.md § Plan Revisions` with `Supersedes:` pointing to the affected `plan.md` or `spec.md` section. **`plan.md` and `spec.md` are never edited.** Orchestrator classifies the revision (approve inline / dispatch Architect to think it through / escalate to User). If Architect is dispatched, Architect proposes amendments by appending to the same `work.md § Plan Revisions` block (Architect does NOT touch `plan.md`). User approves the revision through `AskUserQuestion`; Orchestrator marks `status: approved` in `work.md`. |
| **Pivot** | Entirely new feature, previous feature abandoned | Write `session.md` checkpoint, append action-log entry `pivot-requested`, AskUserQuestion: "abandon current feature (mark `state: abandoned` in work.md, archive feature dir as `<slug>/abandoned`) or close out first (run review + close-out protocol)?" |

### Implementation

Redirect classification runs **first** on any new message during an active pipeline. Orchestrator does not guess the path; if classification is ambiguous, `AskUserQuestion`.

### Checks

- `redirect-classified` — no User message during active pipeline is processed without an explicit classification recorded in `work.md Decisions Log`

---

## Recovery Protocol

Handles `/compact`, `/clear`, and `Esc Esc` rewind. Slash commands are User-only (documented; agents cannot invoke). The Orchestrator's job is:

1. **Watch for signals:** dispatch count, phase transition, Round 3 escalation, user-visible complexity.
2. **Suggest** via `AskUserQuestion` with a ready-to-paste compact prompt.
3. **Write checkpoints** (`session.md`, `work.md`) so that if the user does `/compact` or `/clear`, the fresh session has enough to resume.

### Signals and thresholds

| Signal | Threshold | Action |
|--------|-----------|--------|
| Dispatch count since session start | ≥ 12 | Suggest `/compact` with phase-specific steering |
| Phase transition (spec→plan, plan→implement) | always | Suggest compact if dispatches ≥ 5 |
| Round 3 escalation | always | Write session.md, suggest `/clear` as option (c) in escalation question |
| User pivots mid-pipeline | always | Write session.md checkpoint even if User doesn't clear |

### Resume flow

On session start, Orchestrator reads `session.md` first. If it describes an in-progress state, the Orchestrator's "where we left off" line says so:

```
Resumed. In-flight: notifications-v1, wave 2, T-4 route-handler (implementor-3 was dispatched).
Pick up where left off? (yes / redispatch / status-only)
```

---

## Session Hygiene Protocol

Runs continuously in the background. No user interaction.

### Cache preflights

`.coding-agent/cache.json`:

```json
{
  "mcp_playwright": { "ok": true, "probed_at": "2026-04-20T14:30:00Z" },
  "mcp_ios_simulator": { "ok": false, "reason": "no xcodeproj in this repo" },
  "ui_detected": { "web": true, "ios": false },
  "stack": { "runtime": "node", "framework": "next", "test_runner": "vitest" },
  "agents_md_probed": true,
  "probed_at": "2026-04-20T14:30:00Z"
}
```

- Cache is read on every Orchestrator tick; refreshed only if stale (>1 session) or explicitly invalidated.
- Preflight probes (package.json check, MCP availability test) run once per session, not per dispatch.

### work.md checkpointing

After every Actor return, Orchestrator updates `work.md` task states. This is the "in-flight position" — if the session is compacted mid-task, `work.md` tells the next Orchestrator which task to pick up.

---

## Protocols — named workflows summary

| Name | Entry | Exit | Files touched |
|------|-------|------|--------------|
| **intake** | user message | intent.md approved | intent.md |
| **spec-writing** | intent approved | spec.md approved | spec.md (+ MCP queries) |
| **plan-writing** | spec approved | plan.md approved | plan.md (+ MCP queries) |
| **implementation** | plan approved | all tasks complete | code files, test files, work.md |
| **review** | implementation complete | review.md written | review.md, screenshots/ |
| **fix-round** | review FAIL | review PASS or escalation | work.md, diagnosis.md (round 2) |
| **close-out** | review PASS | commit gate opened | feature dir → archived, learnings.md, AGENTS.md, ARCHITECTURE.md, CURRENT, session.md |
| **redirect** | user message during active pipeline | classified + routed | work.md Decisions Log |
| **recovery** | dispatch threshold or user pivot | checkpoint written | session.md, work.md |

Each Protocol lives in `protocols/<name>.md` as the authoritative reference. Agent prompts reference the Protocol by name, not by copied prose.

---

## Summary

The lifecycle layer adds three things on top of primitives:

1. **Artifact states** — draft → approved → active → archived, enforced via frontmatter Checks
2. **Close-out Protocol** — automatic 8-step distillation on PASS, before commit
3. **Named Protocols** — 9 workflows extracted from agent prompts into `protocols/*.md` so they are authored once, referenced everywhere

Together with `primitives.md` and `workflow-spec.md`, this is the complete design. Implementation migrates existing agents to reference these.
