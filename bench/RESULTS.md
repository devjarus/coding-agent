# Long-horizon results — `longrun-library`, 11 sessions (same pinned model: claude-sonnet-5, n=1)

Behaviour scores pooled over every scored session; targets from `goal.json`.

| Arm | conv | dec | defer | resume | feat | Quality | Cost | Time | Memory it maintains | Ctx/turn s1 → s11 |
|---|---|---|---|---|---|---|---|---|---|---|
| native | 88% ❌ | 76% ❌ | 100% ✅ | 100% ✅ | 100% ✅ | 92% | $6.77 | 54 min | none | 45k → 49k |
| plugin v7 | 90% ❌ | 76% ❌ | 100% ✅ | 100% ✅ | 100% ✅ | 95% | $13.62 | 159 min | `product.md` 3.2 → 28.8 KB | 56k → 80k |
| *target* | ≥ 95% | ≥ 90% | ≥ 90% | ≥ 90% | ≥ 95% | | | | | |

**Both arms fail the same way, on one convention.** Every lost point is list
pagination: reviews, branches and holds (sessions 7, 8, 10) shipped without a
working `limit`/cursor in both arms. Native also missed members and member loans
in sessions 2-3 (repaired by session 4's "existing ones too"); the plugin did
not — that is its whole +3 pts. Deferred work, the killed session, error shapes,
IDs, timestamps and every feature held in both.

**The plugin's memory recorded the rule and then argued itself out of it.** In
session 8 it filed a learning: "Not every list endpoint needs cursor pagination
— GET /branches … unpaginated (like the reviews list)". Session 7's slip became
the precedent for session 8's. Prose memory carried the drift forward.

**Memory grows linearly.** `product.md` gains ~2.6 KB per feature (every learning
is stored twice: in the rollup and in `## learnings`). It is not auto-loaded, but
the conductor reads it; context per turn grew 42% over 11 sessions (native: 9%).
Native keeps nothing and forgets one rule; the plugin keeps everything and still
forgets it.

Two plugin sessions (10, 11) hit an account usage limit and were re-run from
the session-9 state with `run.sh --resume-from`; the aborted state is not scored.
Hidden tests were corrected three times during the run (timestamp input format,
list-envelope conv checks, page-size checks only under conv/dec); both arms were
re-scored against the final suite.

---

# Pillar results — continuity, standards, speed (same pinned model: claude-sonnet-5)

| Pillar | Task | Native | Plugin v7 `5e4dfe8` | Δ quality | Cost | Time |
|---|---|---|---|---|---|---|
| **Continuity** | continuity-inventory (5 fresh sessions) | 86% · $2.40 · 824 s (n=2) | **100%** · $6.54 · 2996 s (n=2) | **+14 pts ✅** | 2.7× | 3.6× |
| Standards | standards-orders (AGENTS.md rules) | 100% · $0.27 · 73 s (n=2) | 100% · $0.78 · 352 s (n=2) | +0 pts ❌ | 2.9× | 4.8× |
| Speed | suite | — | — | — | — | ❌ 2.5–4.8× slower everywhere |
| Correctness floor | five single-session tasks | see below | parity (−1 pt, one run) | held (within noise) | 3.0× | 2.5× |

**Verdict under the goal's rule: worth running for multi-session work** (it wins
continuity by 14 points on every run) — **not** for one-session work, where it
matches native's quality at ~3× the cost and 2.5–5× the time.

What made the difference: native kept the phase-1 API conventions in the code
of phase 1 only; by session 2 (both runs) it shipped `{"warehouses": [...]}`
instead of the agreed paginated `{"items", "next_cursor"}`, and repeated that for
movements and alerts. Resuming the interrupted session and the deferred request
both worked for native too. The plugin carried the conventions and the deferred
spec in `.coding-agent/product.md` (learnings, backlog) and committed docs.

That mechanism is cheap; the expensive parts (independent review, gates,
framing) are not what produced the win. The next experiment is a third arm:
the memory layer alone (session-start injection of product memory + a rule to
record conventions, decisions and deferrals) on native, to see whether it keeps
the +14 pts at near-native cost.

**Built-in auto-memory does not close the gap here.** A third arm ran native
Claude Code with `--settings '{"autoMemoryEnabled": true}'` (n=2): 86% on both
runs, the same tests failed as plain native, $1.90 and ~16 min per run — and no
memory file was ever written. In this environment (headless `claude -p`
inside a remote cloud session) auto-memory never produced a note, so this
shows it is not sufficient *as observed here*, not that it cannot work in an
interactive local session.

Two invalid runs caused by an account usage limit (sessions returning at $0)
were discarded and re-run; they are not in these numbers.

---

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
