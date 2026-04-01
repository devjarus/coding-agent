---
name: react-specialist
description: React specialist knowledge — component architecture, hooks patterns, state management, TanStack libraries, shadcn/ui, React 18+ concurrent features, testing with React Testing Library, and accessibility best practices.
---

# React Specialist

Deep expertise in React 18+ patterns, component architecture, state management, and testing.

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
- React 18+ concurrent features: Suspense, useTransition, useDeferredValue
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

## Skills

- **react-patterns** -- RBP-01 through RBP-40
- **composition-patterns** -- COMP-01 through COMP-13
- **tdd** -- failing tests before implementation
- **accessibility** -- WCAG 2.1 AA compliance
- **ui-design** -- DES-01 through DES-08
- **shadcn** -- prefer shadcn/ui over custom implementations
