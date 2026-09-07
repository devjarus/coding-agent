# coding-agent v5 — canonical design

> One ledger, one law, three moves, two roles. Everything else is derived.

This is the design spec for the v5 reimagining. It supersedes the v4 primitive
set (Actor / Artifact / Skill / Check). v4 grew to 6 agents + 59 skills +
12 protocols + 18 checks + 23 templates — most of which are scaffolding around
one valuable core: *making "done" mean demonstrably done.* v5 keeps that core
and deletes the scaffolding.

> **Implementation note (as built).** Where this document says one `worker.md`
> with seven kinds, the implementation splits it into **five kind-specific
> agents** — `planner` (frame · architect), `developer` (build · prove · review),
> `diagnostician` (diagnose), `designer` (design), `deployer` (ship) — so each carries only the
> tools its kinds need (Context7/Playwright for the developer, the design surface
> for the designer, etc.). The spine, the single-writer law, and the dispatch
> model are unchanged; only the packaging differs. An eighth gate, `reviewed?`
> (with the `review` kind), was added after this spec. See `v5/agents/` and
> `v5/PLAN.md` for the current shape.

---

## 1. The axiom

> **No claim advances without evidence. Evidence is recorded by execution,
> never written by the agent.**

Every gate, recorded-verify, and "tests-actually-committed" check in v4 is a
partial expression of this one invariant. Make it the axiom and the machinery
becomes derivable.

The agent typing *"tests pass ✅"* produces **nothing**. The only path that
writes verification into the system is `record.sh`, which runs a real command
and captures `{cmd, exit, stdout_sha, tree_sha, at}`. Gates read those entries,
not prose. Fabrication isn't policed after the fact — it is structurally inert.

---

## 2. The three core primitives

### 2.1 Ledger — the only memory

Append-only, single-writer (the conductor). Resume = read the tail.
**Two altitudes, one primitive:**

- **Product ledger** — `.coding-agent/product.md`, one per project, never
  closes. Sections: `vision · current-state · decisions(ADRs) ·
  backlog(threads) · learnings · deployments`. This is the *evolution* surface;
  architecture decisions live here because they outlive any one feature.
- **Feature ledger** — `.coding-agent/<feature>/ledger.md`, one per unit of
  work, completes and rolls up into the product ledger.

```markdown
# ledger: <feature>
## intent     ← frozen once user-agreed (revisions re-open framed?)
## plan       ← frozen once user-agreed (revisions appended, never edited)
## log        ← append-only narrative, newest last
## evidence   ← pointer only; real entries live in evidence.jsonl
```

Frozen sections give immutability without separate "approved artifact" files.

### 2.2 Evidence — reality, recorded

`evidence.jsonl`, append-only, written by exactly one script (`record.sh`) and
nothing else — enforced by the single mechanical wall (§5).

```jsonl
{"id":4,"cmd":"pytest -q","exit":0,"stdout_sha":"a91f…","tree_sha":"3bd2…","at":"…"}
```

`tree_sha` binds the proof to the exact code. A passing entry against stale code
does not count — proofs expire when the tree moves. This is the v4 "sha-bound
verdict" generalized to all verification.

### 2.3 Gate — a predicate over the ledger

Deterministic `ledger → pass | block | n/a`. **Conditional gates that don't
apply pass vacuously (n/a)** — this is how one lifecycle serves every arc size
without a "mode" switch (see §6, arc sizing).

| Gate | Passes when | Applies when |
|---|---|---|
| `framed?` | intent frozen + user-agreed | always (may be one line) |
| `architected?` | decision record: ≥2 options weighed, evolution path noted, one-way doors user-agreed | change is structurally consequential |
| `designed?` | surface verdict bound to current design | intent touches UI |
| `proven?` | evidence has `exit:0` entry at current `tree_sha` | a code change exists |
| `clean?` | staged diff: no secrets, no raw debug prints | a commit is imminent |
| `shipped?` | deploy `exit:0` + health check, tree-bound | intent requires deploy |
| `observed?` | post-deploy smoke/health recorded; learnings rolled up | after ship |

