# product: <name>

<!-- Read every session, so it stays short (close warns past 12 KB). Full
     feature rollups live in history.md, read only when a request points back
     at past work you cannot find here. -->

## vision
What this product is for, who it serves, what "good" means.

## current-state
Architecture-as-built, the stacks in play, the declared test command(s).

## conventions
<!-- Rules the user agreed that every future change must follow. One line each,
     ending with the test that enforces it — a contract test that discovers every
     instance from the code (all routes, all models), not a hand-written list:
     - every list endpoint returns {items, next_cursor} and honours limit — test: tests/test_conventions.py
     Use `test: none (<why it cannot be checked>)` only when no test can check it.
     proven? blocks while a line names no existing test. Only the user's words
     change a convention; a learning or a precedent in the code never relaxes one.
     Session start injects this section. -->

## decisions
<!-- ADRs append here; one per consequential decision. architected? reads this.
     Mark a replaced ADR `superseded-by: ADR-<n>`; once nothing in flight
     refers to it, move it to history.md to keep this file short. -->
<!-- ### ADR-1: <decision>  @<ts>
     - forces: <constraints in tension>
     - options: 1) <A> tradeoffs  2) <B> tradeoffs  3) <C> tradeoffs
     - chosen: <X> — because <which forces won>
     - door: two-way | one-way (one-way needs user agreement)
     - next seam: <where this is designed to bend later>
     - feature: <slug> -->

## backlog
Open threads and work the user deferred, with enough spec to build it later.
Delete an item when it ships.

## shipped
<!-- close keeps the newest 12, one line each; history.md has every rollup. -->

## learnings
<!-- close keeps the newest 10, one line each. A rule every later change must
     follow belongs in ## conventions with its test, not here. -->

## deployments
What is live, where, at which version.
