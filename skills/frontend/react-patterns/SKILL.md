---
name: react-patterns
description: Modern React patterns and conventions for React 18+. Priority-ranked rules for performance, correctness, and maintainability. Use when building React components, reviewing React code, or diagnosing React performance issues.
---

# React Best Practices

## When to Apply

Apply these rules when:
- Building new React components or hooks
- Reviewing React code for correctness or performance
- Diagnosing slow renders, large bundles, or waterfall fetches
- Migrating a component from client to server rendering
- Refactoring state management or side-effect logic

Trigger keywords: `component`, `hook`, `useState`, `useEffect`, `fetch`, `Suspense`, `Server Component`, `bundle`, `re-render`.

---

## CRITICAL — Eliminating Waterfalls

Sequential data fetches are the most common React performance killer. Fix these first.

**RBP-01** — Fetch in parallel, not sequentially.

```tsx
// Bad — each await blocks the next
const user = await getUser(id);
const posts = await getPosts(user.id);

// Good — start both requests together
const [user, posts] = await Promise.all([getUser(id), getPosts(id)]);
```

**RBP-02** — Never chain `await` calls inside a single Server Component render when the second fetch does not depend on the first result.

**RBP-03** — Use `Suspense` boundaries to stream independent data slices to the client without blocking the shell.

```tsx
<Suspense fallback={<Skeleton />}>
  <UserProfile userId={id} />
</Suspense>
<Suspense fallback={<Skeleton />}>
  <RecentPosts userId={id} />
</Suspense>
```

**RBP-04** — Co-locate data fetching with the component that consumes it. Lift fetches only when two sibling components truly share the same data shape.

**RBP-05** — Prefetch data before navigation events (e.g., on hover) using `router.prefetch` or `<Link prefetch>` to eliminate the request waterfall on route change.

---

## CRITICAL — Bundle Size

Unused JavaScript is paid for by every user on every page load.

**RBP-06** — Import only what you use. Prefer named imports over default barrel imports.

```tsx
// Bad — pulls in entire library
import _ from 'lodash';

// Good — tree-shaken
import debounce from 'lodash/debounce';
```

**RBP-07** — Use `next/dynamic` (or `React.lazy` + `Suspense`) to code-split components that are not needed on initial render: modals, drawers, heavy charts, rich-text editors.

```tsx
const RichEditor = dynamic(() => import('@/components/RichEditor'), {
  loading: () => <EditorSkeleton />,
  ssr: false,
});
```

**RBP-08** — Do not re-export everything from barrel `index.ts` files inside `components/`. Barrel re-exports defeat tree-shaking; import directly from the source file.

**RBP-09** — Run a bundle analyzer (`@next/bundle-analyzer` or `rollup-plugin-visualizer`) before and after adding any dependency larger than 10 kB. Set a budget and fail CI when exceeded.

**RBP-10** — Audit third-party dependencies with `bundlephobia` or `pkg-size.dev`. Prefer smaller, modular alternatives (e.g., `date-fns` over `moment`, `zod` over `joi`).

**RBP-11** — Use `next/image` (or an equivalent optimized image component) for all `<img>` tags. Never ship full-resolution images to the browser without width/height constraints.

---

## HIGH — Server Performance

Push work to the server before it ever reaches the client.

**RBP-12** — Default to Server Components. Add `'use client'` only when you need browser APIs, event handlers, or React hooks.

**RBP-13** — Keep `'use client'` boundaries as deep (small) as possible. A single interactive button should not force its entire parent tree to become a Client Component.

```tsx
// Bad — entire Card is a client component just for one button
'use client';
export function Card({ data }: Props) { ... }

// Good — push the boundary to the interactive leaf
export function Card({ data }: Props) {
  return <div>...<LikeButton id={data.id} /></div>; // LikeButton is 'use client'
}
```

**RBP-14** — Stream long-running server responses. Place `<Suspense>` around any component that reads slow data so the page shell renders immediately.

**RBP-15** — Set explicit `Cache-Control` headers (or use Next.js `fetch` cache options) for server-fetched data. Stale-while-revalidate patterns eliminate redundant origin requests.

