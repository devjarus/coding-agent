---
name: composition-patterns
description: React component composition patterns — compound components, variant APIs, state isolation, and React 19 patterns. Use when building or reviewing React component architectures.
---

# Composition Patterns

## When to Apply

- Building new React components
- Reviewing component APIs for flexibility
- Refactoring components with too many boolean props
- Designing shared/reusable component libraries

## Rules by Priority

### CRITICAL — Architecture

**COMP-01: Eliminate boolean prop explosion**
Never accumulate boolean props to express variants. Use a `variant` prop (or compound components) instead of `<Button primary large disabled ghost />`.

**COMP-02: Prefer children composition over configuration props**
Expose structure through children and sub-components rather than growing the props surface. `<Card><Card.Header>Title</Card.Header></Card>` over `<Card title="Title" headerVariant="large" />`.

**COMP-03: Accept and spread native HTML attributes**
Components should extend their underlying element's props via `ComponentPropsWithoutRef<'div'>` (or `'button'`, `'input'`, etc.) so callers can pass `className`, `aria-*`, `data-*`, and event handlers without extra wiring.

### HIGH — State Management

**COMP-04: Isolate shared state in providers**
State shared across a component subtree lives in a Context provider — not prop-drilled through multiple levels. Co-locate the provider with the subtree that needs it.

**COMP-05: Standardize state interfaces**
Every stateful hook returns a predictable shape: `{ data, error, isLoading }` for async data, or `[value, setValue]` for simple toggles/values. Never mix conventions within a codebase.

**COMP-06: Derived state is computed, not stored**
If a value can be calculated from existing state or props, compute it inline or with `useMemo`. Do not mirror it into a separate `useState` — that creates sync bugs.

### MEDIUM — Patterns

**COMP-07: Use variant components over boolean configs**
`<Button variant="primary" size="lg">` scales; `<Button primary large>` does not. Variants map cleanly to design tokens and variant libraries (CVA, Tailwind Variants).

**COMP-08: Compound components share context implicitly**
Group related sub-components under a parent namespace and wire them through context. Example: `Select`, `Select.Trigger`, `Select.Content`, `Select.Item` — callers get flexibility without managing wiring themselves.

**COMP-09: Render props only when children composition is insufficient**
Prefer `children` for layout composition. Use `renderHeader={...}` or similar render props only when you need to inject dynamic content into a position that `children` cannot express.

**COMP-10: Slot pattern for flexible layouts**
Accept named regions via compound sub-components or explicit slot props (`header`, `footer`, `actions`). This keeps the component's structure open for extension without an ever-growing props list.

### LOW — React 19+

**COMP-11: Drop `forwardRef`**
React 19 passes `ref` as a regular prop. Remove `forwardRef` wrappers — they add indirection with no benefit on React 19+.

**COMP-12: Use `use()` over `useContext()`**
`use()` works inside conditionals and loops; `useContext()` does not. Prefer `use(MyContext)` for reading context values in React 19+.

**COMP-13: Server Components by default**
Start every new component as a Server Component. Add `'use client'` only when the component requires interactivity, hooks, or browser APIs. This keeps the client bundle lean and enables streaming.

## Examples

### COMP-01 — Boolean explosion → Variant API

**Before**
```tsx
// Props accumulate with every new design requirement
<Button primary large disabled ghost loading />
```

**After**
```tsx
type ButtonProps = ComponentPropsWithoutRef<'button'> & {
  variant?: 'primary' | 'ghost' | 'danger';
  size?: 'sm' | 'md' | 'lg';
};

function Button({ variant = 'primary', size = 'md', ...props }: ButtonProps) {
  return <button className={styles[variant][size]} {...props} />;
}

// Usage
<Button variant="ghost" size="lg">Cancel</Button>
<Button variant="primary" size="md">Save</Button>
```

---

### COMP-02 — Config props → Children composition

**Before**
```tsx
// Caller has no control over structure or ordering
<Card
  title="Account settings"
  subtitle="Manage your profile"
  headerVariant="large"
  footerContent={<button>Save</button>}
/>
```

**After**
```tsx
function Card({ children, ...props }: ComponentPropsWithoutRef<'div'>) {
  return <div className="card" {...props}>{children}</div>;
}
Card.Header = function CardHeader({ children }: { children: ReactNode }) {
  return <div className="card-header">{children}</div>;
};
Card.Body = function CardBody({ children }: { children: ReactNode }) {
  return <div className="card-body">{children}</div>;
};
Card.Footer = function CardFooter({ children }: { children: ReactNode }) {
  return <div className="card-footer">{children}</div>;
};

// Usage — caller controls structure entirely
<Card>
  <Card.Header>
    <h2>Account settings</h2>
    <p>Manage your profile</p>
  </Card.Header>
  <Card.Body>...</Card.Body>
  <Card.Footer><button>Save</button></Card.Footer>
</Card>
```
