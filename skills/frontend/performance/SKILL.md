---
name: performance
description: Frontend performance optimization patterns for Core Web Vitals. Use when building UI.
---

# Performance

## Core Web Vitals Targets

| Metric | Target | Description |
|---|---|---|
| LCP (Largest Contentful Paint) | < 2.5s | Time until the largest visible content is rendered |
| INP (Interaction to Next Paint) | < 200ms | Latency from user interaction to visual response |
| CLS (Cumulative Layout Shift) | < 0.1 | Visual stability — elements should not shift unexpectedly |

## Loading

- Code-split routes and heavy components with `React.lazy` + `Suspense`.
- Serve images in modern formats (WebP, AVIF) and always specify `width` and `height` to prevent layout shift.
- Minimize render-blocking resources: defer non-critical scripts, inline critical CSS.
- Preload critical assets (hero images, key fonts) with `<link rel="preload">`.

## Rendering

- Wrap expensive pure components in `React.memo` only when props are stable (primitives or memoized references).
- Use `useMemo` to memoize expensive computed values and `useCallback` to stabilize callback references passed to memoized children.
- Virtualize long lists with a library like `react-window` or `react-virtual` — never render thousands of DOM nodes.
- Debounce high-frequency events (scroll, resize, input) to limit re-render rate.

## Bundle Size

- Use named imports to enable tree-shaking: `import { debounce } from 'lodash-es'`, not `import _ from 'lodash'`.
- Analyze bundle composition regularly with tools like `webpack-bundle-analyzer` or `vite-bundle-visualizer`.
- Load heavy third-party libraries (charts, editors, PDF renderers) with dynamic `import()` so they are not in the initial bundle.
- Avoid importing entire utility libraries when native browser APIs or a small helper will do.

## Perceived Performance

- Use skeleton screens instead of spinners for content that has a known layout — reduces perceived wait time.
- Apply optimistic UI updates for low-risk mutations (likes, toggles) to make interactions feel instant.
- Prefetch the resources for likely next navigations using `<link rel="prefetch">` or router-level prefetching.
- Load content progressively: show a low-quality placeholder first, then swap in the full asset once loaded.
