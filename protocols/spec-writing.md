# Protocol — Spec Writing

**Entry:** `intent.md` approved.
**Exit:** `spec.md` exists with `state: approved`, `approved_by: user`, and required sections.
**Owner:** Architect.

## Steps

1. **Read profile** (`~/.coding-agent/profile.md`) for default stack preferences, AND **read `.coding-agent/learnings.md`** (if exists) for past project decisions + gotchas. Together these answer most common questions before you ask the user.
2. **Identify discovery questions** — for any unknown the profile doesn't answer, return them as an `ask_user.questions` bundle in your structured return (NOT via `AskUserQuestion` — you don't have that tool). Orchestrator asks the user and re-dispatches you with the answers.
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
   Set `status: needs-input`. Upon re-dispatch with answers, continue to step 3.
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
   - `## Technical Risks`
   - `## Performance Budgets` (only if relevant)
   - `## Non-Goals`
5. **Write `spec.md` in `state: draft`** with blank approval fields.
6. **Return to orchestrator.** The architect NEVER calls `AskUserQuestion` for approval — only the main-thread orchestrator can reach the real user. The orchestrator will:
   - Read `spec.md`
   - Print its full body in chat
   - Call `AskUserQuestion(approve/request-changes/cancel)`
   - On user approve: flip `state: approved`, set `approved_by: user`, set `approved_at: <ts>`
   - Append action-log: `gate-passed | spec.md approved by user`

**Discovery Q&A from the architect subagent is fine** — information-gathering questions reach the user. But approval gates must happen in the orchestrator's conversation, not the subagent's.

## Combined design gate (small features)

For a `small` feature (clear scope, 2–5 files), the orchestrator dispatches the architect ONCE with `Phase: SPEC+PLAN` instead of running spec-writing and plan-writing as two separate dispatches with two separate approvals.

- The architect runs this protocol's steps 1–5, then **continues straight into `plan-writing` steps 1–6** in the same return — producing **both** `spec.md` and `plan.md` in `state: draft` (still two separate artifacts, so `stack-justified`, `test-infra-declared`, and `plan-approved` all apply unchanged).
- The orchestrator prints **both** bodies in chat and runs **one** combined approval (`AskUserQuestion` approve / request-changes / cancel) covering the pair. On approve it signs both artifacts (`approved_by: user`, `approved_at`) and runs `spec-approved` + `plan-approved` together before implementor dispatch.
- This collapses two human gates into one (a `small` feature goes 4 → 3 gates: intent → design → push) and saves a round-trip. It does **not** weaken any check — only the two *approval interactions* merge.
- **`medium`/`large` stay two-gate.** When the stack decision is consequential enough that it must settle before wave decomposition, keep spec and plan as separate dispatches and separate approvals. Don't combine on discovery-heavy specs (`status: needs-input` / `needs-research` mid-spec) — finish and approve the spec first.

## Refusals

Refuse to write `spec.md` if:
- `intent-approved` is failing
- Profile says preference for stack X but project AGENTS.md mandates stack Y → surface the conflict via `AskUserQuestion` first.

## Checks fired

| Check | When |
|-------|------|
| `stack-justified` | after draft, before user-approval prompt |
| `test-infra-declared` | after draft, before user-approval prompt |
| `spec-approved` | after user signs |