`commit-gate = proven? && clean?` is composition, not a new script.

---

## 3. The two resources (not primitives)

- **Skill** — injected knowledge, on match. Demoted from core primitive. Keep
  only the ~dozen that encode what the model doesn't reliably know (stack
  conventions, prototype-first mode, domain gotchas). Drop anything that
  restates general practice. Count is derived by the validator, never hand-synced.
- **Role** — a bounded context, justified only by *focus* or *parallelism*.

---

## 4. The two roles

### 4.1 Conductor — the single writer

Owns the ledger, runs gates, dispatches workers, never writes code. The loop:

```
1. read ledger tail + evidence.jsonl
2. find first applicable gate not yet passed
3. needs work?  → dispatch worker(kind), scoped to that gate
4. worker returns its kind-specific contract (including omissions and questions)
5. append summary to ## log
6. re-run the gate; PASS → advance; BLOCK → route (§7); else loop
```

This single loop replaces all 12 v4 protocols. Recovery is free (a fresh session
re-enters at step 2). Redirect is an appended plan revision.

### 4.2 Worker — stateless, one spine, seven kinds

One archetype. Same **contract** (the spine), different **craft** (the kind).

**Spine (identical for every worker):** verify only via `record.sh`; write
nothing to the ledger (the conductor is the sole writer); return `did`,
`changed_paths`, `open_questions`, and `skipped_or_assumed`; do exactly the
scoped brief. Execution kinds also return `evidence_ids` and `gate_status`.
Planning kinds return `status`, a paste-ready `artifact`, and — when
`status: needs-input` — structured `questions` whose options name their
consequences.
Every worker also carries the operating principles (§12.1); the kind adds its own
principle set.

**Kinds (the swapped block):**

| kind | definition of done | evidence produced |
|---|---|---|
| `frame` | intent + plan drafted for agreement | — (text) |
| `architect` | options weighed, decision + evolution path recorded | ADR in product ledger |
| `design` | user-approved look-contract | sha-bound surface verdict |
| `build` | code implements the plan | — (gated at prove) |
| `prove` | verification run | test/build run, tree-bound |
| `diagnose` | repro captured, fix proven | red repro → green repro |
| `ship` | deployed + healthy | deploy exit + health, tree-bound |

The spine is shared across the worker agents; kinds are compact playbooks. Variation
enters at **dispatch**: the conductor sends `kind=<x>` + scoped brief + skills.

---

## 5. The single mechanical wall

Everything is prompt-enforced except the one invariant the prompt approach has
historically lost to: evidence fabrication. One hook guards it.

```
PreToolUse [Edit|Write where path ends in evidence.jsonl]
  → block unless the writer is record.sh
```

One wall, guarding the one thing that matters. (Honors the standing preference
for prompts over enforcement everywhere else.)

---

## 6. The lifecycle and arc sizing

```
Frame → [Architect] → [Design] → Build → Prove → [Ship → Observe]
```

There is **no mode switch.** Arc size is an emergent property of which gates
apply:

- **Direct (no ledger)** — research / Q&A / a one-line answer. The conductor's
  first decision is `worth_a_ledger?`. Below it: answer directly, zero ceremony.
- **Quick** — a small change. `framed?` is one line, `designed?` is n/a,
  `shipped?`/`observed?` may be n/a. Ceremony = the few applicable gates.
- **Full** — the whole arc, every gate applicable.

Ceremony scales with the work because *cost = sum of applicable gates*. The
**law holds at every size** — even a one-line fix records evidence. Only the
ceremony flexes, never the proof.

---

## 7. Branch & failure paths (every gate has a fail edge)

A gate never silently advances. On `BLOCK` the conductor routes:

