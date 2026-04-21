# Protocol — Spec Writing

**Entry:** `intent.md` approved.
**Exit:** `spec.md` exists with `state: approved`, `approved_by: user`, and required sections.
**Owner:** Architect.

## Steps

1. **Read profile** (`~/.coding-agent/profile.md`) for default stack preferences.
2. **Bundle discovery questions** — for any unknown not answered by profile, batch into one `AskUserQuestion` with profile defaults bolded:
   > *I'll build this with: **Next 15** (profile), **shadcn** (profile), **TanStack Query** (profile). Decisions needed: (1) X — A / B / C? (2) Y — A / B? Confirm or change.*
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
