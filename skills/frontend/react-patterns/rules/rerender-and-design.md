# Re-render Prevention & Component Design

## MEDIUM -- Re-render Prevention

Optimize only after measuring. Premature memoization adds complexity and can hide real bugs.

**RBP-23** -- Apply `React.memo` only to components you have profiled and confirmed re-render unnecessarily. Wrapping every component wastes memory and obscures data flow.

**RBP-24** -- Use `useCallback` to stabilize function references passed as props to memoized children or used as `useEffect` dependencies -- not as a blanket optimization.

**RBP-25** -- Use `useMemo` for expensive calculations (> 1 ms) or to produce stable object/array references consumed by memoized children. Avoid `useMemo` for primitive values.

**RBP-26** -- Derive values from state rather than syncing them in a `useEffect`. Derived values never get out of sync.

```tsx
// Bad -- sync in effect
const [fullName, setFullName] = useState('');
useEffect(() => setFullName(`${first} ${last}`), [first, last]);

// Good -- derive directly
const fullName = `${first} ${last}`;
```

**RBP-27** -- Key strategy for lists: use stable, unique, domain IDs (e.g., `item.id`). Never use array index as a key for lists that can reorder or filter.

**RBP-28** -- Use the React DevTools Profiler and `<Profiler>` API to measure before and after any memoization change. Document the measured gain in the PR description.

## MEDIUM -- Component Design

Structure components for clarity, testability, and long-term maintainability.

**RBP-29** -- Single responsibility: a component should do one thing. If a component needs a long comment to explain what it does, split it.

**RBP-30** -- Prefer composition over configuration. Expose `children` and named slots (render props or compound components) rather than an ever-growing list of boolean props.

```tsx
// Bad -- configuration explosion
<Modal title="..." footer="..." showClose={true} onClose={...} />

// Good -- composable slots
<Modal>
  <Modal.Header>...</Modal.Header>
  <Modal.Body>...</Modal.Body>
  <Modal.Footer>...</Modal.Footer>
</Modal>
```

**RBP-31** -- Define an explicit TypeScript props interface. Destructure props with defaults at the function signature level.

```tsx
interface CardProps {
  title: string;
  variant?: 'default' | 'outlined';
  children: React.ReactNode;
}

function Card({ title, variant = 'default', children }: CardProps) { ... }
```

**RBP-32** -- Avoid prop-drilling beyond two levels. Introduce a context or a co-located state hook instead.

**RBP-33** -- Keep component files under 200 lines. Extract sub-components, helpers, and hooks into sibling files when the file grows beyond that.

**RBP-34** -- Name event handler props `onX` and the implementing functions `handleX` for consistency across the codebase.
