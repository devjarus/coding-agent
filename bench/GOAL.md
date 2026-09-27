# The goal

coding-agent exists for what native Claude Code cannot supply by itself:
**continuity** across sessions, adherence to a project's **standards**, and
**speed**. On the same model and the same tasks, it must win at least one of
continuity or standards without falling below native on plain correctness.
If it wins neither and is slower, it is not worth running.

## Targets (`bench/goal.json` is the source of truth)

| Pillar | Measured by | Target |
|---|---|---|
| **Continuity** | `continuity-inventory`: one codebase over five fresh sessions. Conventions are stated only in session 1; session 3 is killed mid-change and session 4 is told only "pick up where it left off"; session 5 only "build the thing we said we'd do later". | quality ≥ native + 5 pts |
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
