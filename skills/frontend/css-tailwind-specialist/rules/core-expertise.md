# CSS / Tailwind Core Expertise

## Tailwind CSS
- Apply utility classes directly in markup -- prefer composing utilities over writing custom CSS
- Extend `tailwind.config.ts` to add design tokens: custom colors, spacing, font sizes, breakpoints, shadows, and border radii
- Write Tailwind plugins for complex, repeated patterns that cannot be expressed with simple utilities
- Use `@apply` sparingly and only for utility groups genuinely repeated across many unrelated places
- Understand Tailwind's JIT engine: all class names must appear as complete strings -- never construct dynamically
- Use the `cn()` / `clsx()` / `twMerge()` pattern to conditionally compose class strings

## Layout: Flexbox & Grid
- Use Flexbox for one-dimensional layouts (rows or columns)
- Use CSS Grid for two-dimensional layouts (complex page structure, overlapping areas)
- Use container queries (`@container`) for components that must adapt to parent size
- Avoid fixed pixel dimensions on containers; use `max-w-*`, `min-h-*`, percentage, or `fr` units

## CSS Custom Properties & Design Tokens
- Define design tokens as CSS custom properties on `:root`
- Map tokens into `tailwind.config` using `var(--token-name)`
- Use semantic token names (`--color-surface`, `--color-text-primary`, `--color-brand`)
- Scope component-level overrides with local custom properties
- Use custom properties for theming (light/dark) -- swap variable values, not utility classes

## Animations & Transitions
- Use `transition` utilities for simple state changes
- Use `animate-*` utilities for looping animations; extend config with custom keyframes
- Always respect `prefers-reduced-motion` -- wrap in `motion-safe:` variant
- Durations: micro-interactions 100-200ms, transitions 200-400ms, large motion 400-600ms
- Use `will-change` sparingly and only on actively animating elements

## Responsive Design (Mobile-First)
- Base styles for smallest viewport first, then layer on with `sm:`, `md:`, `lg:`, `xl:`
- Prefer fluid sizing (`clamp()`, viewport units, `min()`, `max()`) over hard breakpoint jumps
- Test at 375px (mobile), 768px (tablet), 1280px (desktop), 1920px (wide)

## Dark Mode
- Use Tailwind's `dark:` variant
- `darkMode: 'class'` for JS-toggled dark mode; `darkMode: 'media'` for OS preference
- Derive dark mode values from design tokens, never hard-code

## Color & Contrast
- WCAG 2.1 AA: 4.5:1 for normal text, 3:1 for large text and UI components
- Do not rely on color alone to convey information
- Prefer design system palette; never introduce ad-hoc hex values

## Focus & Keyboard Navigation
- Use `focus-visible:` to show focus rings only for keyboard navigation
- Never suppress `outline` without providing an equivalent custom focus indicator

## Coding Patterns

### Class Organization (recommended order)
1. Layout & positioning (`flex`, `grid`, `absolute`, `z-*`)
2. Box model (`w-*`, `h-*`, `p-*`, `m-*`, `border-*`, `rounded-*`)
3. Typography (`text-*`, `font-*`, `leading-*`, `tracking-*`)
4. Color & background (`bg-*`, `text-color-*`, `border-color-*`)
5. Effects (`shadow-*`, `opacity-*`, `ring-*`)
6. Responsive variants (`sm:`, `md:`, `lg:`)
7. State variants (`hover:`, `focus-visible:`, `active:`, `disabled:`)
8. Dark mode variants (`dark:`)
9. Motion variants (`motion-safe:`, `motion-reduce:`)

### Conditional Classes
```tsx
import { cn } from '@/lib/utils';

<div className={cn(
  'base-classes',
  isActive && 'active-classes',
  variant === 'primary' ? 'primary-classes' : 'secondary-classes',
)} />
```

### Design Token Extension
```ts
export default {
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: 'var(--color-brand)',
          hover: 'var(--color-brand-hover)',
        },
        surface: 'var(--color-surface)',
        'text-primary': 'var(--color-text-primary)',
      },
    },
  },
};
```

### Reduced Motion
```tsx
<div className="motion-safe:animate-spin motion-reduce:hidden" />
```
