# Protocol — Review

**Entry:** Implementation complete (all wave tasks reach `task-state: complete` in `work.md § Tasks`).
**Exit:** `review.md` exists with `## Status` PASS or FAIL and `## Dispatch Recommendation`.
**Owner:** Evaluator.

## Mode selection

| Mode | When | Output |
|------|------|--------|
| **Smoke** | Micro inline / single-file mechanical change | 50-word block, no `review.md` file |
| **Delta** | Fix-round **re-review** of a *targeted* fix (implementor's changed files ⊆ the files named in the prior findings; no new files; not same-bug-twice) | Appends `## Round N Re-review` to the existing `review.md` — per-finding resolved/unresolved + Status. Does NOT re-audit untouched code. |
| **Lightweight** | Touch-up or Small (≤5 files, no design changes) | Shortened `review.md` (changed files + relevant FRs) |
| **Full** | Medium / Large feature, OR fix-round re-review that is NOT targeted (new files, surface beyond the findings, or same-bug-twice), OR prior `review.md` had unresolved findings outside the fixed set | Complete `review.md` (all FRs, regression check, runtime verification) |

Default: Lightweight for first review; **Delta for targeted fix-round re-reviews**. Orchestrator picks the re-review mode from the fix's blast radius (see `${CLAUDE_PLUGIN_ROOT}/protocols/fix-round.md`) and escalates Delta→Full automatically when the fix is not targeted.

### Delta mode steps (targeted fix-round re-review)

The point of Delta is to re-verify *what changed*, not re-audit *what didn't*. Tests still run — integrity is preserved; only the from-scratch FR sweep and full runtime re-drive are skipped.

1. **Read** prior `review.md § Findings` (the specific finding IDs that caused FAIL) + the diff since the prior review (changed files only).
2. **Build** — must pass.
3. **Run the committed test tiers** (regression — must pass). A fix that turns a test red anywhere is a FAIL, not a Delta pass.
4. **Verify each prior finding is resolved** at its `file:line` — targeted, not an all-FR re-sweep. Any unresolved finding → that finding stays open.
5. **Runtime check ONLY if the fix touched UI surface named in the findings** — re-drive just the affected flow + screenshot it; do not re-drive every flow.
6. **Append `## Round N Re-review`** to the existing `review.md`: per-finding `resolved | unresolved`, regression result, and overall `Status: PASS | FAIL`. Escalate to **Full** instead if step 1's diff shows the fix touched files beyond the findings or added files.

## Steps

1. **Pre-flight (UI projects only):**
   - Detect UI: package.json frontend dep OR `client|web|frontend|apps/web|packages/web` dir OR `*.xcodeproj`.
   - Probe required MCP: `mcp__playwright__browser_navigate("about:blank")` (web) or `mcp__ios-simulator__get_booted_sim_id` (iOS).
   - **If MCP unavailable:** write `review.md` with `Status: FAIL`, `Reason: BROWSER_MCP_UNAVAILABLE`, instruct user to enable, return. Do NOT degrade to HTML grep.
2. **Read context:** `spec.md`, `plan.md`, `work.md` (especially `## Plan Revisions` — approved revisions supersede plan.md), last feature's `review.md` (regressions), `learnings.md`, changed files list.
3. **Build:** run the project's actual build command (from AGENTS.md). Capture stdout/stderr.
4. **Run committed tests** (per tier — never write ad-hoc scripts):
   - Unit: `npm test` (or project's command)
   - Integration: `npm run test:integration` (or equivalent)
   - E2E: `npm run test:e2e` (only if UI was touched)
5. **Static review:** spec compliance per FR, error handling (no silent suppression), logging present, security patterns.
6. **Runtime check (UI only, not for API/library):**
   - Web: launch dev server (parse port from stderr — never hardcode), `mcp__playwright__browser_*` to drive primary flow, `mcp__playwright__browser_take_screenshot` to `features/<slug>/screenshots/<descriptive-name>.png`
   - iOS: `mcp__xcodebuild__*` build, `mcp__ios-simulator__*` to launch + screenshot
7. **Write `review.md`** from `${CLAUDE_PLUGIN_ROOT}/templates/review.template.md`. Required sections all present.
8. **Return** with structured update payload.

## Hard rules

- **No ad-hoc scripts.** Evaluator invokes existing test suites. If a needed test does not exist, that is a finding (not a script the evaluator writes itself).
- **`Status: FAIL` if:**
  - Build fails
  - Any unit/integration/e2e test fails (and was supposed to pass)
  - A required test tier is missing for the change (per plan.md's declared tiers — prose-enforced)
  - UI project but no `screenshots/`
  - `BROWSER_MCP_UNAVAILABLE`
  - Pending plan revision exists
- **No "PASS pending human verification."** Either the artifact evidence exists (PASS), or it doesn't (FAIL with specific reason).

## Checks fired

| Check | When |
|-------|------|
| `tests-actually-committed` | Step 4 — asserts the implementor's returned artifact paths exist and changed in git this cycle (same gate the orchestrator runs on wave return); it does not read plan.md and is not test-specific |
| `ui-evidence` | Step 6/7 — required for UI projects |
| `no-raw-print` | Step 5 |
| `revisions-resolved` | Step 2 (pending = automatic FAIL) |
