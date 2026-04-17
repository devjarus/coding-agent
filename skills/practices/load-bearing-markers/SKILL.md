---
name: load-bearing-markers
description: Mark and preserve non-obvious code that looks removable but isn't. Defensive patterns, workarounds for library bugs, and fixes that survived painful debugging deserve a marker so the next refactor doesn't silently regress them.
---

# Load-Bearing Markers

Code that looks redundant, overly defensive, or oddly specific is often load-bearing — it exists because of a bug that was painful to find and costly to re-learn. Without a marker, the next refactor simplifies it away and the bug comes back.

## The Markers

Use one of these comment forms directly above the load-bearing line(s):

| Marker | Use when |
|--------|---------|
| `// LOAD-BEARING: <reason>` | The line fixes or works around a real bug. Reason is 1 sentence — what breaks if this is removed. |
| `// F-NNN: <short-ref>` | Preferred when the fix has a tracking ID (Linear, Jira, GitHub issue, internal RFC). NNN is the ID number. |
| `// HACK: <reason>` | Workaround you'd like to remove but can't yet (e.g., pending upstream fix). Include what would let you remove it. |
| `// FIXME: <reason>` | Known defect, not yet fixed. Not load-bearing — means "this is broken." |

`LOAD-BEARING` and `F-NNN` are the load-bearing markers. `HACK` and `FIXME` are included for completeness so the grep pattern below catches all maintenance-sensitive lines.

## When to Add One

- You fixed a bug that took >30 minutes to diagnose and the fix looks removable.
- You added defensive code because a library/framework misbehaves in a specific way.
- You kept an ordering, a type coercion, or a fallback that isn't obvious from the surrounding code.
- You imported a polyfill, shim, or adapter that a future dev would assume is dead weight.

## Example

```ts
// LOAD-BEARING: tsx in CJS mode does not populate import.meta.dirname,
// so we must derive the directory from import.meta.url manually.
const __dirname = path.dirname(fileURLToPath(import.meta.url));
```

Without the marker, the next refactor deletes the URL dance and replaces it with `import.meta.dirname`, which silently returns `undefined` under tsx/CJS.

## Grep Pattern (for refactors and pre-dispatch checks)

Before rewriting or refactoring any file, run:

```bash
grep -nE '// *(LOAD-BEARING|HACK|FIXME|F-[0-9]+)' <file>
```

If matches are found:
- **Refactor agent:** paste the exact matching lines into the refactor prompt with the instruction *"Preserve these lines. They encode non-obvious fixes. Do not silently simplify."*
- **Orchestrator (pre-dispatch):** include the matches in the implementor dispatch so the marker survives the rewrite.
- **Implementor (before editing a file):** run the grep yourself on files you're about to modify. If you remove a load-bearing line, you own the justification.

## Rules

1. **One sentence minimum.** `// LOAD-BEARING: needed` is useless. Say *what* breaks if removed.
2. **Keep it adjacent.** Marker goes directly above the line(s) it protects, not at the top of the file.
3. **Re-evaluate on removal.** If you're about to remove a LOAD-BEARING line because the underlying bug is fixed, delete the marker in the same commit and write a learnings.md entry explaining the fix is no longer needed.
4. **Don't hide routine defensive code.** Null checks, error handling, and input validation are not load-bearing — they're normal. Mark only the *non-obvious* stuff.
5. **F-NNN is preferred when a ticket exists.** It gives a future reader a single place to read the full history. Fall back to `LOAD-BEARING` when there's no ticket.

## Why This Skill Exists

The alternative is oral tradition: "don't touch that line, it fixes a bug." Oral tradition doesn't survive team turnover or conversation compaction. A grep-able marker does.
