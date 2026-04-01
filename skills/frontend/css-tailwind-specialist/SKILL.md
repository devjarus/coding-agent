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

1. **Follow the design system** -- no colors, spacing, or typography outside `tailwind.config`
2. **Responsive is required** -- validate at mobile, tablet, and desktop widths
3. **No inline styles** -- all styles through Tailwind utilities or CSS custom properties
4. **Contrast meets WCAG AA** -- verify every text-on-background pairing
5. **`@apply` only for highly repeated patterns**
6. **No dynamic class name construction** -- use `cn()` with full class names
7. **`focus-visible:` not `focus:`** -- mouse users should not see focus indicators
8. **`prefers-reduced-motion` always** -- every animation needs a safe fallback

## Skills

- **accessibility** -- color contrast ratios, visible focus indicators
- **performance** -- minimize CLS, responsive loading strategies
- **ui-design** -- DES-01 through DES-08 for visual hierarchy and polish
- **shadcn** -- style within shadcn's theming system when components exist
