# Protocol — Recovery

**Entry:** dispatch threshold reached, user-visible complexity, Round 3 escalation, mid-edit pivot, OR session restart.
**Exit:** session.md checkpoint written; on restart, fresh orchestrator can resume.
**Owner:** Orchestrator.

## When to trigger

| Signal | Threshold | Action |
|--------|-----------|--------|
| Dispatches since last `compact` | ≥ 12 | Suggest `/compact` to user with phase-specific steering text |
| Phase transition (spec→plan, plan→implement) | always | Suggest compact if dispatches ≥ 5 since last compact |
| Round 3 escalation | always | Write checkpoint; suggest `/clear` as one of the escalation options |
| User pivots mid-pipeline | always | Write checkpoint even if user doesn't `/clear` |
| Mid-edit on multi-step inline work (3+ Edits without dispatch) | always | Update `session.md § Checkpoint.resume_hint` after each step |

## Compact suggestion

`/compact` is **user-only**. Orchestrator cannot invoke it. Orchestrator's responsibility is to detect the signal and surface the suggestion via `AskUserQuestion` with a ready-to-paste steering string:

> *"Context is heavy (12 dispatches since last compact). Suggest:*
> *`/compact focus on open findings from work.md and review.md. Drop completed dispatch transcripts.`*
> *Run /compact now? (yes / not yet / never-this-session)"*

## Checkpoint write

Update `session.md § Checkpoint` (overwrites; mutable section):

```markdown
## Checkpoint
active_feature: <slug or none>
phase: <current state machine state>
last_completed: <slug @ ts or none>
dispatches_since_compact: <N>
pending_pushes: <N>
resume_hint: "pick up at wave 2 T-4 (implementor was last dispatched 14:42)"
```

Append to `## Action Log`:
```
<ISO-ts> | recovery | checkpoint written | reason: <signal>
```

## Resume

On session start:

1. Read `session.md § Checkpoint`.
2. If `active_feature: none` and `phase: idle` → fresh start.
3. If `active_feature: <slug>` and `phase: <state>`:
   - Load `features/<slug>/intent.md` (request restated)
   - Load `work.md` (in-flight ledger, last task states)
   - Read action-log tail (last 20 lines, for context)
   - Surface to user:
     > *"Resuming <slug>. Phase: <state>. Last action: <action-log tail line>. Continue / status only / abandon?"*

## Hard rules

- **session.md is the single source of resume truth.** Action log gives context; checkpoint gives state.
- **Orchestrator never auto-runs `/compact` or `/clear`.** Always proposes via `AskUserQuestion`.
- **Cache preflights** (`.coding-agent/cache.json`) — MCP availability, UI detection, stack — refreshed once per session, read on every dispatch decision.

## Checks fired

| Check | When |
|-------|------|
| `session-state-consistent` | session start |
| `action-logged` | continuous |
