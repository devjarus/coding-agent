# Workflow

The runtime is one evidence-gated loop. It has no size-specific modes and no
parallel protocol stack. Small work has fewer applicable gates; consequential,
visual, or deployable work activates more of the same sequence.

## 1. Entry

The conductor first decides whether the request needs a ledger.

- Questions and read-only research are answered directly.
- A code, configuration, test, documentation, or deployment change opens or
  resumes a feature ledger.
- Existing user changes are snapshotted and preserved before delegation.

Initialization:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/ledger.sh" product-init
bash "${CLAUDE_PLUGIN_ROOT}/lib/ledger.sh" init <feature-slug>
```

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

At each step the conductor:

1. runs the first applicable unmet gate;
2. dispatches the owning kind when it blocks;
3. verifies the worker’s paths and evidence against the dispatch scope;
4. records a concise ledger log entry, including skips and assumptions;
5. reruns the same gate;
6. advances only on `pass` or `n/a`.

## 3. Framing

The planner converts a request into observable intent:

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

Approval is bound to SHA-256 digests of the reviewed artifacts and to zero open
comments. The designer may record the verdict but cannot create it. Any edit to
approved bytes reopens `designed?`.

## 6. Build and prove

The conductor sends the developer a bounded brief, path scope, relevant ledger
slice, pre-dispatch snapshot, and named skills. The developer:

1. reads project instructions and peer files;
2. confirms the active test-discovery convention;
3. writes behavior-first tests;
4. implements within scope;
5. runs every declared tier through `lib/record.sh`;
6. returns changed paths, evidence ids, open questions, and skips.

`proven?` requires all declared tiers to be green at the current tree. A UI
feature must declare an end-to-end tier that exercises the live path.

## 7. Review and repair

Review is a separate dispatch from implementation. The conductor may fan out
read-only dimensions—correctness, security, simplicity—then sends one aggregate
reviewer to write `review.md` and record the verdict.

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
obvious secrets and raw debug prints. `.coding-agent/` is never staged.

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
