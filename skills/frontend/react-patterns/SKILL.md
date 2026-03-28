---
name: react-patterns
description: Modern React patterns and conventions for React 18+. Use when building React components.
---

# React Patterns

## Component Design

- Prefer composition over configuration: expose `children` and named slots rather than a growing list of props.
- Keep components focused on a single responsibility — split when a component does too many things.
- Define an explicit props interface. Destructure props with defaults at the top of the function signature.

```tsx
function Card({ title, children, variant = 'default' }: CardProps) { ... }
```

## Hooks Patterns

- Extract reusable logic into custom hooks prefixed with `use` (e.g., `useDebounce`, `useLocalStorage`).
- Return a tuple for simple value/setter pairs; return an object when there are multiple values.
- One concern per `useEffect`: split effects that manage different things into separate hooks.
- Always provide a cleanup function when the effect sets up subscriptions, timers, or listeners.
- Include all referenced values in the dependency array — rely on the exhaustive-deps lint rule.

### State Management Guidelines

| Scope | Tool |
|---|---|
| Local UI state | `useState` |
| Complex or multi-step state | `useReducer` |
| Shared state for a subtree | `React.createContext` + `useContext` |
| Global / cross-cutting state | External store (Zustand, Redux Toolkit, Jotai) |

Avoid lifting state higher than necessary. Co-locate state with the components that use it.

## Testing

Use **React Testing Library** (RTL). Test behavior from the user's perspective, not implementation details.

- **Query priority**: `getByRole` > `getByLabelText` > `getByText` > `getByTestId`.
- **Simulate real interactions**: use `userEvent` over `fireEvent` for typing, clicking, and keyboard events.
- **Assert what the user sees**: check visible text, accessible names, and element presence — not internal state or component structure.

```tsx
// Prefer
const button = screen.getByRole('button', { name: /submit/i });
await userEvent.click(button);
expect(screen.getByText('Success')).toBeInTheDocument();
```

Avoid testing implementation details like state values, private methods, or internal component structure.
