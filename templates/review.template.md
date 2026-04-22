---
artifact: review
feature: <slug>
writer: evaluator
mutability: immutable
state: active                    # ARTIFACT lifecycle: draft|approved|active|archived. Use `active` here. Close-out flips to `archived`. Do NOT confuse with task-state (in work.md § Tasks: ready|in-progress|complete|blocked|failed) or review status (## Status section: PASS|FAIL).
supersedes: null
mode: full                       # full | lightweight | smoke
---

# Review

## Status
PASS | FAIL                      # FAIL means findings must be fixed
Reason: <one line>

## Build Result
<success/failure, warning count>

## Test Results
- Unit: <N passed / M failed>
- Integration: <N passed / M failed>
- E2E: <N passed / M failed or N/A>
- Typecheck: <ok | N errors>

## Evaluation Criteria Results
| Criterion (from plan.md) | Result | Evidence |
|--------------------------|--------|----------|

## Spec Compliance
| FR | Status | Evidence |
|----|--------|----------|

## Findings
| ID | Severity | File:Line | Description | Fix Direction |
|----|----------|-----------|-------------|---------------|

## Screenshots                   # required for UI projects
- home.png — landing after login
- mobile-375.png — responsive at 375px

## Regressions
| Previous Finding | Still Present? | Evidence |

## Dispatch Recommendation
next_step: re-implement | debugger | done
reason: <why>
priority_findings: <IDs>
