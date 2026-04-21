# Protocol — Intake

**Entry:** user types a request.
**Exit:** `intent.md` exists in `features/<slug>/` with `state: approved` and `approved_by: user`.
**Owner:** Orchestrator.

## Steps

1. **Restate** the request in one paragraph: what user wants, constraints, context from `AGENTS.md` if relevant.
2. **Classify** mode (`feature` | `touch-up` | `refactor`) and size (`micro` | `small` | `medium` | `large`).
3. **Propose path:** which gates this run will hit, estimated waves.
4. **Generate slug:** `YYYY-MM-DD-<short-name>`.
5. **Create `features/<slug>/`** and write the slug to `.coding-agent/CURRENT`. Skip for `micro` (orchestrator inlines without a feature dir).
6. **Draft `intent.md`** from `${CLAUDE_PLUGIN_ROOT}/templates/intent.template.md` — frontmatter `state: draft`.
7. **`AskUserQuestion`** with options: `approve` / `redirect` / `cancel`.
8. **On approve:** flip `state: approved`, set `approved_by: user`, set `approved_at: <ISO timestamp>`.
9. **Append action-log:** `gate-passed | intent.md approved by user`.
10. **Run check `intent-approved`.** Must pass before next protocol begins.

## Touch-up variant

Steps 1–9 the same, but mode = `touch-up`. After approval, the protocol exits to `implementation` directly (no `spec-writing` or `plan-writing`).

## Micro variant

Steps 1–4 only. No feature dir created, no `intent.md` file. The intent is captured as the first action-log entry: `intake | micro | "<restated request>"`. Approval is the user's `AskUserQuestion` response. Exit straight to inline edit.

## Refusals

Refuse to proceed (and ask user to fix) if:
- `active-feature-consistent` fails (CURRENT is stale)
- A previous feature's `close-out` did not complete

## Checks fired

| Check | When |
|-------|------|
| `active-feature-consistent` | before slug generation |
| `intent-approved` | after user signs |
| `action-logged` | continuous |
