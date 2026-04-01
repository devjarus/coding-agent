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
