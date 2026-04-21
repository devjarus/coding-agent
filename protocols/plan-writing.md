# Protocol — Plan Writing

**Entry:** `spec.md` approved.
**Exit:** `plan.md` exists with `state: approved`, per-task skill manifest, per-wave evaluation criteria with three test tiers.
**Owner:** Architect.

## Steps

1. **Read** `spec.md` (the contract) and `learnings.md` (project gotchas).
2. **Decompose** into waves (foundation → vertical slices) with tasks (T-N).
3. **For each task, declare:**
   - `domain_tags`: e.g. `[backend, nodejs, security]`
   - `skills`: consult the Practice skills routing table below. Always-include: `tdd`, `test-doubles-strategy`, `code-review`, `security-checklist`. Conditional by context. Also add domain specialists matching `domain_tags`.
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

## Practice skills routing

Used in step 3 (`skills:` per task). Rows are additive — all that match the task context apply.

| Task context | Practice skills to include |
|--------------|----------------------------|
| Every task (always-include) | `tdd`, `test-doubles-strategy`, `code-review`, `security-checklist` |
| Task writes production logic | `observability`, `error-handling` |
| Task touches configuration | `config-management` |
| Task introduces external client (DB, API, cache, queue) | `service-architecture` |
| Task defines a cross-service contract | `shared-contracts` |
| Task has integration boundary | `integration-testing` |
| Task has user-facing flow | `e2e-testing` |
| Task touches a new dependency | `dependency-evaluation` |
| Task migrates data or schema | `migration-safety` |
| Feature is a published library | `publish-ready` |
| First feature in greenfield project | `ci-testing-standard` (invoked by close-out protocol, not by implementor) |
| Refactoring existing files | `load-bearing-markers` (already preloaded to implementor; mention here for audit) |
| Multi-perspective research (architect's own step 1) | `ideation-council` |
| Generating project docs (orchestrator dispatches implementor with this during close-out) | `project-docs` |
| Cutting a release | `release` |

When a task hits multiple contexts, union the skill sets. A typical backend API endpoint task lands: `tdd`, `test-doubles-strategy`, `code-review`, `security-checklist`, `observability`, `error-handling`, `api-design`, `nodejs-specialist`, `integration-testing`.

## Checks fired

| Check | When |
|-------|------|
| `plan-approved` | after user signs (verifies sections + skill manifests + evaluation rows) |
| `revisions-resolved` | continuously |
