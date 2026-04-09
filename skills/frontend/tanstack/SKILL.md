---
name: tanstack
description: TanStack ecosystem — Query v5 for server state, Router v1 for type-safe routing, Table v8 for headless data grids, Form v1 for form state. Covers data fetching, caching, mutations, optimistic updates, URL state, and state management decisions.
---

# TanStack

The modern React data layer. Query handles server state (~80% of app data), Router handles navigation + URL state, Table handles data grids, Form handles form state.

## When to Apply

- Fetching data from APIs (use Query, not useState+useEffect)
- Managing URL search params, filters, pagination (use Router)
- Building tables with sorting/filtering/pagination (use Table)
- Complex forms with validation (use Form)
- Deciding what state tool to use (see State Decision Framework)

## State Decision Framework

Pick the right tool for the right state:

```
Server data (API responses)     → TanStack Query
URL state (search, filters)     → TanStack Router validateSearch / nuqs
Shared UI state (sidebar, theme) → Zustand (or Context if simple)
Local component state            → useState / useReducer
Form state                       → TanStack Form (or just useState for simple forms)
```

**The rule:** If data comes from a server, use Query. If it's in the URL, use Router. If it's local UI, use React state. Only add Zustand when Context causes re-render problems.

## TanStack Query v5 (rules/query.md)

Server state: fetching, caching, background refetching, mutations.

### Core Pattern

```typescript
// Define query options (reusable across components)
const postsQueryOptions = queryOptions({
  queryKey: ['posts', { status }],
  queryFn: () => fetchPosts(status),
  staleTime: 5 * 60 * 1000, // 5 min
})

// In component
const { data, isPending, error } = useQuery(postsQueryOptions)

// Or with Suspense
const { data } = useSuspenseQuery(postsQueryOptions)
```

### Mutations

```typescript
const mutation = useMutation({
  mutationFn: createPost,
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['posts'] })
  },
})

// Optimistic update
const mutation = useMutation({
  mutationFn: updatePost,
  onMutate: async (newPost) => {
    await queryClient.cancelQueries({ queryKey: ['posts'] })
    const previous = queryClient.getQueryData(['posts'])
    queryClient.setQueryData(['posts'], (old) => [...old, newPost])
    return { previous }
  },
  onError: (err, newPost, context) => {
    queryClient.setQueryData(['posts'], context.previous) // rollback
  },
  onSettled: () => {
    queryClient.invalidateQueries({ queryKey: ['posts'] })
  },
})
```

### Critical Rules (v5)

- **No `onSuccess`/`onError` callbacks on `useQuery`** — removed in v5. Use `useEffect` or handle in the component.
- **`gcTime` not `cacheTime`** — renamed in v5.
- **`isPending` not `isLoading`** — renamed in v5. `isLoading` = `isPending && isFetching` (first load only).
- **`placeholderData` not `keepPreviousData`** — renamed. Use `placeholderData: keepPreviousData` (import the function).
- **Don't mix `useSuspenseQuery` with `enabled`** — not supported. Use `useQuery` with `enabled` or `useSuspenseQuery` without.
- **Throw errors in queryFn** — `fetch` doesn't throw on 4xx/5xx. Check `response.ok`.
- **Query keys are arrays** — `['posts']` not `'posts'`. Include dependencies: `['posts', { status, page }]`.
- **Don't use query data as local state** — Query IS your state. Don't copy `data` into `useState`.

## TanStack Router v1 (rules/router.md)

Type-safe routing with data loading and URL state management.

### File-Based Routes

```typescript
// routes/posts.tsx
export const Route = createFileRoute('/posts')({
  validateSearch: z.object({
    page: z.number().default(1),
    search: z.string().optional(),
  }),
  loaderDeps: ({ search }) => ({ page: search.page }),
  loader: ({ context, deps }) =>
    context.queryClient.ensureQueryData(postsQueryOptions(deps.page)),
  component: PostsPage,
})

function PostsPage() {
  const { page, search } = Route.useSearch()
  const { data } = useSuspenseQuery(postsQueryOptions(page))
  const navigate = Route.useNavigate()

  return (
    // Type-safe search param updates
    <button onClick={() => navigate({ search: { page: page + 1 } })}>
      Next
    </button>
  )
}
```