| Situation | Route |
|---|---|
| `proven?` fails (tests red) | dispatch `diagnose` (repro is already the failure) |
| `designed?` rejected on the surface | re-dispatch `design` with the comment thread |
| `shipped?` fails (deploy errors) | dispatch `diagnose`; revert if partial |
| `observed?` fails (health red post-deploy) | **rollback**: `ship` revert to last good `tree_sha`, then `diagnose` |
| requirements change mid-flight | append plan revision (plan change) or intent revision (re-opens `framed?`) |
| material intent change | new feature ledger; old one closes as superseded |

`diagnose` is not a separate machine — it is the same Frame→Build→Prove loop
entered from a symptom, where the law forces *repro-before-fix*: the first
evidence entry is the red repro; the fix isn't `proven?` until that repro is
green at the current tree.

---

## 8. The design surface (conversational)

A small local web app the `design` worker drives:

- **renders** the current look-contract / running UI,
- holds an **append-only comment thread** (same shape as the ledger),
- loops render → comment → revise until you approve,
- records a **sha-bound verdict** into `evidence.jsonl`.

`designed?` reads that verdict. Change the design after approval → verdict goes
stale → gate re-opens. This is the only place a local server earns its keep in
v5, because the value is *seeing and reacting*.

**Prototype-first interaction:** when design emerges from a running prototype
rather than a static contract, `designed?` evaluates *after* build — the surface
reviews the running thing. The gate still holds; it just moves later in the arc.

---

## 9. Product evolution (closing the loop)

```
ship → observe → learnings → (product backlog) → frame next
```

Closing a feature appends its summary + learnings + deployment record to the
product ledger. Starting work reads the product ledger to pick and frame the
next thing. That feedback path *is* "evolve product" — the same signal the team
already mines by hand from `.coding-agent/` artifacts.

**Writer discipline:** the session conductor is the sole writer of `product.md`.
Concurrent feature sessions serialize through append-only writes (last-writer-
append; conflicts are line-additive, not edits). Known constraint, not a bug.

---

## 10. What v5 deletes

| v4 | v5 |
|---|---|
| 23 templates | 1 ledger template (2 altitudes) |
| 18 checks | ~6 gates (predicates over the ledger) |
| 12 protocols | 1 conductor loop |
| 6 agents | 2 roles (conductor + worker×7 kinds) |
| 59 skills | ~12 knowledge resources |
| hand-synced counts | derived by the validator |
| `last-verify.json` + ad-hoc verify | `evidence.jsonl` + `record.sh`, wall-protected |

The verification spine hardened across all of v4 isn't thrown away — it is
*promoted to the axiom*, and everything else is deleted around it.

---

## 11. File layout

```
coding-agent/
├── .claude-plugin/plugin.json
├── agents/
│   ├── conductor.md          # the loop + single-writer law
│   ├── planner.md  developer.md  diagnostician.md  designer.md  deployer.md
├── principles.md             # the craft plane: operating · build · prove · review · architect
├── skills/                   # ~12, lightly grouped
├── gates/
│   ├── lib.sh  framed.sh  architected.sh  designed.sh  proven.sh  reviewed.sh  clean.sh  shipped.sh  observed.sh
├── lib/
│   ├── record.sh             # the only writer of evidence.jsonl
│   └── ledger.sh             # read-tail / append-log / freeze-section
├── surface/                  # the conversational design app (local server)
├── hooks/hooks.json          # SessionStart resume + the evidence wall
├── product.template.md  ledger.template.md
└── scripts/validate.sh       # derives all counts
```

---

## 12. Principles — the craft plane

The control plane (§1–§11) says *when* work advances. The craft plane says *how
it should be done well.* It lives in one file, `principles.md`, in tiers. The
spine carries the operating tier; each worker kind adds its own tier.

**Binding rule:** a principle must change a decision or a gate. If it changes
neither, it is a comment — delete it. This is what keeps the craft plane from
becoming the next 58-skills sprawl.