```tsx
const data = await fetch(url, { next: { revalidate: 60 } });
```

**RBP-16** — Never expose secrets, database credentials, or server-only modules inside a Client Component. Use `server-only` package to enforce the boundary at build time.

---

## HIGH — Client-Side Patterns

Client Components still have rules. Follow them to avoid subtle bugs and wasted renders.

**RBP-17** — One concern per `useEffect`. Split effects that manage different resources (subscriptions, timers, DOM mutations) into separate hooks or custom hooks.

**RBP-18** — Always return a cleanup function from `useEffect` when it creates subscriptions, event listeners, or timers.

```tsx
useEffect(() => {
  const handler = (e: MessageEvent) => handleMessage(e);
  window.addEventListener('message', handler);
  return () => window.removeEventListener('message', handler);
}, [handleMessage]);
```

**RBP-19** — Include all referenced values in the `useEffect` dependency array. Rely on the `exhaustive-deps` ESLint rule; never suppress it without a documented reason.

**RBP-20** — State management tier selection:

| Scope | Tool |
|---|---|
| Local UI state | `useState` |
| Complex / multi-step transitions | `useReducer` |
| Shared state for a subtree | `createContext` + `useContext` |
| Global / cross-cutting | Zustand, Jotai, or Redux Toolkit |

Avoid lifting state higher than necessary. Co-locate state with the components that consume it.

**RBP-21** — Extract reusable logic into custom hooks prefixed with `use`. Return a tuple `[value, setter]` for simple pairs; return a named object when there are three or more values.

**RBP-22** — Never call hooks conditionally or inside loops. If the hook must be conditional, gate the entire component with a conditional render instead.

---

## MEDIUM — Re-render Prevention

Optimize only after measuring. Premature memoization adds complexity and can hide real bugs.

**RBP-23** — Apply `React.memo` only to components you have profiled and confirmed re-render unnecessarily. Wrapping every component wastes memory and obscures data flow.

**RBP-24** — Use `useCallback` to stabilize function references passed as props to memoized children or used as `useEffect` dependencies — not as a blanket optimization.

**RBP-25** — Use `useMemo` for expensive calculations (> 1 ms) or to produce stable object/array references consumed by memoized children. Avoid `useMemo` for primitive values.

**RBP-26** — Derive values from state rather than syncing them in a `useEffect`. Derived values never get out of sync.

```tsx
// Bad — sync in effect
const [fullName, setFullName] = useState('');
useEffect(() => setFullName(`${first} ${last}`), [first, last]);

// Good — derive directly
const fullName = `${first} ${last}`;
```

**RBP-27** — Key strategy for lists: use stable, unique, domain IDs (e.g., `item.id`). Never use array index as a key for lists that can reorder or filter.

**RBP-28** — Use the React DevTools Profiler and `<Profiler>` API to measure before and after any memoization change. Document the measured gain in the PR description.

---

## MEDIUM — Component Design

Structure components for clarity, testability, and long-term maintainability.

**RBP-29** — Single responsibility: a component should do one thing. If a component needs a long comment to explain what it does, split it.

**RBP-30** — Prefer composition over configuration. Expose `children` and named slots (render props or compound components) rather than an ever-growing list of boolean props.

```tsx
// Bad — configuration explosion
<Modal title="..." footer="..." showClose={true} onClose={...} />

// Good — composable slots
<Modal>
  <Modal.Header>...</Modal.Header>
  <Modal.Body>...</Modal.Body>
  <Modal.Footer>...</Modal.Footer>
</Modal>
```

**RBP-31** — Define an explicit TypeScript props interface. Destructure props with defaults at the function signature level.

```tsx
interface CardProps {
  title: string;
  variant?: 'default' | 'outlined';
  children: React.ReactNode;
}

function Card({ title, variant = 'default', children }: CardProps) { ... }
```

**RBP-32** — Avoid prop-drilling beyond two levels. Introduce a context or a co-located state hook instead.

**RBP-33** — Keep component files under 200 lines. Extract sub-components, helpers, and hooks into sibling files when the file grows beyond that.

**RBP-34** — Name event handler props `onX` and the implementing functions `handleX` for consistency across the codebase.

---