### Query + Router Integration

```typescript
// In loader: ensure data is cached (returns from cache if fresh)
loader: ({ context }) => context.queryClient.ensureQueryData(queryOptions),

// In component: subscribe to cache (gets updates, shows cached data instantly)
const { data } = useSuspenseQuery(queryOptions)
```

This eliminates loading spinners on navigation — loader prefetches, component reads cache.

### Critical Rules

- **Use `loaderDeps`** when loader depends on search params. Without it, loader won't re-run on param changes.
- **`ensureQueryData` not `fetchQuery`** in loaders. `ensureQueryData` returns cached data if fresh; `fetchQuery` always fetches.
- **Always `validateSearch`** — without it you lose type safety on URL params.

## TanStack Table v8 (rules/table.md)

Headless table logic — you provide all markup.

### Core Pattern

```typescript
// IMPORTANT: memoize columns to prevent infinite re-renders
const columns = useMemo<ColumnDef<Post>[]>(() => [
  { accessorKey: 'title', header: 'Title' },
  { accessorKey: 'author', header: 'Author' },
  { accessorKey: 'createdAt', header: 'Date',
    cell: ({ getValue }) => formatDate(getValue()) },
], [])

const table = useReactTable({
  data,
  columns,
  getCoreRowModel: getCoreRowModel(),
  getSortedRowModel: getSortedRowModel(),
  getFilteredRowModel: getFilteredRowModel(),
  getPaginationRowModel: getPaginationRowModel(),
})
```

### Critical Rules

- **Memoize columns** — defining columns inside render = infinite re-renders.
- **Import row models** — sorting won't work without `getSortedRowModel()`.
- **It's headless** — no default UI. You build the `<table>`, `<tr>`, `<td>` yourself.

## TanStack Form v1 (rules/form.md)

Headless form state with granular reactivity.

### Core Pattern

```typescript
const form = useForm({
  defaultValues: { title: '', content: '' },
  onSubmit: async ({ value }) => {
    await createPost(value)
  },
})

return (
  <form onSubmit={(e) => { e.preventDefault(); form.handleSubmit() }}>
    <form.Field name="title" validators={{
      onChange: z.string().min(1, 'Required'),
    }}>
      {(field) => (
        <>
          <input value={field.state.value} onChange={(e) => field.handleChange(e.target.value)} />
          {field.state.meta.errors.map(err => <span key={err}>{err}</span>)}
        </>
      )}
    </form.Field>
  </form>
)
```

## Common Integration Patterns

### Query + Table (server-side pagination)

```typescript
const { data } = useQuery({
  queryKey: ['posts', { page, sort, filter }],
  queryFn: () => fetchPosts({ page, sort, filter }),
})

const table = useReactTable({
  data: data?.rows ?? [],
  pageCount: data?.pageCount ?? -1,
  state: { pagination, sorting, columnFilters },
  onPaginationChange: setPagination,
  onSortingChange: setSorting,
  manualPagination: true,
  manualSorting: true,
})
```

### Form + Mutation (submit with cache invalidation)

```typescript
const mutation = useMutation({ mutationFn: createPost,
  onSuccess: () => queryClient.invalidateQueries({ queryKey: ['posts'] })
})

const form = useForm({
  onSubmit: ({ value }) => mutation.mutateAsync(value),
})
```

## Rules

1. **Query for server data, not useState.** If it comes from an API, use Query.
2. **URL state for filters/pagination.** Don't put page number in React state — put it in the URL.
3. **Don't copy query data into local state.** Query IS your state manager for server data.
4. **Memoize table columns.** Or they cause infinite re-renders.
5. **Use v5 API names.** `isPending` not `isLoading`, `gcTime` not `cacheTime`.
6. **Always throw on fetch errors.** `fetch` resolves on 4xx — check `response.ok`.
