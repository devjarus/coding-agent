# Protocol — Redirect

**Entry:** user message during an active pipeline (i.e., `CURRENT` is non-empty and last action wasn't `close-out`).
**Exit:** message classified and routed.
**Owner:** Orchestrator.

## Classification (always do this first)

| Kind | Signals | Action |
|------|---------|--------|
| **Feedback on current work** | references in-flight tasks, fixes, corrections, "also fix X" within scope | Append to `work.md § Findings` (mid-implementation findings). Fold into current fix-round or active wave. **No new artifact.** |
| **Scope change** | adds a requirement, removes one, changes a tradeoff | Append a `revision` entry to `work.md § Plan Revisions` with `Supersedes: plan.md §<section>`. **`plan.md` and `spec.md` stay untouched.** Then route through Implementation protocol's pending-revision classification. |
| **Pivot** | entirely new feature, previous feature abandoned | Run `recovery` (write session.md checkpoint), then `AskUserQuestion`: "abandon current feature (mark `state: abandoned` in work.md, move dir to `<slug>.abandoned/`) or close out first (run review + close-out)?" |

## Procedure

1. **Read message + current `phase`** from `session.md § Checkpoint`.
2. **Classify** using the table above. If ambiguous → `AskUserQuestion` with the three options.
3. **Append action-log:** `redirect-classified | kind: <feedback|scope-change|pivot> | reason: <one line>`.
4. **Route** per the chosen kind:
   - Feedback → continue current protocol with the new finding folded in
   - Scope change → invoke `plan-writing` revision flow OR `implementation` pending-revision classification (depending on whether plan structure changes or just task content)
   - Pivot → run `recovery`, then `intake` for the new request after user decision

## Hard rules

- **Never edit approved artifacts** (`spec.md`, `plan.md`, `intent.md`). All amendments go through `work.md`.
- **Architect, when re-dispatched for a scope change, also writes only to `work.md § Plan Revisions`.** Never `plan.md` or `spec.md`.
- **Classification is recorded** in `work.md § Decisions Log` AND action-log. Future audits can answer "why did the orchestrator choose to fold this in vs treat it as a scope change?"

## Checks fired

| Check | When |
|-------|------|
| `redirect-classified` | every user message during active pipeline |
| `revisions-resolved` | continuous |
| `action-logged` | continuous |
