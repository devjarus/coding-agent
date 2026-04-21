# Protocol — Close-Out

**Entry:** `review.md` `Status: PASS`.
**Exit:** Feature directory frozen, project memory distilled, `CURRENT` cleared, commit gate opened.
**Owner:** Orchestrator.

## Steps (8)

1. **Freeze artifacts.** For every `.md` in `features/<CURRENT>/`, set frontmatter `state: archived`. After this step, the directory is read-only.
2. **Distill to learnings.** Append a dated section to `.coding-agent/learnings.md`:
   ```markdown
   ## YYYY-MM-DD — <slug>
   ### Decisions
   - <stack choice + rejected alternative + why>
   ### Gotchas
   - <workarounds, library bugs, mental-model corrections>
   ### Patterns
   - <reusable patterns introduced>
   ```
   `learnings.md` is `append-only` — newest section at top, older below; never truncated.
3. **Update AGENTS.md** if a new project-wide convention was established (logger module, test path, shared adapter).
4. **Update ARCHITECTURE.md** if a new service/db/queue or cross-module dependency was introduced.
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

1. Show diff (`git diff --stat HEAD` summary + first 100 lines of `git diff`) in chat.
2. Draft commit message: `<type>(<scope>): <subject>` + body referencing FRs + `Learnings:` block.
3. **`AskUserQuestion`**: `approve push` / `commit local only` / `redo message` / `abort`.
4. On approve push → `git commit && git push`. On commit local only → `git commit`, set `session.md.pending_pushes` += 1.

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
| `commit-has-learnings` | commit gate (Medium/Large only) |
