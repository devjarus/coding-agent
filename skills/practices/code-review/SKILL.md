---
name: code-review
description: Systematic code review process for domain leads reviewing specialist output. Covers correctness, security, performance, and convention compliance.
---

# Code Review

A structured checklist for domain leads reviewing specialist-produced code. Work through each section in order — correctness first, then the rest.

---

## Checklist

### 1. Correctness
- [ ] Does the code satisfy the acceptance criteria in the task contract?
- [ ] Are edge cases handled (empty input, zero, null, large values, boundary conditions)?
- [ ] Is error handling present and correct for all failure paths?
- [ ] Does the logic match the intended algorithm? Trace through a representative example.
- [ ] Are there off-by-one errors, incorrect comparisons, or missed negations?

### 2. Security
- [ ] Is all external input validated (type, length, format, allowed values)?
- [ ] Are SQL queries parameterized (no string concatenation)?
- [ ] Is output encoded for the rendering context (HTML encoding, JSON escaping)?
- [ ] Are CSRF protections in place on state-mutating endpoints?
- [ ] Are there hardcoded secrets, tokens, or credentials anywhere?
- [ ] Are authorization checks present — not just authentication but resource-level ownership checks?

### 3. Performance
- [ ] Are there N+1 query patterns (a query inside a loop)?
- [ ] Is there unnecessary computation inside hot paths or loops?
- [ ] Are large data structures copied where a reference would suffice?
- [ ] Are expensive operations (network calls, disk I/O) performed synchronously when they could be async or deferred?

### 4. Conventions
- [ ] Does the code follow patterns established in `CLAUDE.md` and the codebase?
- [ ] Are names clear, consistent with existing naming conventions, and self-documenting?
- [ ] Is formatting consistent with the project's linter/formatter rules?
- [ ] Are new abstractions necessary, or does existing code already cover the need?

### 5. Tests
- [ ] Do tests exist for the changed behavior?
- [ ] Do tests verify behavior (not implementation details)?
- [ ] Are failure cases and edge cases tested?
- [ ] Do tests run and pass in CI?

### 6. Maintainability
- [ ] Can a new team member understand this code in 5 minutes?
- [ ] Are there magic numbers or unexplained constants? (They should be named.)
- [ ] Is the code modifiable without requiring deep knowledge of the surrounding system?
- [ ] Is there duplication that should be extracted into a shared utility?

---

## How to Give Feedback

**Be specific with location.** Reference `file:line` rather than describing the problem abstractly.

**Explain why.** "This is wrong" is not actionable. "This creates an N+1 query because `getUser` is called inside a loop — consider batching with `getUsersByIds`" is.

**Distinguish severity.** Use consistent labels so the author knows what must change versus what is optional:

| Label | Meaning |
|-------|---------|
| `blocker` | Must be fixed before merge. Correctness, security, or data-loss risk. |
| `major` | Should be fixed before merge. Performance, maintainability, or convention issue. |
| `minor` | Fix if you have time. Small improvements, style preferences. |
| `nit` | Trivial. Take it or leave it. |

**Offer alternatives.** When blocking a change, suggest a path forward. Don't just reject — help.

**Separate opinion from requirement.** Prefix personal preferences with "I'd prefer..." to distinguish them from objective issues.
