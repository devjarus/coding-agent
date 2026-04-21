# Protocol — Spec Writing

**Entry:** `intent.md` approved.
**Exit:** `spec.md` exists with `state: approved`, `approved_by: user`, and required sections.
**Owner:** Architect.

## Steps

1. **Read profile** (`~/.coding-agent/profile.md`) for default stack preferences.
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
   - `mcp__deepwiki__*` for repo-specific guidance
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
