# Protocol — Close-Out

**Entry:** `review.md` `Status: PASS`.
**Exit:** Feature directory frozen, project memory distilled, `CURRENT` cleared, commit gate opened.
**Owner:** Orchestrator.

## Steps (8)

1. **Freeze artifacts.** For every `.md` in `features/<CURRENT>/`, set frontmatter `state: archived`. After this step, the directory is read-only.
2. **Distill to learnings.** Prepend a dated section to `.coding-agent/learnings.md` (the file uses template `${CLAUDE_PLUGIN_ROOT}/templates/learnings.template.md` — create from template if missing):
   ```markdown
   ## YYYY-MM-DD — <slug>

   ### Decisions
   - <stack choice> — chose X over Y because Z

   ### Gotchas
   - <library bug / API quirk / mental-model correction>

   ### Patterns
   - <reusable pattern introduced> — file:line reference
   ```
   `learnings.md` is `append-only` — newest section at top (below the file header), older below; never truncated, never edited after writing. Existing dated sections are immutable. If you find a past entry is wrong or outdated, ADD a correcting entry in today's section — do NOT edit the old one.
3. **Update the committed documentation set** via `${CLAUDE_PLUGIN_ROOT}/skills/practices/project-docs/SKILL.md` — the cross-referenced, no-duplication set any agent can use (README · AGENTS · PRODUCT · DESIGN · docs/architecture · docs/dataflow · docs/index · deployment). On the **first feature** generate the whole applicable set from the real codebase (DESIGN.md only for UI projects; deployment.md only when CI config exists); on later features refresh only the docs the feature touched, per the skill's update map. Each fact lives in exactly one file — never duplicate across docs.
   - **README.md** — front page; on first feature (or whenever missing / still a scaffold) generate a real one (a scaffold "This template provides a minimal setup…" must be **replaced**; the `docs-current` check at step 8 blocks close-out otherwise).
   - **AGENTS.md** — build/test commands + conventions when a new project-wide convention was established. Stays vendor-neutral: no `.coding-agent/`, protocol/check/role names, or deploy values (the `docs-links` check enforces this).
4. **Update `docs/architecture.md`** (topology, data model, key components, stack rationale) and **`docs/dataflow.md`** (flow traces, state transitions) if the feature introduced a new service/db/queue/integration or changed component topology or how data moves. This is the project's only architecture surface — a legacy root `ARCHITECTURE.md`, if present, is reduced to a one-line pointer to `docs/architecture.md` (never two architecture docs). Refresh `docs/index.md` if a file was added to/removed from `docs/`.
4.6. **Distill `DESIGN.md`** (UI projects only) if the feature shipped UI that introduced or changed design tokens, components, or guardrails — from the approved per-feature look-contract (`design.html`), not re-invented. Skip for non-UI projects.
4.5. **Ensure CI exists (first feature only).** If this was the project's first feature AND there's no `.github/workflows/` (or GitLab/Bitbucket equivalent), dispatch Implementor with `ci-testing-standard` skill to scaffold: test script, CI workflow running lint+typecheck+tests+build on push/PR, optional pre-commit hook. Skip if CI already exists and covers what the evaluator ran.
4.7. **Product reflection (opt-in — only if `.coding-agent/product.md` exists).** Dispatch Product-Lead (`Mode: reflect`) with the feature's `spec.md` + `review.md` summary + `product.md` path; append its returned `evolution_entry` to `product.md § Evolution Log` (append-only — you own the on-disk write) and update the maturity-ladder "Now:" line if it changed. **Then re-distill the committed `PRODUCT.md`** (the current-state snapshot from step 3) from the freshened runtime `product.md` — strip the Evolution Log and any unshipped bets; the committed file is the public what/why/for-whom, never the strategy log. Append action-log `product-reflect | <slug> | <north-star delta>`. See `${CLAUDE_PLUGIN_ROOT}/protocols/product-direction.md` § Reflect. Skip entirely when no `product.md` exists (step 3 already generated the committed `PRODUCT.md` from the spec) and for touch-up/micro close-out.
5. **Clear CURRENT.** `: > .coding-agent/CURRENT`
6. **Update session.md Checkpoint:**
   ```
   active_feature: none
   phase: idle
   last_completed: <slug @ ISO-timestamp>
   ```
