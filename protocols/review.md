# Protocol — Review

**Entry:** Implementation complete (all wave tasks `state: complete`).
**Exit:** `review.md` exists with `## Status` PASS or FAIL and `## Dispatch Recommendation`.
**Owner:** Evaluator.

## Mode selection

| Mode | When | Output |
|------|------|--------|
| **Smoke** | Micro inline / single-file mechanical change | 50-word block, no `review.md` file |
| **Lightweight** | Touch-up or Small (≤5 files, no design changes) | Shortened `review.md` (changed files + relevant FRs) |
| **Full** | Medium / Large feature, OR fix-round Round 2+, OR prior `review.md` had unresolved findings | Complete `review.md` (all FRs, regression check, runtime verification) |

Default: Lightweight. Orchestrator escalates to Full automatically on size or regression triggers.

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
  - A required test tier is missing for the change (`test-tiers-covered` fail)
  - UI project but no `screenshots/`
  - `BROWSER_MCP_UNAVAILABLE`
  - Pending plan revision exists
- **No "PASS pending human verification."** Either the artifact evidence exists (PASS), or it doesn't (FAIL with specific reason).

## Checks fired

| Check | When |
|-------|------|
| `tests-actually-committed` | Step 4 — verifies test files claimed in plan.md exist |
| `ui-evidence` | Step 6/7 — required for UI projects |
| `no-raw-print` | Step 5 |
| `revisions-resolved` | Step 2 (pending = automatic FAIL) |
