# Next.js Specialist Core Expertise

## App Router Architecture
- Structure apps under the `app/` directory using file-system routing conventions
- Use `layout.tsx` for persistent UI shared across routes (navigation, sidebars, providers)
- Use `page.tsx` as the unique UI for each route segment
- Use `loading.tsx` to automatically wrap page content in a `<Suspense>` boundary with a fallback
- Use `error.tsx` (a Client Component) to handle runtime errors within a route segment using error boundaries
- Use `not-found.tsx` to render custom 404 UIs -- trigger with `notFound()` from `next/navigation`
- Use `template.tsx` when you need a fresh instance (re-mounted) on every navigation
- Group routes with `(groupName)` directories that don't affect the URL path
- Use `[param]` for dynamic segments, `[...slug]` for catch-all, and `[[...slug]]` for optional catch-all

## Server Components vs Client Components
- **Default to Server Components** -- they run on the server, can fetch data directly, and have zero client-side JS bundle cost
- Add `'use client'` only when the component needs browser APIs, event listeners, state, or effects
- Push `'use client'` boundaries as deep (leaf-ward) as possible to minimize client bundle size
- Never import a Server Component into a Client Component -- pass Server Components as `children` props instead
- Server Components can be `async` -- `await` data fetches directly in the component body

## Server Actions
- Define Server Actions with `'use server'` directive at the top of a server-side function or file
- Use for mutations: form submissions, database writes, cache invalidation
- Invoke from Client Components via `action` prop on `<form>` or direct function call
- Use `revalidatePath()` or `revalidateTag()` to invalidate cached data after mutations
- Handle validation errors and return structured error responses
- Use `useFormState` and `useFormStatus` (from `react-dom`) to manage Server Action state

## Rendering Strategies
- **SSR:** dynamic rendering per request -- `export const dynamic = 'force-dynamic'`
- **SSG:** pages with no dynamic data render at build time by default
- **ISR:** `export const revalidate = <seconds>` in a page or layout
- **Streaming:** `<Suspense>` boundaries in Server Components enable streaming
- **PPR:** in Next.js 15+, static shell + streaming dynamic holes -- opt in per route

## Caching Strategies
- `fetch()` in Server Components: `cache: 'force-cache'` (default), `cache: 'no-store'`, or `next: { revalidate: seconds }` / `next: { tags: ['tag'] }`
- Use `unstable_cache` for caching non-fetch async operations (DB queries, SDK calls)
- Tag cache entries with `next: { tags: ['entity-type'] }` for precise `revalidateTag()` invalidation
- Use React's `cache()` to deduplicate identical requests within a single render pass

## Routing & Navigation
- Use `<Link href="...">` from `next/link` for client-side navigation
- Use `useRouter()` from `next/navigation` for programmatic navigation
- Use `usePathname()` and `useSearchParams()` for reading current URL
- Use `redirect()` from `next/navigation` for server-side redirects
- Define route-level middleware in `middleware.ts` at the project root

## API Route Handlers
- Create `route.ts` files in `app/` for API endpoints
- Export named functions (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`) matching HTTP methods
- Use `NextRequest` and `NextResponse` from `next/server`
- Return `NextResponse.json(data, { status })` for JSON responses
- Protect routes via middleware or inline session checks

## Optimization
- Use `next/image` for all images -- lazy loading, responsive sizing, format conversion
- Use `next/font` to self-host fonts -- eliminates external requests and layout shift
- Use `<Script>` component for third-party scripts with strategy control
- Export `metadata` objects or `generateMetadata` for SEO

## Environment Variables
- Server-only secrets: `MY_SECRET` -- accessible in Server Components, Actions, API routes
- Client-accessible values: `NEXT_PUBLIC_MY_VALUE` -- bundled into client JS; never put secrets here
- Validate env vars at startup with a schema library (e.g., `zod`)

## File & Directory Conventions

```
app/
  layout.tsx          # Root layout
  page.tsx            # Home route
  loading.tsx         # Suspense fallback
  error.tsx           # Error boundary ('use client')
  not-found.tsx       # 404 UI
  (auth)/             # Route group
    login/page.tsx
  dashboard/
    layout.tsx        # Nested layout
    page.tsx
    [id]/
      page.tsx        # Dynamic route
  api/
    users/
      route.ts        # API route handler
middleware.ts         # Edge middleware
```
