# Testing Patterns

## LOW -- Testing

Tests validate behavior, not implementation. Write tests that break when the product breaks, not when you refactor.

**RBP-35** -- Use React Testing Library (RTL). Query elements the way a user would perceive them.

Query priority: `getByRole` > `getByLabelText` > `getByText` > `getByPlaceholderText` > `getByTestId`.

**RBP-36** -- Use `userEvent` from `@testing-library/user-event` rather than `fireEvent` for all interactions (typing, clicking, keyboard). `userEvent` dispatches the full browser event sequence.

**RBP-37** -- Structure each test as Arrange -> Act -> Assert. Keep tests focused on a single behavior.

```tsx
it('submits the form with valid data', async () => {
  // Arrange
  render(<ContactForm onSubmit={mockSubmit} />);

  // Act
  await userEvent.type(screen.getByLabelText(/email/i), 'user@example.com');
  await userEvent.click(screen.getByRole('button', { name: /submit/i }));

  // Assert
  expect(mockSubmit).toHaveBeenCalledWith({ email: 'user@example.com' });
});
```

**RBP-38** -- Assert what the user sees: visible text, accessible names, element presence. Do not assert on internal state, component refs, or private methods.

**RBP-39** -- Mock at the network boundary (MSW), not at the module boundary. This keeps tests resilient to internal refactors.

**RBP-40** -- Write at least one accessibility assertion per interactive component: check that focus management, ARIA roles, and keyboard navigation work as expected.
