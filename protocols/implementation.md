# Protocol — Implementation

**Entry:** `plan.md` approved.
**Exit:** All tasks in plan reach `task-state: complete` in `work.md § Tasks` table. (Note: `task-state` is distinct from artifact frontmatter `state:` — tasks use `ready/in-progress/complete/blocked/failed`; artifacts use `draft/approved/active/archived`.)
**Owner:** Orchestrator (dispatches Implementor).

## Steps

1. **Initialize `work.md`** from `${CLAUDE_PLUGIN_ROOT}/templates/work.template.md`. Populate the Tasks table from plan.md.
2. **For each wave, in order:**
   - **Determine dispatch shape:**
     - If wave has `parallel: [T-X, T-Y]` block → dispatch listed Implementors in **one message** (Pattern A fan-out).
     - Otherwise → serial: dispatch one Implementor at a time.
   - **For each Implementor dispatch, include:**
     - The full task block from plan.md (including `skills:` manifest)
     - Path to `work.md` (current state)
     - Path to `learnings.md` and `AGENTS.md` (project context)
     - Path to any prior `review.md` (regression context)
3. **On Implementor return — gate before you record; one boundary, not a turn-chain.**
   - (a) Parse the structured `return:` YAML from the Implementor's final message.
   - (b) **Ground-truth gate — codified, not ad-hoc.** Run `bash ${CLAUDE_PLUGIN_ROOT}/checks/tests-actually-committed.sh "$PWD" wave <artifacts_written...>` with the returned paths verbatim. For a **parallel wave, run it ONCE at the all-returns-received barrier** (see Parallel failure handling) over every Implementor's `artifacts_written` concatenated — the check loops over the whole path list, so one invocation covers every task identically. For a **serial task**, run it on that one return. It asserts against git that the paths exist and changed this cycle; it fails on a missing file, a path invisible to git, or a zero-length list. Any task whose paths the check does not corroborate → `task-state: failed`, log `check-failed | tests-actually-committed | T-N`, route to `fix-round`. Record no completion the check did not corroborate.
   - (c) **Once the gate returns `ok` this turn, apply `work_updates` and record completion in the SAME turn** — no separate turn per step:
     - `task_states` → update `work.md § Tasks`
     - `deviations` → append to `work.md § Deviations`
     - `revisions` (any with `status: pending`) → invoke **classification step** (below) before continuing
     - `decisions` → append to `work.md § Decisions Log`
     - `nits` → append to `work.md § Nits`
     - Append action-log: `dispatch-returned | T-N | <status>`
   - (d) **Dispatch the next task/wave in a SUBSEQUENT turn.** The only hard boundary: the next `Agent` dispatch must not share a tool block with — or precede — the gating check that proved the current return. That single rule prevents advancing on an uninspected return; splitting parse/apply/log into their own turns buys no extra safety.
4. **Wave completion:** when all tasks in wave are `complete`, advance to next wave.

## Pending revision classification

When an Implementor returns a revision with `status: pending`:

| Classification | Action |
|----------------|--------|
| **Approve inline** — change is local, doesn't alter downstream tasks or evaluation criteria | Mark `Status: approved by orchestrator`, continue |
| **Dispatch architect** — change alters downstream task contracts or evaluation criteria | Architect re-dispatched; Architect appends amendments to `work.md § Plan Revisions` only (never edits plan.md). Mark `Status: approved by architect` after return. |
| **Escalate to user** — change contradicts approved spec | `AskUserQuestion` before any further dispatch |

**Hard rule:** Orchestrator must NOT dispatch the next wave while any revision is `Status: pending`. Check `${CLAUDE_PLUGIN_ROOT}/checks/revisions-resolved.sh` enforces this.

## Parallel failure handling

If any one of N parallel Implementors fails:
- The other N-1 continue to completion.
- When all parallel returns are received, Orchestrator updates `work.md` (failed task `state: failed`).
- **Then** route the failure to `${CLAUDE_PLUGIN_ROOT}/protocols/fix-round.md` Round 1 — do not interrupt the parallel batch mid-flight.

## Implementor "needs-input" return

If an Implementor returns `status: needs-input`:
- Orchestrator surfaces the question via `AskUserQuestion`
- On answer, Orchestrator re-dispatches the same Implementor with the answer in the prompt
- Append action-log: `implementor-paused | T-N | reason: needs-input`

## Skill manifest enforcement

The Orchestrator passes the Implementor's skill manifest **verbatim** from plan.md. It does not add or remove skills at dispatch time. If an Implementor returns claiming a needed skill was missing, that is a `revision` (Architect under-specified the manifest) — handled via the classification step above.

## Checks fired

| Check | When |
|-------|------|
| `tests-actually-committed` | step 3(b) — on every returned task, BEFORE `dispatch-returned` is logged or the wave advances |
| `revisions-resolved` | before each wave dispatch |
| `no-raw-print` | self-run by Implementor on changed files before return |
| `action-logged` | continuous |
