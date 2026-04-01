# React Specialist Core Expertise

## Functional Components & Hooks
- Write all components as functional components with explicit TypeScript props interfaces
- Master all built-in hooks: `useState`, `useEffect`, `useRef`, `useMemo`, `useCallback`, `useContext`, `useReducer`, `useId`, `useTransition`, `useDeferredValue`
- Build custom hooks to encapsulate reusable stateful logic
- Always specify correct `useEffect` dependency arrays -- never omit deps or use exhaustive-deps suppressions without justification
- Always return cleanup functions from `useEffect` when subscribing to events, timers, or external resources

## State Management
- Use `useState` for simple local state
- Use `useReducer` for complex state transitions with multiple sub-values
- Use React Context + `useContext` for shared state that doesn't require external libraries
- Integrate with external stores (Zustand, Redux Toolkit, Jotai) following the store's idiomatic patterns
- Derive state inline from existing state rather than duplicating it into additional `useState` calls

## TanStack Libraries (Preferred)
- **TanStack Query (React Query)** -- use for all server state: data fetching, caching, background refetching, optimistic updates. Never manage server state in useState/useReducer.
  - Define query keys as constants or factories for consistency
  - Use `useQuery` for reads, `useMutation` for writes with `onSuccess` invalidation
  - Configure `staleTime` and `gcTime` intentionally -- don't rely on defaults blindly
  - Use `useSuspenseQuery` with Suspense boundaries where applicable
- **TanStack Table** -- use for any data table with sorting, filtering, pagination, or column resizing
- **TanStack Router** -- use if the project uses TanStack Router; type-safe routing with built-in data loading
- **TanStack Form** -- use for complex forms with validation
- Always check if a TanStack library covers the use case before building custom solutions

## shadcn/ui Components (Preferred)
- Use shadcn/ui as the default component library for all UI elements
- Before building any custom component, check if shadcn/ui provides it: Button, Card, Dialog, DropdownMenu, Table, Tabs, Input, Select, Sheet, Toast, etc.
- Follow shadcn's composition patterns -- components are composable primitives, not monolithic
- Use shadcn's theming via CSS variables -- extend the theme rather than overriding with custom Tailwind
- When shadcn doesn't have a component, build custom components that match shadcn's design language

## React 18+ Concurrent Features
- Use `<Suspense>` boundaries for async data fetching and lazy-loaded components
- Use `useTransition` to mark non-urgent state updates and keep UI responsive
- Use `useDeferredValue` to defer re-renders of expensive child components
- Use `React.lazy` with `<Suspense>` for code splitting at the route and component level
- Understand Server Components vs Client Components boundary -- know when to add `'use client'`

## Performance
- Apply `React.memo` only when profiling confirms unnecessary re-renders -- never prematurely
- Use `useCallback` to stabilize function references passed as props to memoized children
- Use `useMemo` for expensive computations -- not for simple value creation
- Implement code splitting with `React.lazy` at meaningful boundaries (routes, heavy modals)
- Avoid anonymous functions and object literals directly in JSX props for stable-reference-sensitive children

## Testing (React Testing Library)
- Test behavior from the user's perspective, not implementation details
- Query elements by accessible role, label, placeholder, or text -- avoid querying by class or test-id unless necessary
- Use `userEvent` over `fireEvent` for realistic interaction simulation
- Assert on visible output and DOM changes, not internal state
- Mock only at the boundary (API calls, external modules) -- let React render fully

## Accessibility
- Use semantic HTML elements (`<button>`, `<nav>`, `<main>`, `<section>`, `<header>`, `<footer>`, `<article>`) instead of generic `<div>` wrappers
- Add ARIA attributes only when semantic HTML is insufficient
- Ensure all interactive elements are keyboard-navigable and have visible focus indicators
- Provide `alt` text for images; use `alt=""` for decorative images
- Manage focus explicitly for modals, dialogs, and dynamic content insertions

## TypeScript
- Define explicit `interface` or `type` for every component's props
- Use discriminated unions for components with mutually exclusive prop sets
- Type event handlers precisely (`React.ChangeEvent<HTMLInputElement>`)
- Avoid `any` -- use `unknown` with type guards when the shape is truly unknown
- Export prop types alongside components to enable extension by consumers
