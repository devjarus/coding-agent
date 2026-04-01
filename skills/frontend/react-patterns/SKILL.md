---
name: react-patterns
description: Modern React patterns and conventions for React 18+. Priority-ranked rules for performance, correctness, and maintainability. Use when building React components, reviewing React code, or diagnosing React performance issues.
---

# React Best Practices

## When to Apply

- Building or reviewing React components or hooks
- Diagnosing slow renders, large bundles, or waterfall fetches
- Refactoring state management or side-effect logic

## Rules

### CRITICAL -- Waterfalls & Bundle Size (rules/waterfalls-and-bundle.md)

- **RBP-01 to RBP-05:** Parallel fetches, Suspense boundaries, co-located data, prefetch on hover
- **RBP-06 to RBP-11:** Named imports, dynamic imports, no barrel re-exports, bundle analyzer, `next/image`

### HIGH -- Server & Client Patterns (rules/server-and-client.md)

- **RBP-12 to RBP-16:** Server Components default, deep `'use client'` boundaries, Suspense streaming, cache headers, no secrets in client
- **RBP-17 to RBP-22:** One concern per effect, cleanup functions, complete deps, state management tiers, custom hooks, no conditional hooks

### MEDIUM -- Re-render & Design (rules/rerender-and-design.md)

- **RBP-23 to RBP-28:** Memo/useCallback/useMemo only when profiled, derive values, stable keys, profile before/after
- **RBP-29 to RBP-34:** Single responsibility, composition over config, TypeScript props, no prop-drilling, 200-line limit, onX/handleX naming

### LOW -- Testing (rules/testing.md)

- **RBP-35 to RBP-40:** RTL query priority, userEvent, Arrange-Act-Assert, assert visible output, MSW mocking, accessibility assertions

## Anti-Patterns

- Sequential awaits for independent data (waterfall)
- `'use client'` at the top of large component trees
- Barrel re-exports defeating tree-shaking
- `useMemo`/`useCallback` without profiling evidence
- Array index as list key for reorderable lists
- Asserting on internal state instead of user-visible output
