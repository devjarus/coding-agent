# Eliminating Waterfalls & Bundle Size

## CRITICAL -- Eliminating Waterfalls

Sequential data fetches are the most common React performance killer. Fix these first.

**RBP-01** -- Fetch in parallel, not sequentially.

```tsx
// Bad -- each await blocks the next
const user = await getUser(id);
const posts = await getPosts(user.id);

// Good -- start both requests together
const [user, posts] = await Promise.all([getUser(id), getPosts(id)]);
```

**RBP-02** -- Never chain `await` calls inside a single Server Component render when the second fetch does not depend on the first result.

**RBP-03** -- Use `Suspense` boundaries to stream independent data slices to the client without blocking the shell.

```tsx
<Suspense fallback={<Skeleton />}>
  <UserProfile userId={id} />
</Suspense>
<Suspense fallback={<Skeleton />}>
  <RecentPosts userId={id} />
</Suspense>
```

**RBP-04** -- Co-locate data fetching with the component that consumes it. Lift fetches only when two sibling components truly share the same data shape.

**RBP-05** -- Prefetch data before navigation events (e.g., on hover) using `router.prefetch` or `<Link prefetch>` to eliminate the request waterfall on route change.

## CRITICAL -- Bundle Size

Unused JavaScript is paid for by every user on every page load.

**RBP-06** -- Import only what you use. Prefer named imports over default barrel imports.

```tsx
// Bad -- pulls in entire library
import _ from 'lodash';

// Good -- tree-shaken
import debounce from 'lodash/debounce';
```

**RBP-07** -- Use `next/dynamic` (or `React.lazy` + `Suspense`) to code-split components that are not needed on initial render: modals, drawers, heavy charts, rich-text editors.

```tsx
const RichEditor = dynamic(() => import('@/components/RichEditor'), {
  loading: () => <EditorSkeleton />,
  ssr: false,
});
```

**RBP-08** -- Do not re-export everything from barrel `index.ts` files inside `components/`. Barrel re-exports defeat tree-shaking; import directly from the source file.

**RBP-09** -- Run a bundle analyzer (`@next/bundle-analyzer` or `rollup-plugin-visualizer`) before and after adding any dependency larger than 10 kB. Set a budget and fail CI when exceeded.

**RBP-10** -- Audit third-party dependencies with `bundlephobia` or `pkg-size.dev`. Prefer smaller, modular alternatives (e.g., `date-fns` over `moment`, `zod` over `joi`).

**RBP-11** -- Use `next/image` (or an equivalent optimized image component) for all `<img>` tags. Never ship full-resolution images to the browser without width/height constraints.
