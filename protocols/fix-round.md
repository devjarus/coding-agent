# Protocol — Fix Round

**Entry:** `review.md` `Status: FAIL`.
**Exit:** `review.md` `Status: PASS` OR Round 3 escalation to user.
**Owner:** Orchestrator.

## Round 1 — Re-implement

1. Read `review.md` `Findings` and `Dispatch Recommendation`.
2. Update `work.md § Findings` with the review IDs and severities.
3. **Dispatch Implementor** with: findings list, paths to `review.md` and `work.md`, paths to changed files.
4. Implementor returns → re-run `review` protocol.
5. PASS → close-out. FAIL → Round 2.

## Round 2 — Debugger

1. Append to `work.md § Handoff`:
   ```markdown
   ## Handoff — Round 2
   ### What Was Tried (Round 1)
   <implementor's approach + key files changed>
   ### Why It Failed
   <Round 1 findings, quoted>
   ### What's Ruled Out
   <approaches that demonstrably won't work>
   ```
2. Choose Debugger mode:
   - **Inspection** (threshold tuning, config tweak, value adjustment): Debugger reads code/logs, returns 10-line diagnosis, no `diagnosis.md` file. Orchestrator applies the fix inline (Micro) or re-dispatches Implementor (Small).
   - **Full diagnosis** (real bug, wrong mental model, concurrency, integration failure): Debugger writes `diagnosis.md`. Implementor dispatched with `diagnosis.md` path.
3. Re-run `review` protocol.
4. PASS → close-out. FAIL → Round 3.

## Round 3 — Escalate

1. Write `session.md § Checkpoint` with full state (phase, last action, links to relevant artifacts).
2. Append action-log: `escalation | round-3 | feature: <slug>`.
3. **`AskUserQuestion`** with options:
   - (a) Take over manually
   - (b) Provide new direction (route through `redirect`)
   - (c) Abandon feature (move dir to `<slug>.abandoned`, clear CURRENT)
   - (d) `/clear` and resume from `session.md` checkpoint
4. Wait for user response. Do NOT dispatch further on own initiative.

## Hard rules

- **Round count is tracked in `work.md`.** Same task escalates to Round 2 on second failure of the same symptom — not unrelated failures.
- **Same-bug-twice rule:** if Round 1 finding text is substantially the same as the original review's finding text → straight to Debugger Full diagnosis, skip the Round 1 re-implement reflex.
- **Handoff section must exist before Round 2 dispatch** (`handoff-written` check).
- **Diagnosis must be referenced in dispatch prompt** (`diagnosis-consumed` check).

## Checks fired

| Check | When |
|-------|------|
| `handoff-written` | before Round 2 dispatch |
| `revisions-resolved` | continuous |
| `action-logged` | continuous |