### 12.1 Operating principles (spine — every worker)

1. **Evidence over assertion.** A claim with no recorded evidence is noise. (the law)
2. **Smallest step that clears the next gate.** No gold-plating, smallest reversible diff.
3. **Read before you write.** Understand the existing code and its conventions first.
4. **Match the surrounding code.** Consistency beats personal taste.
5. **Say what you didn't do.** Surface skips, assumptions, and uncertainty plainly.
6. **Stop at the gate.** Don't expand past the scoped brief.

### 12.2 Code-craft principles (`build`)

1. **Simplest thing that works; deletability over cleverness** (YAGNI).
2. **Make illegal states unrepresentable;** push errors earliest (compile > runtime > prod).
3. **Abstract on the third repetition,** not the first (rule of three).
4. **Boundaries explicit; dependencies point toward the stable core.**
5. **Name for intent, not mechanism.**
6. **Clean within scope only** — no drive-by refactors that bloat the diff.

### 12.3 Testing principles (`prove`, and `build` writes the test)

1. **Test behavior at the seam, not implementation details.**
2. **A test that can't fail proves nothing** — every new behavior ships with a
   test that fails in its absence. *(This is the close for residual risk #1:
   `proven?` requires not just a green run but a test that exercises the new
   behavior — a hollow `echo ok` cannot satisfy it.)*
3. **The first test of a bug is its repro** (drives `diagnose`).
4. **Few honest integration tests over many mock-heavy unit tests.**
5. **Tests are committed code,** the evidence `proven?` consumes — never ad-hoc.
6. **Coverage is a detector, not a target.**

### 12.4 Architecture principles (`architect`)

1. **Optimize for change** — the only certainty is that requirements move.
2. **Boundaries are the architecture;** the rest is detail you can revisit.
3. **Defer irreversible decisions to the last responsible moment;** name the one-way doors.
4. **Every choice is a trade-off** — record what you trade away, not just what you pick.
5. **Evolve, don't rewrite** — prefer the strangler-fig seam over the big-bang.
6. **Keep the expensive-to-change things few and explicit.**

---

## 13. The architect deep-dive

`architect` is a distinct kind, not a line in `frame`, because consequential
structure deserves its own cognitive mode and its own evidence. It fires through
the conditional `architected?` gate when a change is **structurally
consequential**: a new service/module, a new data model, a new external
dependency, a cross-cutting change, or any **one-way door**. For routine changes
the gate is vacuous (like `designed?` for non-UI work).

Before drafting the ADR, the architect runs a short discovery dialogue when
material unknowns remain. It evaluates both **system-level** choices (topology,
ownership, data flow, deployment, one-way doors) and **component-level** choices
(public contracts, state ownership, invariants, failure behavior, and seams).
It returns `needs-input` with one to three bundled questions; the conductor asks
them in the main conversation, records the answers in the ledger, and
redispatches the architect. This is discovery, not approval: a one-way-door ADR
still requires the separate user-agreement evidence enforced by `architected?`.
At most two reversible, low-stakes defaults may be assumed and must be named in
the return contract.

**Definition of done — an ADR appended to product ledger `## decisions`:**

```markdown
### ADR-<n>: <decision>  @<ts>
- forces: <constraints / non-negotiables in tension>
- options:
  1. <A> — trade-offs, cost-to-change
  2. <B> — trade-offs, cost-to-change
  3. <C> — trade-offs, cost-to-change
- chosen: <X> — because <which forces won>
- door: two-way (reversible) | one-way (needs user agreement)
- next seam: <where this is designed to bend later>
```

The **options** and **next seam** fields are what make architecture *evolve*
rather than ossify: every decision names the cheaper alternatives it beat and
the joint where the next change is meant to enter. Because ADRs live in the
durable product ledger, the architecture's evolution is a readable history, not
folklore — and the same record feeds the `learnings` loop in §9.