7. **Append action-log entry:** `close-out | <slug> archived | N waves | M tasks | K nits`
8. **Run all close-out checks** — see below. If any fail, self-repair the failed step and re-check.

## Commit Gate (after close-out)

After close-out completes, **before** any git commit:

0. **Run the commit gate — one serialized call** (`bash ${CLAUDE_PLUGIN_ROOT}/checks/commit-gate.sh "$PWD" <slug>`). It runs, in order and stopping at the first failure: `review-passed` (evaluator's `review.md` Status: PASS — never substitute your own `tsc`/build) → `tests-actually-committed commit` (working tree has real source changes) → `no-secrets-staged` → `last-verify` green. **Do not improvise this as separate parallel calls** — the one script is the serialization. On non-zero, read `failed`/`reason`, append `check-failed | commit-gate | <failed>`, and route back: `review`/`fix-round` for a review or test failure; for a `no-secrets-staged` failure, surface `file_hits`/`content_hits`, append to `.coding-agent/open-threads.md`, and proceed only when the user un-stages or explicitly authorizes — then re-run with `commit-gate.sh "$PWD" <slug> --allow-secrets`. Draft no message and show no diff until the gate passes.
1. Show diff (`git diff --stat HEAD` summary + first 100 lines of `git diff`) in chat.
2. Draft commit message: `<type>(<scope>): <subject>` + body referencing FRs + `Learnings:` block. **Never write "verified" / "passing" / "N tests pass" as narration** — verification is the recorded artifact `.coding-agent/last-verify.json` (written by `run-and-record.sh`), never a word you type. State results by pointing at the recorded counts. The installed `commit-msg` hook **rejects** any message claiming verification unless that record is green and current; "(verified)" is never a self-description.
3. **`AskUserQuestion`**: `approve push` / `commit local only` / `redo message` / `abort`.
4. On approve, **stage source explicitly — NEVER `git add -A` or `git add .`**. Coordinator state must never be tracked. Use `git add -- . ':(exclude).coding-agent'` (or stage only the implementor's reported source paths). Then `approve push` → `git commit && git push`; `commit local only` → `git commit`, set `session.md.pending_pushes` += 1.

> **Never track `.coding-agent/`.** Staging it (via `git add -A`) makes coordinator artifacts part of a commit; a later `git reset --hard`/amend/`git clean` then deletes `intent.md`/`spec.md`/`plan.md`/`session.md` all at once. Always stage source explicitly and exclude `.coding-agent/`.

## Touch-up close-out (lightweight)

Touch-up close-out skips:
- Step 3 (README/AGENTS.md update — touch-ups don't establish conventions or change the project's front page)
- Step 4 / 4.6 (docs/architecture.md, dataflow.md, DESIGN.md — touch-ups don't change architecture or the design system)
- Step 4.7 (product reflection — a touch-up doesn't move the north-star)
- The `docs-current` and `docs-links` checks in step 8 (a touch-up shouldn't force a docs regen)

Steps 1, 2, 5, 6, 7, 8 still run (step 8 minus `docs-current` and `docs-links`). `learnings.md` entry only if a real lesson was learned (touch-up reflection is optional).

## Micro close-out (none)

Micro tasks have no feature dir. "Close-out" is just appending action-log: `micro | done | commit <sha>`.

## Checks fired

| Check | When |
|-------|------|
| `close-out-complete` | step 8 — one aggregate script; verifies artifacts archived, learnings appended, CURRENT cleared, session updated, and no draft artifacts remain |
| `docs-current` | step 8 (full close-out only) — README.md exists, isn't framework-scaffold boilerplate, and isn't an untouched placeholder while source landed |
| `docs-links` | step 8 (full close-out only) — committed doc set is present (DESIGN only for UI, deployment only with CI), every relative cross-link resolves, and no committed doc leaks plugin-runtime references or secrets |
| `commit-gate` | commit gate, step 0 — one serialized script: `review-passed` → `tests-actually-committed commit` → `no-secrets-staged` → `last-verify` green, stopping at the first failure |

The Medium/Large commit message must carry a `Learnings:` block (step 2) — an orchestrator convention, not a separate script. The consumer-side `commit-msg` git hook (installed by `setup.sh`) independently rejects fabricated "verified/passing" messages — enforcement, not just convention.
