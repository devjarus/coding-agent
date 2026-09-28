# The goal

coding-agent exists for what native Claude Code cannot supply by itself:
**continuity** across sessions, adherence to a project's **standards**, and
**speed**. On the same model and the same tasks, it must win at least one of
continuity or standards without falling below native on plain correctness.
If it wins neither and is slower, it is not worth running.

## What the plugin promises, and how each promise is tested

Evals come first: the architecture changes only to move one of these numbers.

| Promise on a long-running project | Behaviour tag | Tested by |
|---|---|---|
| A convention agreed once holds in every later feature | `conv` | `longrun-library`: error envelope, ID prefixes, list envelope, `Z` timestamps, checked on features built sessions later |
| A changed decision replaces the old one — for existing code and all later work | `dec` | session 4 changes page size (20/100 → 50/200); every list endpoint, old and new, is checked |
| Work parked for later is built when asked for by reference only | `defer` | holds (specified in session 3) and borrowing limits (session 8), requested in session 10 as "everything we said we'd do later" |
| A killed session is finished from the repo alone | `resume` | session 6 is killed at 12 turns; session 7 says only "pick up where it left off" |
| Features keep working as the codebase grows | `feat` | every session re-runs all earlier sessions' hidden tests |
| Memory that every session pays for stays bounded | memory | bytes auto-loaded per session (CLAUDE.md + its imports), measured after every session |
| The repo's written rules are followed | standards | `standards-orders` |
| No slower than native | speed | suite wall time |

Each tag is isolated: only `conv` tests check the envelopes, so drifting from a
convention costs `conv` points without also failing the feature built on it.
`bench/tasks/longrun-library/hidden/` was mutation-checked against the reference
(stale page size, flat errors, integer IDs, no holds, no limits, no reviews,
bare lists): each mutation fails only its own behaviour, plus the tests that
cannot exist without the missing feature.

Behaviour scores are pooled over every scored session, not read at the end: a
later session can repair earlier drift (a retroactive decision did exactly that
in the first native run), but the sessions in between still shipped it.

`longrun-library` is 11 sessions. `feat`/`conv`/`dec`/`defer`/`resume` floors
and the memory cap are absolute targets in `goal.json` — the plugin must meet
them whatever native scores; native's row shows whether a plugin is needed at all.

## Targets (`bench/goal.json` is the source of truth)

| Pillar | Measured by | Target |
|---|---|---|
| **Continuity** | `longrun-library` (11 sessions, per-behaviour floors above) and `continuity-inventory`: one codebase over five fresh sessions. Conventions are stated only in session 1; session 3 is killed mid-change and session 4 is told only "pick up where it left off"; session 5 only "build the thing we said we'd do later". | quality ≥ native + 5 pts |
| **Standards** | `standards-orders`: an existing repo whose `AGENTS.md` sets house rules (logger, error type, numbered migrations, tests, docs, changelog) that the request never restates. Hidden checks verify the rules, not just the feature. | quality ≥ native + 5 pts |
| **Speed** | suite-wide wall time | ≤ 1.0× native |
| Correctness floor | single-session tasks (small fix, REST service, complex apps, job queue) | ≥ native |
| Cost floor | suite-wide spend | ≤ 1.5× native |

**Verdict rule:** worth running if it wins continuity or standards while holding
the correctness floor. Wins neither and is slower → retire it.

Hidden acceptance tests score everything: the agent never sees them, and they
run after each phase including earlier phases' tests.

## Rules of the comparison

1. Same prompt, same seed repo, same machine, and the same pinned model
   (`--model`, default `claude-sonnet-5`; subagents inherit it). The only
   difference is `--plugin-dir`.
2. The plugin arm loads the plugin exactly as users do (registered agents,
   hooks, conductor as main agent), from a snapshot that excludes `bench/`, so
   the hidden tests are unreachable.
3. Runs happen outside the repository, so no agent can walk up to the tests.
4. One rep is directional. Claims need `min_reps_to_claim` reps per arm.
5. Architecture changes are justified by a scoreboard delta, and a component
   that does not move a number is a candidate for deletion.
6. Hidden suites may grow when a **stated** requirement turns out to be
   untested (bench v2 added JSON-error and literal-search checks after a plugin
   review surfaced them). When they grow, re-score every run with
   `bench/rescore.py` so both arms are measured by the same suite, and record
   where the new check came from.

Latest numbers and what they mean: [RESULTS.md](RESULTS.md).

## How to use it

```bash
bench/selftest.sh                           # zero cost: hidden tests pass on references
bench/run.sh small-pricing-fix --arm both   # one task, both arms
bench/run.sh all --arm both --reps 3        # the full claim
bench/report.py <results-dir>...            # scoreboard vs goal.json
bench/rescore.py <results-dir>...           # re-score after the hidden suites change
```
