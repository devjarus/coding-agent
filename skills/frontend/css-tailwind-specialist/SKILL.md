---
name: css-tailwind-specialist
description: CSS and Tailwind specialist knowledge — utility-first styling, responsive design systems, modern layout techniques, animations, dark mode, design tokens, and accessibility-compliant theming.
---

# CSS / Tailwind Specialist

Utility-first styling, responsive design systems, modern layout, and accessibility-compliant theming.

## When to Apply

- Styling components with Tailwind CSS utilities
- Building responsive layouts with Flexbox and Grid
- Configuring design tokens and CSS custom properties
- Implementing dark mode theming
- Adding animations and transitions with reduced-motion support
- Extending `tailwind.config` with project-specific tokens
- Ensuring color contrast and focus indicator accessibility

## Core Expertise (rules/core-expertise.md)

- Tailwind utilities over custom CSS; `@apply` only for highly repeated patterns
- JIT requires complete class strings -- use `cn()`/`twMerge()` for conditionals
- Flexbox for 1D, Grid for 2D, container queries for parent-adaptive components
- Design tokens as CSS custom properties mapped into `tailwind.config`
- Mobile-first responsive: base -> `sm:` -> `md:` -> `lg:` -> `xl:`
- Dark mode via `dark:` variant; derive values from tokens
- Animations with `motion-safe:` / `motion-reduce:` variants always
- WCAG 2.1 AA contrast: 4.5:1 normal text, 3:1 large text
- `focus-visible:` for keyboard-only focus rings

## Rules

1. **Follow the design system** -- no colors, spacing, or typography outside the theme config (Tailwind v3 `tailwind.config.js` or Tailwind v4 `@theme` block in CSS)
2. **Responsive is required** -- validate at mobile, tablet, and desktop widths
3. **No inline styles** -- all styles through Tailwind utilities or CSS custom properties
4. **Contrast meets WCAG AA** -- verify every text-on-background pairing
5. **`@apply` only for highly repeated patterns**
6. **No dynamic class name construction** -- use `cn()` with full class names
7. **`focus-visible:` not `focus:`** -- mouse users should not see focus indicators
8. **`prefers-reduced-motion` always** -- every animation needs a safe fallback

## Tailwind v4 gotchas

Tailwind v4 removed the config file entirely — there is NO `tailwind.config.js`, NO `content` array, NO `theme` export. Check which version the project is on before writing any config.

**Detection:** if `package.json` has `"tailwindcss": "^4"` or higher, you're on v4.

**Setup (v4):** just `@import "tailwindcss";` at the top of your main CSS file:

```css
/* app/globals.css */
@import "tailwindcss";

@theme {
  --color-brand: oklch(0.72 0.19 147);
  --font-display: "Inter Variable", system-ui, sans-serif;
}
```

The `@theme` block IS the config. No JavaScript file. Trying to create `tailwind.config.js` on a v4 project wastes time and produces a file Tailwind ignores.

**Plugins in v4** use the `@plugin` directive directly in CSS:

```css
@import "tailwindcss";
@plugin "@tailwindcss/typography";
```

No config file. Classes like `prose`, `prose-slate`, `dark:prose-invert` work out of the box. Requires `@tailwindcss/typography` v0.5.19+ for v4 compatibility.

**`@theme inline`** is for when your CSS variables are defined elsewhere (e.g., shadcn's `:root { --background: ... }` variables) and you want Tailwind to expose them as utility classes without redeclaring. Modern shadcn generates this block automatically.

## shadcn/ui uses OKLCH

Current shadcn/ui (v2+) uses OKLCH color space for theme variables, not HSL. Any older guidance saying "shadcn uses HSL vars" is out of date. Example from the current Slate preset:

```css
:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.129 0.042 264.695);
  --primary: oklch(0.208 0.042 265.755);
}
```

OKLCH is perceptually uniform — equal numeric changes produce equal perceptual changes. It handles dark mode variants more cleanly than HSL. Don't convert OKLCH to HSL when editing shadcn themes; keep the OKLCH values the CLI generates.

## Skills

- **accessibility** -- color contrast ratios, visible focus indicators
- **performance** -- minimize CLS, responsive loading strategies
- **ui-design** -- DES-01 through DES-08 for visual hierarchy and polish
- **shadcn** -- style within shadcn's theming system when components exist
