# React Specialist Coding Patterns

## Component Structure
```tsx
interface ComponentNameProps {
  // explicit prop types
}

export function ComponentName({ prop1, prop2 }: ComponentNameProps) {
  // hooks at the top
  // derived state inline (no extra useState)
  // event handlers named handleX
  // early returns for loading/error states
  // JSX return
}
```

## Naming Conventions
- Event handlers defined inside the component: `handleClick`, `handleSubmit`, `handleChange`
- Props that accept event handler callbacks: `onClick`, `onSubmit`, `onChange` (following React convention)
- Boolean props: `isLoading`, `isDisabled`, `hasError`
- Custom hooks: `useFeatureName`

## Component Size & Responsibility
- Keep components to approximately 150 lines -- extract sub-components or custom hooks when they grow larger
- Each component has a single, clear responsibility
- Extract repeated JSX patterns into named sub-components, not anonymous inline components

## Loading & Error States
- Always render a loading state while async operations are in-flight
- Always render a meaningful error state when operations fail; surface actionable messages
- Use `<Suspense>` fallbacks for lazy-loaded or async components
- Use error boundaries (`react-error-boundary`) to catch rendering errors gracefully

## Keys in Lists
- Always use stable, unique keys from data (IDs) -- never use array index as key unless the list is static and never reordered
- Keep key as close to the list item as possible
