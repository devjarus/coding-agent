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
3. **Update AGENTS.md** if a new project-wide convention was established (logger module, test path, shared adapter). Keep it vendor-neutral — see `${CLAUDE_PLUGIN_ROOT}/skills/practices/project-docs/SKILL.md § AGENTS.md is vendor-neutral`. No references to `.coding-agent/`, protocols, checks, or deploy commands.
4. **Update ARCHITECTURE.md** if a new service/db/queue or cross-module dependency was introduced.
4.5. **Ensure CI exists (first feature only).** If this was the project's first feature AND there's no `.github/workflows/` (or GitLab/Bitbucket equivalent), dispatch Implementor with `ci-testing-standard` skill to scaffold: test script, CI workflow running lint+typecheck+tests+build on push/PR, optional pre-commit hook. Skip if CI already exists and covers what the evaluator ran.
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

0. **Run `review-passed`** (`bash ${CLAUDE_PLUGIN_ROOT}/checks/review-passed.sh "$PWD" <slug>`). Asserts the evaluator wrote `review.md` with `## Status: PASS` — a real build + test verdict from a different actor. If it fails, there is **no passing review**: a commit here would ship unverified (or broken) work. **Abort the commit gate**, append `check-failed | review-passed`, and route back to `review` (or `fix-round` if findings exist). NEVER substitute your own `tsc`/typecheck/build for the evaluator's review — a partial signal like `tsc -b` passing is not a PASS.
1. **Run `tests-actually-committed` in commit mode** (`bash ${CLAUDE_PLUGIN_ROOT}/checks/tests-actually-committed.sh "$PWD" commit`). This asserts the working tree is non-empty (staged, modified, or untracked changes exist). If it fails, there is nothing to commit — a "commit" claim here is fabricated. **Abort the commit gate**, append `check-failed | tests-actually-committed | commit`, and surface to the user. Do not draft a commit message or show a diff.
2. **Run `no-secrets-staged`** (`bash ${CLAUDE_PLUGIN_ROOT}/checks/no-secrets-staged.sh "$PWD"`). If it fails: surface the `file_hits` and `content_hits` to the user, append a line to `.coding-agent/open-threads.md`, and **do not proceed to the next step until the user either un-stages the file(s) or explicitly authorizes the override** ("commit anyway — fixture/intentional"). Re-run the check after any change.
3. Show diff (`git diff --stat HEAD` summary + first 100 lines of `git diff`) in chat.
4. Draft commit message: `<type>(<scope>): <subject>` + body referencing FRs + `Learnings:` block.
5. **`AskUserQuestion`**: `approve push` / `commit local only` / `redo message` / `abort`.
6. On approve push → `git commit && git push`. On commit local only → `git commit`, set `session.md.pending_pushes` += 1.

## Touch-up close-out (lightweight)

Touch-up close-out skips:
- Step 3 (AGENTS.md update — touch-ups don't establish conventions)
- Step 4 (ARCHITECTURE.md update — touch-ups don't change architecture)

Steps 1, 2, 5, 6, 7, 8 still run. `learnings.md` entry only if a real lesson was learned (touch-up reflection is optional).

## Micro close-out (none)

Micro tasks have no feature dir. "Close-out" is just appending action-log: `micro | done | commit <sha>`.

## Checks fired

| Check | When |
|-------|------|
| `close-out-frozen` | step 1 verification |
| `learnings-appended` | step 2 verification |
| `current-cleared` | step 5 verification |
| `session-updated` | step 6 verification |
| `no-draft-artifacts` | step 1 verification |
| `close-out-complete` | aggregate of all above (single command) |
| `review-passed` | commit gate, step 0 — requires the evaluator's `review.md` Status: PASS before any commit |
| `commit-has-learnings` | commit gate (Medium/Large only) |
| `no-secrets-staged` | commit gate, step 2 — blocks .env / private keys / common token patterns |
