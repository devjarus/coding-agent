# Protocol — Spec Writing

**Entry:** `intent.md` approved.
**Exit:** `spec.md` exists with `state: approved`, `approved_by: user`, and required sections.
**Owner:** Architect.

**Size branch.** For **non-large** features this protocol runs in the SAME architect dispatch as plan-writing (`Phase: SPEC+PLAN`): the spec is drafted, then the plan is drafted against it, and BOTH are handed into one combined design-review pass — the spec is not separately approved here (one verdict binds both shas). The standalone Entry/Exit above (spec approved on its own gate before the plan starts) applies only to **large** features, where the spec is locked + immutable before the plan is written so wave decomposition builds on a frozen spec.

## Steps

1. **Read profile** (`~/.coding-agent/profile.md`) for default stack preferences, AND **read `.coding-agent/learnings.md`** (if exists) for past project decisions + gotchas. Together these answer most common questions before you ask the user.
2. **Identify discovery questions — split design-changing vs low-stakes.** For each unknown the profile doesn't answer: if it would **materially change the design or core flow** (or more than 2 forks remain), return it as an `ask_user.questions` bundle (NOT via `AskUserQuestion` — you don't have that tool; the orchestrator asks and re-dispatches with answers). If it's one of **≤2 low-stakes forks**, do NOT round-trip — default it and flag it (low-stakes lane below).
   Example bundle:
   ```yaml
   ask_user:
     questions:
       - q: "Notification delivery?"
         options: ["push + in-app", "email only", "toast only"]
         default: "push + in-app"
       - q: "Read state persistence?"
         options: ["per-user timestamp", "thread-level"]
         default: "per-user timestamp"
   ```
   Set `status: needs-input` for **design-changing forks, or when more than 2 forks remain**. Upon re-dispatch with answers, continue to step 3.
   **Low-stakes lane (≤2 forks):** for up to two forks that do NOT change the core flow, draft the spec applying sane defaults, record each under `## Assumed Defaults` (fork / chosen default / why / how to override — it renders in the review surface), and return `status: complete`. No `needs-input` round-trip: the user confirms or overrides them inside the single design-review approval pass. Reserve the `ask_user` bundle for design-changing forks.
3. **Test infrastructure research** — for each external dep in the stack, query MCPs and decide test tool:
   - `mcp__context7__query-docs` for SDK / framework test patterns
   - `mcp__exa__web_search_exa` for `<dep> testing 2026`
   - Use **interleaved thinking** — reason about each result before the next query. **Verify before trusting:** try to refute each load-bearing claim with a second source or a recency check before recording it.
   - For breadth-heavy research (3+ unfamiliar deps, a "which approach wins" comparison), don't grind sequentially — return `status: needs-research` with a `research_request`; the orchestrator runs `${CLAUDE_PLUGIN_ROOT}/protocols/research.md` (parallel fan-out + verification) and re-dispatches you with cited findings.
   - Record each as a row in `## Test Infrastructure` (tool + tradeoff + source consulted).
4. **Draft `spec.md`** from `${CLAUDE_PLUGIN_ROOT}/templates/spec.template.md`. Include all required sections:
   - `## Tech Stack` (chosen + alternatives + tradeoff per row)
   - `## Test Infrastructure` (tool + tradeoff + source per row)
   - `## Requirements` (FR-N, one sentence each, testable)
   - `## Assumed Defaults` (≤2 low-stakes forks defaulted instead of asked — fork / chosen default / why / how to override; empty = none)
   - `## Technical Risks`
   - `## Performance Budgets` (only if relevant)
   - `## Non-Goals`
5. **Write `spec.md` in `state: draft`** with blank approval fields.
6. **Return — and the gate is size-conditional.** The architect NEVER calls `AskUserQuestion` for approval — only the main-thread orchestrator can reach the real user.
   - **NON-LARGE (`Phase: SPEC+PLAN`): do NOT run a spec gate here.** Do not return after the spec and do not flip spec.md on its own verdict. Continue into `plan-writing.md` in the same dispatch and return both `spec.md` + `plan.md`; the spec flips to approved only as part of the single combined design-review verdict (which binds both shas — see `design-review.md` rule 4).
   - **LARGE (`Phase: SPEC`): run the standalone spec gate now**, via `${CLAUDE_PLUGIN_ROOT}/protocols/design-review.md`:
     - Print a 5-line summary in chat (not the full body), start the review surface (`scripts/design-review.sh start <feature_dir>`), give the user the URL
     - User comments + signs in the browser; on `verdict: approved` (sha-bound): flip `state: approved`, set `approved_by: user`, `approved_at: <verdict ts>`
     - On `changes-requested`: triage the comment batch, ONE re-dispatch to the architect, round++
     - Append action-log: `gate-passed | spec.md approved via design review (sha <short>)`
     - Headless fallback (no browser): print full body + `AskUserQuestion(approve/request-changes/cancel)` as before

**Discovery Q&A from the architect subagent is fine** — information-gathering questions reach the user. But approval gates must happen in the orchestrator's conversation, not the subagent's.

## Refusals

Refuse to write `spec.md` if:
- `intent-approved` is failing
- Profile says preference for stack X but project AGENTS.md mandates stack Y → surface the conflict via `AskUserQuestion` first.

## Checks fired

| Check | When |
|-------|------|
| `stack-justified` | after draft, before user-approval prompt |
| `test-infra-declared` | after draft, before user-approval prompt |
| `spec-approved` | after the verdict — large: standalone spec verdict; non-large: the combined SPEC+PLAN verdict (spec_sha leg) |
