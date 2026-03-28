---
name: dependency-evaluation
description: Framework for evaluating and selecting npm packages, libraries, and tools. Use when choosing between alternatives (ORMs, auth libs, UI frameworks) or adding new dependencies.
---

Solves: "which auth library?", "prisma vs drizzle?", "should we add this dep?"

## When to Apply
- Choosing between library alternatives
- Adding a new dependency to the project
- Researcher agent evaluating options
- Planner selecting tech stack components

## Evaluation Criteria (priority ordered)

### CRITICAL
- DEP-01: Does it solve the actual problem? Don't add a library for something the stdlib/framework handles
- DEP-02: Is it actively maintained? Check: last commit < 6 months, issues being responded to, not deprecated
- DEP-03: Security — run `npm audit` / `pip audit`. Check for known CVEs. Check Snyk/Socket.dev

### HIGH
- DEP-04: Bundle size impact — check bundlephobia.com. Is tree-shaking supported?
- DEP-05: TypeScript support — first-class types (not @types/ afterthought)?
- DEP-06: Community adoption — npm weekly downloads, GitHub stars (as a signal, not a metric), used by notable projects?
- DEP-07: API stability — does it follow semver? Frequent breaking changes?

### MEDIUM
- DEP-08: Documentation quality — are docs complete, current, with examples?
- DEP-09: Escape hatch — can you replace it later without rewriting everything? Avoid deep lock-in
- DEP-10: License — MIT/Apache/BSD are safe. Check for GPL/AGPL if distributing

## Decision Template

Show a structured comparison format agents should use:

```
## Evaluation: [Category] — [Option A] vs [Option B] vs [Option C]

| Criteria | Option A | Option B | Option C |
|----------|----------|----------|----------|
| Solves problem? | ... | ... | ... |
| Maintained? | ... | ... | ... |
| Security | ... | ... | ... |
| Bundle size | ... | ... | ... |
| TypeScript | ... | ... | ... |
| Community | ... | ... | ... |
| API stability | ... | ... | ... |
| Docs quality | ... | ... | ... |
| Escape hatch | ... | ... | ... |
| License | ... | ... | ... |

Recommendation: [Option] because [reason]
Risk: [what could go wrong]
```

## Rules
- Prefer fewer dependencies — every dep is a maintenance and security liability
- Prefer framework built-ins over third-party (Next.js Image over sharp, etc.)
- Never add a dependency for something achievable in < 20 lines of code
- Check if the project already has a similar dep (don't add axios if fetch is already used)
