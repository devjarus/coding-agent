# Server & Client-Side Patterns

## HIGH -- Server Performance

Push work to the server before it ever reaches the client.

**RBP-12** -- Default to Server Components. Add `'use client'` only when you need browser APIs, event handlers, or React hooks.

**RBP-13** -- Keep `'use client'` boundaries as deep (small) as possible. A single interactive button should not force its entire parent tree to become a Client Component.

```tsx
// Bad -- entire Card is a client component just for one button
'use client';
export function Card({ data }: Props) { ... }

// Good -- push the boundary to the interactive leaf
export function Card({ data }: Props) {
  return <div>...<LikeButton id={data.id} /></div>; // LikeButton is 'use client'
}
```

**RBP-14** -- Stream long-running server responses. Place `<Suspense>` around any component that reads slow data so the page shell renders immediately.

**RBP-15** -- Set explicit `Cache-Control` headers (or use Next.js `fetch` cache options) for server-fetched data. Stale-while-revalidate patterns eliminate redundant origin requests.

```tsx
const data = await fetch(url, { next: { revalidate: 60 } });
```

**RBP-16** -- Never expose secrets, database credentials, or server-only modules inside a Client Component. Use `server-only` package to enforce the boundary at build time.

## HIGH -- Client-Side Patterns

Client Components still have rules. Follow them to avoid subtle bugs and wasted renders.

**RBP-17** -- One concern per `useEffect`. Split effects that manage different resources (subscriptions, timers, DOM mutations) into separate hooks or custom hooks.

**RBP-18** -- Always return a cleanup function from `useEffect` when it creates subscriptions, event listeners, or timers.

```tsx
useEffect(() => {
  const handler = (e: MessageEvent) => handleMessage(e);
  window.addEventListener('message', handler);
  return () => window.removeEventListener('message', handler);
}, [handleMessage]);
```

**RBP-19** -- Include all referenced values in the `useEffect` dependency array. Rely on the `exhaustive-deps` ESLint rule; never suppress it without a documented reason.

**RBP-20** -- State management tier selection:

| Scope | Tool |
|---|---|
| Local UI state | `useState` |
| Complex / multi-step transitions | `useReducer` |
| Shared state for a subtree | `createContext` + `useContext` |
| Global / cross-cutting | Zustand, Jotai, or Redux Toolkit |

Avoid lifting state higher than necessary. Co-locate state with the components that consume it.

**RBP-21** -- Extract reusable logic into custom hooks prefixed with `use`. Return a tuple `[value, setter]` for simple pairs; return a named object when there are three or more values.

**RBP-22** -- Never call hooks conditionally or inside loops. If the hook must be conditional, gate the entire component with a conditional render instead.
