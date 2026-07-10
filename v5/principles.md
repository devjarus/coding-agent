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

## prove  (testing — `build` writes the test, `prove` runs it)
1. **Test behavior at the seam, not implementation details.**
2. **A test that can't fail proves nothing** — every new behavior ships with a test
   that fails in its absence. (This is why `proven?` requires `kind=test`, not any green run.)
3. **The first test of a bug is its repro** (drives `diagnose`).
4. **Few honest integration tests over many mock-heavy unit tests.**
5. **Tests are committed code,** the evidence `proven?` consumes — never ad-hoc.
6. **Coverage is a detector, not a target.**

## architect  (architecture)
1. **Optimize for change** — the only certainty is that requirements move.
2. **Boundaries are the architecture;** the rest is detail you can revisit.
3. **Defer irreversible decisions to the last responsible moment;** name the one-way doors.
4. **Every choice is a trade-off** — record what you trade away, not just what you pick.
5. **Evolve, don't rewrite** — prefer the strangler-fig seam over the big-bang.
6. **Keep the expensive-to-change things few and explicit.**
