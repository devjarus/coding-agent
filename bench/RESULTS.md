# Bench results — 2026-09-27

Native = Claude Code with no plugin (Sonnet 5, effort high). Plugin arms load the
plugin via `--plugin-dir`. Quality = hidden-test pass rate after re-scoring every
run against the current suites (`bench/rescore.py`). Means over `n` runs.

| Task | Native | v6.1 (Opus, all delegated) | v7 `a097764` | v7 `5831291` | v7 `979942a` (latest) |
|---|---|---|---|---|---|
| small-pricing-fix | 100% · $0.18 · 64 s (n=3) | 100% · $1.29 · 283 s | 100% · $0.33 · 157 s | 100% · $0.26 · 124 s (n=2) | — |
| medium-bookmarks-api | 94% · $0.32 · 133 s (n=2) | 100% · $3.38 · 950 s | 88% · $1.45 · 660 s | 91% · $1.39 · 668 s (n=2) | **100%** · $2.64 · 1193 s (n=2) |
| complex-job-queue | 100% · $0.73 · 282 s (n=2) | — | 100% · $1.12 · 521 s | 100% · $1.96 · 822 s (n=2) | — |
| complex-booking-engine | 100% · $1.45 · 566 s (n=2) | 100% · $7.78 · 1972 s | 100% · $3.53 · 1396 s | — | — |
| complex-issue-tracker | 95% · $1.52 · 678 s (n=2) | 100% · $9.46 · 2354 s | 95% · $5.12 · 1988 s | — | — |

Suite ratios vs native (one comparable run each, `report.py`):

| | Quality Δ | Cost | Time |
|---|---|---|---|
| v6.1 | +3 pts | 7.2× | 3.5× |
| v7 `a097764` | −1 pt | 3.0× | 2.5× |
| Goal | ≥ 0 (complex ≥ +10) | ≤ 1.0× | ≤ 1.0× |

**Goal not met.** No arm has the 3 reps per task the goal requires for a claim.

## What the numbers say

- **Native Sonnet 5 is at the ceiling on well-specified tasks.** It scored 100%
  on every original hidden test, including 8 concurrent worker processes. The
  only misses, on every native run, are a stated-but-subtle rule: "errors are
  JSON" on methods the server doesn't handle.
- **v6.1's quality edge came with Opus and 7× cost.** Every v6.1 role ran
  Opus 5.5; v7 inherits the session model (Sonnet 5), so part of v6.1's edge
  was the model, not the process.
- **v7 cut cost 2.4× vs v6.1** by letting the conductor build, inheriting the
  model, and moving bookkeeping into `ca`. Remaining overhead is mostly review
  (≈ 40% of wall time on complex tasks) and review-triggered rework.
- **Review earns its cost only when it runs the change.** Reading code missed
  the framework's default error page; once the reviewer was told to exercise
  unhandled methods and query-language special characters, medium went to 100%
  in 2/2 runs — at roughly 2× the cost of the reading-only review.
- **Run-to-run variance is large** (job queue: $1.12 → $1.96 on the same
  design). One run per setup cannot separate small changes.

## Caveats

- The `SpecEdges` / `Errors` hidden tests were added after a plugin review
  surfaced them, and the latest prompts name those defect classes. They are
  genuine stated requirements, but the plugin's 100% on them is partly taught.
  A held-out set of spec-edge checks that no prompt mentions is needed.
- Runs executed concurrently on one machine; wall times include that noise.
- Spend for this round: ≈ $61 across 31 scored runs (+ ≈ $16 for evals, probes,
  and one stopped run).