## LOW — Testing

Tests validate behavior, not implementation. Write tests that break when the product breaks, not when you refactor.

**RBP-35** — Use React Testing Library (RTL). Query elements the way a user would perceive them.

Query priority: `getByRole` > `getByLabelText` > `getByText` > `getByPlaceholderText` > `getByTestId`.

**RBP-36** — Use `userEvent` from `@testing-library/user-event` rather than `fireEvent` for all interactions (typing, clicking, keyboard). `userEvent` dispatches the full browser event sequence.

**RBP-37** — Structure each test as Arrange → Act → Assert. Keep tests focused on a single behavior.

```tsx
it('submits the form with valid data', async () => {
  // Arrange
  render(<ContactForm onSubmit={mockSubmit} />);

  // Act
  await userEvent.type(screen.getByLabelText(/email/i), 'user@example.com');
  await userEvent.click(screen.getByRole('button', { name: /submit/i }));

  // Assert
  expect(mockSubmit).toHaveBeenCalledWith({ email: 'user@example.com' });
});
```

**RBP-38** — Assert what the user sees: visible text, accessible names, element presence. Do not assert on internal state, component refs, or private methods.

**RBP-39** — Mock at the network boundary (MSW), not at the module boundary. This keeps tests resilient to internal refactors.

**RBP-40** — Write at least one accessibility assertion per interactive component: check that focus management, ARIA roles, and keyboard navigation work as expected.

---

## Rule Index

| ID | Rule | Priority |
|---|---|---|
| RBP-01 | Fetch in parallel with Promise.all | CRITICAL |
| RBP-02 | No sequential awaits for independent data | CRITICAL |
| RBP-03 | Suspense boundaries for independent data slices | CRITICAL |
| RBP-04 | Co-locate data fetching with consumer | CRITICAL |
| RBP-05 | Prefetch before navigation | CRITICAL |
| RBP-06 | Named imports, no barrel re-exports | CRITICAL |
| RBP-07 | Dynamic imports for non-critical components | CRITICAL |
| RBP-08 | No barrel index.ts re-exports | CRITICAL |
| RBP-09 | Bundle analyzer in CI | CRITICAL |
| RBP-10 | Audit dependency size before adding | CRITICAL |
| RBP-11 | next/image for all images | CRITICAL |
| RBP-12 | Server Components by default | HIGH |
| RBP-13 | Minimal 'use client' boundary depth | HIGH |
| RBP-14 | Stream with Suspense for slow data | HIGH |
| RBP-15 | Explicit cache headers on server fetches | HIGH |
| RBP-16 | Never expose secrets in Client Components | HIGH |
| RBP-17 | One concern per useEffect | HIGH |
| RBP-18 | Cleanup function in every useEffect | HIGH |
| RBP-19 | Complete dependency arrays | HIGH |
| RBP-20 | State management tier selection | HIGH |
| RBP-21 | Custom hooks for reusable logic | HIGH |
| RBP-22 | No conditional hook calls | HIGH |
| RBP-23 | React.memo only when measured | MEDIUM |
| RBP-24 | useCallback for stable references | MEDIUM |
| RBP-25 | useMemo for expensive calculations | MEDIUM |
| RBP-26 | Derive values, don't sync in effects | MEDIUM |
| RBP-27 | Stable unique keys for lists | MEDIUM |
| RBP-28 | Profile before/after memoization | MEDIUM |
| RBP-29 | Single responsibility per component | MEDIUM |
| RBP-30 | Composition over configuration | MEDIUM |
| RBP-31 | Explicit TypeScript props interface | MEDIUM |
| RBP-32 | No prop-drilling beyond two levels | MEDIUM |
| RBP-33 | Keep component files under 200 lines | MEDIUM |
| RBP-34 | onX props / handleX implementations | MEDIUM |
| RBP-35 | RTL query priority | LOW |
| RBP-36 | userEvent over fireEvent | LOW |
| RBP-37 | Arrange-Act-Assert structure | LOW |
| RBP-38 | Assert what the user sees | LOW |
| RBP-39 | Mock at network boundary (MSW) | LOW |
| RBP-40 | Accessibility assertions per component | LOW |
