# The goal

coding-agent exists to build, maintain, and extend software **better than the
agent it runs on**. "Better" is measured, not asserted: on identical tasks, the
plugin must beat native Claude Code on quality *and* not lose on cost or time.

## Targets (`bench/goal.json` is the source of truth)

| Scope | Quality (hidden-test pass rate) | Cost vs native | Wall time vs native |
|---|---|---|---|
| **Suite** (all tasks) | ≥ native | ≤ 1.0× | ≤ 1.0× |
| Small (maintenance fix) | ≥ native | ≤ 1.5× | ≤ 1.5× |
| Medium (new service) | ≥ native | ≤ 1.2× | ≤ 1.2× |
| **Complex** (app + change request) | **≥ native + 10 points** | ≤ 1.0× | ≤ 1.0× |
| Integrity (plugin only) | 0 commits that bypassed the gate | — | — |

Why these shapes:

- **Quality is judged by hidden acceptance tests** the agent never sees, run
  after each phase, including regressions of earlier phases. Neither arm can
  game them, and "tests pass" claims count for nothing.
- **Complex work is where process must pay for itself.** A harness that only
  matches native there is pure overhead, so it has to win by a margin.
- **Small work may cost a little more, never a lot.** Some fixed overhead is the
  price of evidence; a 10× tax on a one-line fix is a design failure.
- **Suite-wide cost and time must not exceed native.** Savings on complex work
  (less rework, cheaper workers, deterministic scripts instead of model turns)
  have to fund the overhead on small work.

## Rules of the comparison

1. Same prompt, same seed repo, same main model, same machine. The only
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

## How to use it

```bash
bench/selftest.sh                           # zero cost: hidden tests pass on references
bench/run.sh small-pricing-fix --arm both   # one task, both arms
bench/run.sh all --arm both --reps 3        # the full claim
bench/report.py <results-dir>...            # scoreboard vs goal.json
bench/rescore.py <results-dir>...           # re-score after the hidden suites change
```
