---
name: artifact-migration
description: Detect and clean up legacy .coding-agent/ artifacts left by older plugin conventions (root-level flat plan/spec/review + .prev* chains, per-feature progress.md / nits.md / mode files) so a long-lived project doesn't drift into confusing dual state. Archive-never-delete, opt-in, idempotent.
scope: orchestrator
trigger: on-invoke
category: practice
---

# Artifact Migration

Long-lived projects accumulate `.coding-agent/` artifacts from older plugin conventions. The SessionStart hook flags them; this skill cleans them up — **safely, opt-in, and without ever destroying state.**

The plugin's conventions evolved: `progress.md` → `work.md`; separate `nits.md` → `work.md § Nits/Findings`; per-feature `mode` files → orchestrator classification; and a flat root layout (`.coding-agent/plan.md`, `spec.md`, `review.md` + manual `.prev`/`.prev2`/`.prev3` versioning) → per-feature `features/<slug>/` dirs with immutable artifacts + `work.md § Plan Revisions` supersession. Old projects carry both, which confuses "what's the active state."

## When to apply

- The SessionStart hook surfaced "Legacy-convention artifacts detected" AND the user accepts the offered cleanup.
- The user asks to "clean up `.coding-agent`", "migrate old artifacts", or similar.
- **Never auto-run.** This moves files — the orchestrator OFFERS it (`AskUserQuestion`) and runs it only on a yes. Suppressed after a `.coding-agent/.migrated` marker exists.

## What is legacy

| Legacy artifact | Current equivalent | Action |
|---|---|---|
| Root `.coding-agent/{plan,spec,review,progress}.md` + `*.prev*.md` | per-feature `features/<slug>/` dirs | **Archive** the whole flat/`.prev` set — it predates per-feature dirs and competes with the active layout |
| Per-feature `progress.md` (in an archived feature) | `work.md` | **Leave in place** — it's frozen history of a shipped feature; lossy prose→table conversion isn't worth the risk |
| Per-feature `nits.md` (in an archived feature) | `work.md § Nits` | **Leave in place** — frozen history |
| Per-feature `mode` file | orchestrator classifies at intake | **Archive** — dead convention, nothing reads it |

## Hard rules (safety)

1. **NEVER delete — only archive.** Move to `.coding-agent/.archive/<YYYY-MM-DD>/`, preserving relative paths. Reversible by design.
2. **Never touch the ACTIVE feature.** Read `.coding-agent/CURRENT`; the active feature dir and its artifacts are off-limits.
3. **Never touch a current-layout `features/<slug>/` dir's live artifacts** (`work.md`, `intent.md`, `spec.md`, `plan.md`, `review.md`). Only the legacy items in the table above.
4. **User confirms first.** The orchestrator shows the exact list of files to be moved and the destination, then `AskUserQuestion(migrate / skip)`. No silent moves.
5. **Idempotent.** After a successful run, write `.coding-agent/.migrated` (date + which sets were archived). The SessionStart hook checks for it and stops re-offering.
6. **Conservative scope.** When unsure whether something is legacy or live, LEAVE IT and note it for the user — over-archiving live state is worse than leaving an extra file.

## Procedure

1. **Detect.** Enumerate legacy artifacts (the table above). Exclude the `CURRENT` feature dir.
2. **Present.** Orchestrator lists every file to be moved + the `.archive/<date>/` destination, then asks the user (migrate / skip).
3. **Archive (on yes).**
   ```bash
   ARCH=".coding-agent/.archive/$(date +%Y-%m-%d)"
   mkdir -p "$ARCH"
   # root flat + .prev chains (NOT a current-layout file):
   for f in .coding-agent/plan*.md .coding-agent/spec*.md .coding-agent/review*.md .coding-agent/progress*.md; do
     [ -e "$f" ] && mkdir -p "$ARCH/$(dirname "${f#'.coding-agent/'}")" && git mv -k "$f" "$ARCH/" 2>/dev/null || mv "$f" "$ARCH/"
   done
   # dead per-feature mode files (skip CURRENT):
   find .coding-agent/features -name mode -type f  # move each into $ARCH preserving path, skipping CURRENT
   ```
   (`.coding-agent/` is gitignored, so a plain `mv` is fine; preserve the relative path under `.archive/`.)
4. **Marker.** Write `.coding-agent/.migrated`:
   ```
   migrated: <YYYY-MM-DD>
   archived: root flat plan/spec/review/progress + .prev chains; N dead mode files
   note: per-feature progress.md/nits.md in archived features left in place (frozen history)
   ```
5. **Log.** Append action-log: `artifact-migration | archived <N> legacy artifacts to .archive/<date>`.

## What this is NOT

- Not a feature-state rewrite. It does not convert `progress.md` into `work.md` — frozen history stays as-is.
- Not a deletion tool. Everything is recoverable from `.archive/`.
- Not automatic. The user always decides.