**Gate teeth:** `architected?` blocks `build` on consequential changes until the
ADR exists, and on one-way doors until the user has agreed. This is the one place
v5 deliberately *adds* friction — because an unrecorded, unweighed one-way door
is the most expensive mistake the agent can make.

---

## 14. Runtime composition — how a worker knows its role

There is no per-role system prompt. An agent's context is assembled from **two
layers**, mapping directly onto how Claude Code subagents run:

- **Static system prompt** — the agent `.md` body. Invariant across every
  invocation.
  - `conductor.md`: the loop (§4.1), the single-writer law, the dispatch
    protocol, the concurrency rules (§15).
  - each worker agent (`planner`/`developer`/`diagnostician`/`designer`/`deployer`): the spine
    (§4.2) + operating principles (§12.1) + the return contract + "you act as
    exactly one kind, named in your brief."
- **Dynamic dispatch** — the free-form task prompt the conductor writes when it
  spawns the worker. This is where per-invocation variation enters.

**The kind is chosen at dispatch, not baked into a prompt.** Each worker agent
covers a small set of related kinds; the conductor names the exact kind in the
brief — which is why the kinds map onto five agents, not one-file-per-kind. The
dispatch message schema:

```
kind     = build
gate     = proven?
brief    = "implement plan step 3: POST /orders handler"
context  = <scoped ledger slice — intent + plan step 3, not the whole ledger>
skills   = [backend, testing]
scope    = src/orders/**          # files this worker may touch
isolate  = worktree | none        # set when run in parallel (§15)
```

**Are principles injected?** Layered, not blobbed — one copy of each, never
duplicated:

- **Operating principles (12.1)** are static in every worker agent — each worker
  always carries them.
- **Kind principles (12.2–12.4)** are *pulled by reference*: the dispatch names
  the kind, and the worker reads `principles.md#<kind>` + its playbook. The
  conductor injects the pointer and the scoped brief, not the principle text.
- **Skills** are preloaded via frontmatter or named in `skills=`.

So the resolved worker context = `static spine` + `dispatch brief` +
`pulled kind-tier`. The conductor never copies craft text into the prompt; it
points, and the worker reads. (Derive, don't duplicate.)

---

## 15. Concurrency — the single-writer law *is* the parallelism model

Because workers are **stateless and write nothing to the ledger**, N of them run
concurrently with zero coordination. The conductor is the sole **fan-out /
fan-in** point:

```
conductor: dispatch batch  →  [worker, worker, worker]  (concurrent)
           await all       →  fold each result into the ledger ONE at a time
           run the gate    →  advance
```

The single-writer law is what makes this safe: parallel workers cannot race the
ledger because none of them touch it. `record.sh` serializes evidence id
allocation and append behind a portable lock, so concurrent proof workers also
produce unique, complete entries.

**Where parallelism pays (within a move, never across moves):**

| Pattern | Fan-out |
|---|---|
| `architect` option-exploration | one worker per option → conductor (or a judge) picks; ADR records the winner + the beaten alternatives. The deep-dive is *naturally* a judge panel. |
| `build` on disjoint files | one worker per independent plan step, each `isolate=worktree` or scoped to non-overlapping paths; conductor owns the merge. |
| `prove` across dimensions | correctness · security · perf in parallel, each returning its own evidence. |
| `review` across dimensions | read-only reviewers return findings → one aggregate reviewer writes `review.md` and its verdict. |
| `frame` research sweep | parallel readers over subsystems → one framed intent. |

**File safety:** parallel `build` workers either take disjoint `scope` globs or
run in worktree isolation; the conductor merges and only *then* runs `proven?`
against the merged tree (so `tree_sha` binds to the real combined state).

**Where it does *not* parallelize:** the gates are sequential by nature — you
cannot `prove` before `build`, or `ship` before `prove`. Parallelism lives
*inside* a move (N builds, N options, N prove-dimensions), and the conductor
re-serializes at the fold. The lifecycle stays a line; only each move can widen.
