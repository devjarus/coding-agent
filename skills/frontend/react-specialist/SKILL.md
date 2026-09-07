---
name: react-specialist
description: React 19-first specialist guidance with React 18 compatibility, covering component architecture, Actions, hooks, state, TanStack, testing, performance, and accessibility.
---

# React Specialist

React 19-first guidance for component architecture, state management, and
testing. Inspect the project's installed major before applying version-specific
APIs; preserve React 18 compatibility when the project has not upgraded.

## When to Apply

- Building React components, pages, or features
- Implementing state management with hooks or external stores
- Working with TanStack Query, Table, Router, or Form
- Integrating shadcn/ui components
- Writing React component tests with React Testing Library
- Optimizing React rendering performance
- Ensuring accessibility compliance in React UIs

## Core Expertise (rules/core-expertise.md)

- Functional components with explicit TypeScript props interfaces
- All built-in hooks plus custom hooks for reusable logic
- TanStack Query for server state (never useState for fetched data)
- shadcn/ui as default component library; check before building custom
- React 19: Actions, `useActionState`, `useOptimistic`, `use()`, and ref as a prop
- React 18-compatible concurrency: Suspense, useTransition, useDeferredValue
- Performance: memo/useCallback/useMemo only after profiling
- RTL testing: query by role, userEvent, assert visible output
- Semantic HTML + ARIA; keyboard navigation required

## Coding Patterns (rules/coding-patterns.md)

- Component structure: hooks -> derived state -> handlers -> early returns -> JSX
- Naming: `handleX` for handlers, `onX` for callback props, `isX`/`hasX` for booleans
- 150-line component limit; extract sub-components and hooks
- Loading + error states required; use Suspense and error boundaries
- Stable unique keys from data IDs (never array index for dynamic lists)

## Rules

1. **Follow existing patterns** -- read the codebase before writing new code
2. **Test behavior, not implementation** -- tests survive refactors
3. **No premature optimization** -- add memo/useCallback/useMemo only after profiling
4. **Accessibility is required** -- keyboard-accessible with visible focus and accessible names
5. **No `any` in TypeScript** -- type props, state, and return values explicitly
6. **Cleanup effects** -- every subscribing `useEffect` must return a cleanup function

## React 19 compatibility boundary

- Function components can receive `ref` as a normal prop in React 19. Keep
  `forwardRef` when publishing for React 18 or when the repository still runs 18.
- `use()` may read a Promise or context during render and may be called in a
  conditional, but it is not a general replacement for event-driven fetching.
- Prefer Actions with `useActionState`, `useOptimistic`, and `useFormStatus` for
  mutation UX when the surrounding framework supports them. Preserve an
  established query/mutation abstraction instead of mixing two ownership models.
- Treat removed legacy APIs (`propTypes` enforcement for functions,
  `defaultProps` on functions, legacy context, string refs, `createFactory`) as
  migration findings rather than patterns for new work.

## Version-sensitive guidance

Verified 2026-09-06 against the official React 19 documentation and changelog.
Re-check by 2026-12-05 or before recommending a newer major.

- https://react.dev/reference/react
- https://github.com/react/react/blob/main/CHANGELOG.md

## Skills

- **react-patterns** -- RBP-01 through RBP-40
- **composition-patterns** -- COMP-01 through COMP-13
- **tdd** -- failing tests before implementation
- **accessibility** -- WCAG 2.1 AA compliance
- **ui-design** -- DES-01 through DES-08
- **shadcn** -- prefer shadcn/ui over custom implementations
