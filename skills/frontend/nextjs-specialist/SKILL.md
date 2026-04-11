---
name: nextjs-specialist
description: Next.js specialist knowledge — App Router architecture, Server Components, Server Actions, rendering strategies, caching, routing, API route handlers, and optimization patterns for Next.js 14+.
---

# Next.js Specialist

Deep expertise in Next.js 14+ App Router, Server Components, Server Actions, rendering strategies, and full-stack data patterns.

## When to Apply

- Building Next.js applications with the App Router
- Implementing Server Components and Server Actions
- Configuring rendering strategies (SSR, SSG, ISR, streaming)
- Setting up API route handlers
- Optimizing Next.js performance and SEO
- Managing caching and revalidation strategies
- Configuring middleware for auth, redirects, or header rewriting

## Core Expertise (rules/core-expertise.md)

- App Router file conventions: `page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx`, `route.ts`
- Server Components by default; `'use client'` only for browser APIs/state/effects
- Server Actions for mutations with `revalidatePath()`/`revalidateTag()`
- Rendering strategies: SSR, SSG, ISR, Streaming, PPR
- Caching: fetch options, `unstable_cache`, React `cache()`, tag-based invalidation
- Routing: `<Link>`, `useRouter()`, middleware, dynamic segments
- API route handlers: named exports per HTTP method
- Optimization: `next/image`, `next/font`, `<Script>`, metadata export
- Environment variables: `NEXT_PUBLIC_` for client, plain for server-only

## Patterns

- Fetch data as close to where it's used as possible; avoid prop-drilling
- Use `Promise.all()` for independent concurrent fetches in Server Components
- Add `error.tsx` at every route segment with independent failure modes
- Add `loading.tsx` at segments whose data takes perceptibly long
- Every `page.tsx` must export `metadata` or `generateMetadata`

## Next.js 15+ Gotchas

These bite real projects and produce **runtime errors, not typecheck errors** — easy to miss in smoke tests. Always navigate actual routes in the evaluator's runtime verification, not just curl `/`.

### Async params and searchParams

In Next.js 15+, dynamic segment `params` and `searchParams` are `Promise`s. **Must `await` them** before use in both `page.tsx` and `route.ts`:

```ts
// app/notes/[...slug]/page.tsx
export default async function NotePage({ params }: { params: Promise<{ slug: string[] }> }) {
  const { slug } = await params;                      // REQUIRED: await first
  const path = slug.join("/");
  // ...
}

// app/api/notes/[...slug]/route.ts
export async function GET(
  req: Request,
  { params }: { params: Promise<{ slug: string[] }> }
) {
  const { slug } = await params;                      // REQUIRED: await first
  // ...
}
```

Forgetting the `await` produces cryptic runtime errors like `Cannot read properties of undefined (reading 'join')`, NOT typecheck errors.

### `dynamic(() => ..., { ssr: false })` cannot be called from server components

In Next.js 15, `next/dynamic` with `ssr: false` is forbidden inside server components. The working pattern: a tiny client-component wrapper whose only job is to host the `dynamic()` call:

```tsx
// app/components/command-palette-loader.tsx
'use client';
import dynamic from 'next/dynamic';

const CommandPalette = dynamic(() => import('./command-palette'), { ssr: false });

export default function CommandPaletteLoader() {
  return <CommandPalette />;
}

// app/layout.tsx (server component)
import CommandPaletteLoader from './components/command-palette-loader';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        <CommandPaletteLoader />
        {children}
      </body>
    </html>
  );
}
```

The rest of the shell layout stays a server component. Only the loader is client.

### next-themes FOUC prevention

`next-themes` injects an IIFE into `<body>` that reads `localStorage` (or `prefers-color-scheme`) and calls `document.documentElement.classList.add('dark')` **before React hydrates**. Without this script, there's a flash of light mode on first paint even when the user prefers dark.

Three things are required for this to work:

1. `<html suppressHydrationWarning>` on the root — the IIFE mutates `classList` before React runs, which would normally trigger a hydration warning
2. `<ThemeProvider>` from `next-themes` wrapping the app
3. The IIFE script must actually be present in the served HTML (verify with `curl -s http://localhost:<port>/ | grep -c 'classList.add'`)

Verify dark-mode-won't-flash by inspecting the served HTML, not just the React tree. Missing IIFE = FOUC on every first paint.

### Dev server port fallback

`next dev` silently falls back to port 3001 (or the next available) if 3000 is taken, and only logs it once in the initial output. **Never hardcode 3000** in evaluator scripts — parse the actual port from stderr. Curling the wrong port will hit whatever other process owns 3000, which is almost always misleading.

### `pnpm dev` wipes `.next/` on restart

If you verify a specific compiled chunk (e.g., a code-split file `807.<hash>.js`) and then start `pnpm dev`, the chunk filename changes and the file you verified no longer exists. **Verify build artifacts BEFORE starting the dev server, not after.** Applies equally to any framework with a dev pipeline (Vite, Astro, webpack-dev-server).

## Rules

1. **Server-first** -- default to Server Components; `'use client'` only when needed
2. **Follow Next.js file conventions** -- exact naming required
3. **Use Context7 MCP for documentation lookup**
4. **NEXT_PUBLIC_ prefix rule** -- only expose safe values to the client
5. **next/image for all images** -- never use raw `<img>` tags
6. **Metadata on every page** -- export metadata or generateMetadata
7. **No direct DB calls from Client Components**

## Skills

- **react-patterns** -- especially RBP-12 (Server Components by default)
- **performance** -- Core Web Vitals targets
- **tdd** -- failing tests before implementation
- **config-management** -- server/client config separation (CFG-06)
- **ui-design** -- visual design principles
- **shadcn** -- default component library
