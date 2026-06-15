# Protocol — Design Review

**Entry:** architect returned a draft `spec.md` (spec gate) or `plan.md` (plan gate), plus `design.html` for UI features.
**Exit:** sha-bound `design-verdict.json` with `verdict: approved`, frontmatter flipped to `approved` — or escalation back to the architect with the comment batch.
**Owner:** Orchestrator (runs the surface, triages feedback); User (reviews, comments, signs).

## Why this exists

Chat is a poor approval surface: it hides the full design behind a terminal scroll, and every feedback item costs a whole round-trip (re-print artifact → user types → re-dispatch). The review surface renders the draft in a browser, lets the user **batch N comments in one round**, and converts the gate from O(comments) chat turns to O(rounds). The markdown artifacts stay canonical — the surface is a render + input device, never a second source of truth.

## The loop

```
architect returns draft ──► orchestrator runs pre-gate checks (stack-justified, …)
        │
        ▼
bash ${CLAUDE_PLUGIN_ROOT}/scripts/design-review.sh start <feature_dir> --round N
        │   serves review UI on localhost (spec/plan rendered server-side from
        │   markdown; design.html in an iframe), opens the browser — no CDN, offline
        ▼
USER, in the browser: reads, clicks any block/element → pinned comment,
batches all feedback, then ONE of:
  · Approve            → server writes design-verdict.json (sha-bound, rejected
                         server-side if any comment is open)
  · Request changes    → verdict: changes-requested + comments saved
        │
USER returns to chat and says anything ("done", "continue", …)
        ▼
orchestrator: design-review.sh stop, then reads design-verdict.json + design-comments.json
        │
  ┌─────┴──────────────┐
  ▼                    ▼
approved          changes-requested
  │                    │
flip frontmatter   TRIAGE the comments (orchestrator's real job here):
state: approved      · trivial wording/detail   → fold into ONE architect re-dispatch
log gate-passed      · material scope change    → existing revision machinery
continue pipeline    · out-of-scope/new feature → surface back to user, open-threads.md
                     then re-dispatch architect with ALL comments, round++ → loop
```

## Rules

1. **Start the surface, don't print the wall.** At the spec/plan gate, print a 5-line summary in chat + the review URL — not the full artifact body. The full body lives in the browser.
2. **One re-dispatch per round.** Never re-dispatch the architect per-comment. The whole comment batch (verbatim JSON, anchors included) goes into a single dispatch prompt — anchors pin each comment to the exact section/element, so the architect needs no clarification round.
3. **Triage before forwarding.** Dedupe overlapping comments; classify each as trivial / material / out-of-scope. Material ones flow through the same revision classification used in implementation. Out-of-scope ones go back to the user — they may be the seed of the next feature, not a spec change.
4. **The Approve button is the gate.** On `verdict: approved`: verify `spec_sha`/`plan_sha` in the verdict matches the file on disk (the `spec-approved`/`plan-approved` checks do this mechanically), flip `state: approved`, `approved_by: user`, `approved_at: <verdict ts>`, log `gate-passed | spec.md approved via design review (sha <short>)`. Do NOT ask a second confirmation in chat — the whole point is removing that round-trip.
5. **Round archives.** `design-review.sh start --round N+1` auto-archives the previous round's comments to `design-comments.round-N.json`. Never delete them — they're the feedback trail.
6. **Headless fallback.** No browser available (SSH, CI)? Fall back to the legacy gate: print full body in chat + `AskUserQuestion(approve/request-changes/cancel)`. Same semantics, no verdict file (checks then run frontmatter-only).
7. **Stop the server before dispatching.** A running server holds the old round; stop it, re-dispatch, restart with `--round N+1` when the revision returns.

## Integrity notes (on the record)

- **What the sha-binding buys:** approval is pinned to the exact bytes reviewed. Any post-approval edit mechanically fails `spec-approved`/`plan-approved`. Chat approval never had this.
- **What it does not buy:** fabrication-resistance is *equivalent* to the legacy gate, not better — a misbehaving orchestrator could write `design-verdict.json` itself, exactly as it could flip frontmatter without asking. The defense remains the same as everywhere else in this plugin: the orchestrator NEVER writes `design-verdict.json` or `design-comments.json` (only the review server does), and the action log records the gate with the sha for audit. Treat any hand-written verdict file as a fabricated approval.

## Checks fired

| Check | When |
|-------|------|
| `spec-approved` / `plan-approved` | after verdict — validates frontmatter AND verdict sha matches current bytes |
| `action-logged` | gate-passed entry with short sha |
