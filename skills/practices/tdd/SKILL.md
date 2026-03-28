---
name: tdd
description: Test-driven development process — write failing test, implement to pass, refactor. Use when implementing any feature or fixing bugs.
---

# Test-Driven Development (TDD)

## The RED-GREEN-REFACTOR Cycle

TDD is a discipline: you do not write implementation code until a failing test demands it.

1. **RED** — Write a test for the next small behavior. Run it. It must fail (confirming the test actually exercises real code).
2. **GREEN** — Write the minimum code required to make the test pass. Nothing more.
3. **REFACTOR** — Clean up the code (and tests) without changing behavior. Run the full suite to confirm nothing broke.

Repeat for every behavior.

---

## Rules

- **Never write implementation without a failing test.** If you reach for a file before writing a test, stop.
- **One behavior per test.** Each test should verify exactly one thing. If the test name requires "and", split it.
- **Run the full suite after GREEN.** A passing test that breaks another test is not GREEN.
- **GREEN means minimum code.** Hardcoding a return value to pass a test is valid — the next test will force generalization.
- **REFACTOR is not optional.** Skipping it accumulates design debt that compounds quickly.
- **Bug found = write a reproducing test first.** Make the bug visible as a failing test, then fix it. This prevents regressions.

---

## Test Design

### Naming
Name tests by the behavior they verify, not by the method they call.

- Bad: `test_calculate()`
- Good: `test_total_includes_tax_for_taxable_items()`

### Structure: Arrange-Act-Assert
Every test follows three phases:

```
// Arrange — set up inputs and dependencies
// Act     — call the unit under test
// Assert  — verify the outcome
```

Keep each phase visually distinct (blank lines or comments).

### What to test
- **Test the public interface**, not internal implementation details. Tests that reach into private methods break during refactoring.
- **One assertion per test** (or one logical concept). Multiple assertions obscure which behavior failed.
- **Use realistic inputs.** Edge cases are important, but start with a normal, representative case.

### Test scope
- Unit tests: isolate a single function or class. Mock collaborators.
- Integration tests: verify that two or more real components work together. Use sparingly in TDD cycles — they are slow.
- E2E tests: written after features are complete, not during TDD loops.

---

## When to Break the Rules

TDD is a discipline, not a religion. Two situations where you may skip the cycle:

1. **Exploratory spikes** — When you genuinely do not know if an approach is feasible, write throwaway code to find out. Delete it afterward and TDD the real implementation.
2. **Simple glue code** — Configuration files, framework boilerplate, and one-line adapters with no logic have little value under test. Use judgment.

In all other cases, follow RED-GREEN-REFACTOR.
