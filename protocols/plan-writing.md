# Protocol — Plan Writing

**Entry:** `spec.md` approved.
**Exit:** `plan.md` exists with `state: approved`, per-task skill manifest, per-wave evaluation criteria with three test tiers.
**Owner:** Architect.

## Steps

1. **Read** `spec.md` (the contract) and `learnings.md` (project gotchas).
2. **Decompose** into waves (foundation → vertical slices) with tasks (T-N).
3. **For each task, declare:**
   - `domain_tags`: e.g. `[backend, nodejs, security]`
   - `skills`: consult `${CLAUDE_PLUGIN_ROOT}/CLAUDE.md § Practice skills by task context` for the routing table (always-include: `tdd`, `test-doubles-strategy`, `code-review`, `security-checklist`; conditional by context). Also add domain specialists matching `domain_tags`.
   - `acceptance`: testable statements
   - `evaluation`: three rows — `Unit:`, `Integration:`, `E2E: <what or "N/A — reason">`
4. **Mark parallelism explicitly.** Default serial. Add a `parallel: [T-3, T-4]` line per wave only when tasks touch disjoint files AND have no ordering dependency.
5. **Map risks to tasks** in `## Risk Mitigations`.
6. **Write `plan.md` in `state: draft`** with blank approval fields.
7. **Return to orchestrator.** Architect NEVER calls `AskUserQuestion` for approval. The orchestrator will:
   - Read `plan.md`
   - Print its full body in chat
   - Call `AskUserQuestion(approve/request-changes/cancel)`
   - On user approve: flip `state: approved`, set `approved_by: user`, set `approved_at: <ts>`
   - Append action-log: `gate-passed | plan.md approved by user`

Approval gates only work in the main-thread orchestrator's conversation. See `spec-writing.md` for the same rule.

## Constraints

- Spec must remain immutable. If during plan writing the spec is found to need changes, dispatch a separate `redirect` flow — do not edit `spec.md`.
- Test tiers are mandatory: `Unit` and `Integration` always; `E2E` if user-facing surface, otherwise `N/A` with reason.
- Do not invent skills. If a needed skill doesn't exist in `${CLAUDE_PLUGIN_ROOT}/skills/`, surface this as a finding before plan approval — propose adding the skill (separate, smaller workflow), don't proceed without coverage.

## Checks fired

| Check | When |
|-------|------|
| `plan-approved` | after user signs (verifies sections + skill manifests + evaluation rows) |
| `revisions-resolved` | continuously |
