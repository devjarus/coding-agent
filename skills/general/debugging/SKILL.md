---
name: debugging
description: A structured 4-step debugging process: reproduce, understand, hypothesize, verify. Use when encountering any bug, test failure, or unexpected behavior before proposing fixes.
---
# Debugging

## The 4-Step Process

### 1. Reproduce
- Capture the **exact error message** and stack trace
- Reproduce the failure **locally** before touching anything
- Build a **minimal reproduction** — the smallest input or code path that triggers the bug
- If you cannot reproduce it, you cannot verify a fix

### 2. Understand
- **Read the error carefully** — the message usually tells you what happened
- Walk the **stack trace from bottom to top** — the lowest frame is the origin, the top frame is where it surfaced
- Check **what changed recently** — git log, recent deploys, dependency updates, config changes
- Do not assume you know the cause before reading the evidence

### 3. Hypothesize
- Form a **specific, testable theory**: "The cache key includes the user ID but the session was not yet persisted, so the lookup returns null"
- Avoid vague theories: "something is wrong with the database"
- One hypothesis at a time

### 4. Verify
- Make the **smallest possible change** that would prove or disprove your hypothesis
- Use **logs or a debugger** at the suspected location — confirm actual values, not assumed ones
- Check that removing your fix re-introduces the bug (proves causality)
- Do not move to the next hypothesis until the current one is falsified

## Fixing
- Fix the **root cause**, not the symptom
- Write a **test that reproduces the bug first**, then make it pass — this prevents regression
- After fixing, search the codebase for the **same pattern** elsewhere

## Anti-Patterns to Avoid
| Anti-pattern | Why it is harmful |
|---|---|
| Making random changes until it works | Creates new bugs; you do not understand what you fixed |
| Wrapping in try/catch to silence errors | Hides problems; they resurface later in unexpected ways |
| "Works on my machine" | Environment differences are bugs too; make them reproducible |
| Print-only debugging without forming a hypothesis | Generates noise without narrowing the search space |
| Fixing the symptom (e.g., null check) instead of the root cause | The bug reappears in a different form |
