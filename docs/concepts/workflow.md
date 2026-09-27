# Workflow

The runtime is one evidence-gated loop run by the conductor. Its **lane**
(quick, standard, deep) sets how much ceremony surrounds the work; it never
changes what counts as proof. Consequential, visual, or deployable work also
activates more of the same gate sequence.

## 1. Entry

The conductor first decides whether the request needs a ledger.

- Questions and read-only research are answered directly.
- A code, configuration, test, documentation, or deployment change opens or
  resumes a feature ledger.
- Existing user changes are snapshotted and preserved before delegation.

The conductor picks a lane and opens the feature. In the quick and standard
lanes it frames and freezes in the same call:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/ca.sh" start <feature-slug> --lane quick --answer "<the user's words>" < frame.md
```

| Lane | Use when | Builds | Review | Planner |
|---|---|---|---|---|
| quick | small fix, no UI / architecture / deploy | conductor | none, while `reviewed?` measures the diff since `base` at ≤ 150 lines with no ui/consequential/deploy tags | no |
| standard (default) | features, services, multi-file changes | conductor | one read-only reviewer | architecture questions only |
| deep | user asks, or a one-way door | developer workers | reviewer + optional dimension fan-out | frame + ADR |

Why the conductor builds in the quick and standard lanes: a subagent starts
from nothing and re-reads the code, so delegating the writing multiplies cost
without adding judgment. Measured on the bench (`bench/`), delegating every
build cost 7–12× native Claude Code for the same hidden-test quality.
Specialists are dispatched where a *separate* agent adds something: independent
review, architecture options, diagnosis, the design surface, deployment.

## 2. Ordered gate loop

```text
┌─────────┐   ┌─────────────┐   ┌──────────┐   ┌────────┐
│ framed? │──►│architected? │──►│designed? │──►│proven? │
└─────────┘   └─────────────┘   └──────────┘   └───┬────┘
                                                    ▼
┌───────────┐   ┌──────────┐   ┌────────┐   ┌───────────┐
│ observed? │◄──│ shipped? │◄──│ clean? │◄──│ reviewed? │
└───────────┘   └──────────┘   └────────┘   └───────────┘
```

`ca next` runs every gate in order and prints the next action; every other
`ca` step ends by printing it too. At each step the conductor:

1. takes the first applicable unmet gate;
2. does the work (quick/standard) or dispatches the owning kind;
3. verifies any worker’s paths and evidence against the dispatch scope;
4. records a concise ledger log entry, including skips and assumptions;
5. advances only on `pass` or `n/a`.

## 3. Framing

The conductor (quick/standard) or the planner (deep) converts a request into
observable intent:

- goal and problem rather than an assumed solution;
- explicit scope and non-goals;
- observable acceptance criteria;
- affected surfaces (`touches:`);
- deployment applicability;
- verification tiers and exact commands;
- consequential architecture marker;
- open questions.

The conductor shows the frame to the user and freezes it with the user’s actual
reply. A later intent revision reopens `framed?`.

## 4. Architecture dialogue

Architecture is handled before an ADR, not as a post-hoc approval form.

### System-level scan

The planner checks whether the feature changes:

- service or process boundaries;
- data ownership or persistence model;
- public API, event, or compatibility contracts;
- authentication, authorization, or trust boundaries;
- deployment topology and external dependencies;
- irreversible migration or rollout strategy.

### Component-level scan

For each substantial component, the planner checks:

- responsibility and boundary;
- public interface and callers;
- dependencies and direction of coupling;
- invariants and failure behavior;
- observability and test seams;
- rollout, rollback, and backward compatibility.

### Dialogue path

```text
unresolved choice changes the design?
       │
       ├── yes ─► planner returns needs-input + 1–3 bundled questions
       │                │
       │                └─► conductor asks user, records answers, redispatches
       │
       └── no ──► planner drafts ADR with options and trade-offs
```

Low-stakes reversible defaults are allowed only in small number and must be
reported. Discovery is not a failed gate. When the resulting ADR contains a
one-way door, the conductor asks for separate explicit agreement before build.

## 5. Visual design

When `touches:` includes `ui`, the designer writes a look-contract and opens the
localhost review surface. The user comments and approves in the browser.

Approval is bound to the SHA-256 digest of `design.html` and to zero open
comments. The designer may record the verdict but cannot create it, and
`designed?` re-verifies the verdict on every run rather than trusting the
recorded command. Approval binds to the look-contract, not the source tree:
building the design does not reopen the gate, but editing `design.html` does.
Whether the build matches the approved design is a review question.

## 6. Build and prove

In the quick and standard lanes the conductor builds. In the deep lane it sends
developers a bounded brief, path scope, relevant ledger slice, pre-dispatch
snapshot, and named skills. Either way, whoever builds:

1. reads project instructions and peer files;
2. confirms the active test-discovery convention;
3. writes behavior-first tests, one per acceptance line;
4. implements within scope;
5. records every declared tier (`ca prove` wraps `lib/record.sh`);
6. (a worker) returns changed paths, evidence ids, open questions, and skips.

`proven?` requires all declared tiers to be green at the current tree. A UI
feature must declare an end-to-end tier that exercises the live path.

## 7. Review and repair

Review is a separate agent from whoever built, and it runs before the commit,
so the reviewer reads the working tree against the recorded `base`. Standard
work gets one read-only reviewer; deep work may fan out read-only dimensions
(correctness, security, simplicity) and then send one aggregate reviewer to write
`review.md`. The conductor records the verdict with `ca verdict`. The quick lane
skips review only while `reviewed?` measures the change as small and low-risk.

Findings use a load-bearing shape:

```text
- [blocking] path/to/file:42 — acceptance or correctness defect
- [advisory] path/to/file:77 — improvement that does not block delivery
```

Blocking findings route to a scoped build, then a fresh review. After the same
gate blocks twice with no new evidence id, the conductor stops and asks the user
rather than spinning.

## 8. Clean, commit, document

The conductor stages only attributable paths. `clean?` scans the staged diff for
staged coordinator state, obvious secrets, and raw debug prints. The conductor
then commits, and the git pre-commit gate re-runs `framed?` through `clean?`
and refuses the commit at the first block. That holds even when the model
skipped a gate or the commit message claims nothing.

When product behavior, architecture, component contracts, commands, or
deployment changed, the conductor refreshes portable consumer documentation:

- `docs/architecture.md` for system topology and component inventory;
- `docs/dataflow.md` for end-to-end movement and state transitions;
- `docs/components/<name>.md` for substantial component contracts;
- README, AGENTS, PRODUCT, DESIGN, docs index, or deployment guide only when
  their owned facts changed.

Each fact has one owning document; other files link instead of copying.

## 9. Ship and observe

Deployment is conditional and user-authorized. The deployer records the deploy
command and a separate health check. “Deployed” is an attempt; “observed healthy”
is the production claim.

An unhealthy observation routes to rollback using the last deploy tree that was
subsequently observed healthy, then to diagnosis.

## 10. Close and resume

The conductor rolls summary, learnings, and deployment outcome into
`product.md`, closes the feature, and pops `CURRENT`. If the feature interrupted
another one, that earlier ledger becomes active again.

On any new session, the resume hook injects the active ledger tail. Running the
ordered gates reconstructs the exact next action.
