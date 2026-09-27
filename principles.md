# principles — the craft plane

How work should be done *well*. The control plane (gates) says when work
advances; this says how. Tiered: the spine carries the operating tier; each
worker kind pulls its own tier by reference.

> **Binding rule:** a principle must change a decision or a gate. If it changes
> neither, it is a comment — delete it.

## operating  (spine — every worker)
1. **Evidence over assertion.** A claim with no recorded evidence is noise.
2. **Smallest step that clears the next gate.** No gold-plating; smallest reversible diff.
3. **Read before you write.** Understand the existing code and its conventions first.
4. **Match the surrounding code.** Consistency beats personal taste.
5. **Say what you didn't do.** Surface skips, assumptions, and uncertainty plainly.
6. **Stop at the gate.** Don't expand past the scoped brief.

## build  (code-craft)
1. **Simplest thing that works; deletability over cleverness** (YAGNI).
2. **Make illegal states unrepresentable;** push errors earliest (compile > runtime > prod).
3. **Abstract on the third repetition,** not the first (rule of three).
4. **Boundaries explicit; dependencies point toward the stable core.**
5. **Name for intent, not mechanism.**
6. **Clean within scope only** — no drive-by refactors that bloat the diff.
7. **Every stated rule is an acceptance line with a test** — including error
   formats and inputs the spec says are literal.

## prove  (testing — `build` writes the test, `prove` runs it)
1. **Test behavior at the seam, not implementation details.**
2. **A test that can't fail proves nothing** — every new behavior ships with a test
   that fails in its absence. (This is why `proven?` requires `kind=test`, not any green run.)
3. **The first test of a bug is its repro** (drives `diagnose`).
4. **Few honest integration tests over many mock-heavy unit tests.**
5. **Tests are committed code,** the evidence `proven?` consumes — never ad-hoc.
6. **Coverage is a detector, not a target.**

## review  (`review` — reads the diff, records a verdict; writes no code)
1. **Review against the intent, not your taste.** The acceptance criteria and the
   ADR define "correct"; a nit is not a defect.
2. **Blocking vs advisory is the whole job.** Blocking = fails an acceptance
   criterion, or a security/correctness defect. Everything else is advisory —
   record it, don't gate on it.
3. **A green suite is not a clean review.** Look for what tests pass over:
   wrong-but-green logic, missing acceptance coverage, unsafe input handling.
   Two places drafts reliably miss: the **stated error contract on paths the
   code doesn't handle** (unknown routes and methods, malformed bodies, framework
   default error pages), and **user input reaching a query language** (SQL
   `LIKE`, regex, shell, glob) without escaping.
4. **Cite `file:line`.** A finding you can't point at isn't actionable.
5. **Don't fix — surface.** Reviewing and building are separate dispatches;
   the conductor routes the fix.

## frame  (`frame` — turning a request into an agreeable contract)
1. **Frame the problem, not the solution the user reached for.** "Add a cache"
   is usually "this page is slow"; write down the second one.
2. **Acceptance criteria are observable or they are decoration.** If nobody can
   run it, it cannot gate anything.
3. **Name the tiers honestly** — `proven?` demands exactly what you declare, so
   an omitted tier is a hole you cut yourself.
4. **Smallest scope that is still worth agreeing to.** Non-goals are as
   load-bearing as goals; they are what stops the arc from drifting.
5. **Ambiguity is an open question, never a default.** A guess frozen into an
   intent is the most expensive kind of guess.

## diagnose  (`diagnose` — root cause before fix)
1. **Reproduce before you theorize.** A failure you have not seen is a story.
2. **The repro is the contract:** the same command, red then green. Not a
   similar one.
3. **Name the cause in one sentence before touching code.** If you can't, you
   haven't isolated it — keep going.
4. **Reason about each probe before the next.** Probing without a hypothesis is
   collecting output, not debugging.
5. **Never weaken the test to reach green.** If the assertion is genuinely
   wrong, say so out loud; don't quietly relax it.
6. **Same bug twice means the model is wrong,** not that the fix needs one more
   attempt. Stop and re-derive.

## design  (`design` — the look contract)
1. **Show, don't describe.** The surface exists because product judgment is
   visual; a paragraph about a layout is not a layout.
2. **Design the states, not just the happy screen** — empty, loading, error,
   too-long text, no permission.
3. **The human approves, never the agent.** An agent approving its own design
   defeats the only gate the user actually looks at.
4. **Every comment is addressed or surfaced.** Silently papering over one is how
   the next round repeats.

## ship  (`ship` — deploy and observe)
1. **Never paper over a failure.** Report the real exit and the real output;
   a massaged deploy log is worse than a red one.
2. **Deployed is not healthy.** The health check is the claim; the deploy is
   only the attempt.
3. **Know the way back before you go forward** — the rollback target is a
   recorded tree, not a memory.
4. **Rollback is the conductor's call,** and it needs the last good tree, not
   the last good intention.

## architect  (architecture)
1. **Optimize for change** — the only certainty is that requirements move.
2. **Boundaries are the architecture;** the rest is detail you can revisit.
3. **Defer irreversible decisions to the last responsible moment;** name the one-way doors.
4. **Every choice is a trade-off** — record what you trade away, not just what you pick.
5. **Evolve, don't rewrite** — prefer the strangler-fig seam over the big-bang.
6. **Keep the expensive-to-change things few and explicit.**
