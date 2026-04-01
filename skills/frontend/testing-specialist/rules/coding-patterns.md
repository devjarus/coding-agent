# Testing Coding Patterns

## Arrange-Act-Assert
```typescript
it('shows error message when login fails', async () => {
  // Arrange
  server.use(http.post('/api/login', () => HttpResponse.json({ error: 'Invalid credentials' }, { status: 401 })));
  render(<LoginForm />);

  // Act
  await userEvent.type(screen.getByLabelText('Email'), 'bad@example.com');
  await userEvent.type(screen.getByLabelText('Password'), 'wrong');
  await userEvent.click(screen.getByRole('button', { name: 'Sign in' }));

  // Assert
  expect(await screen.findByRole('alert')).toHaveTextContent('Invalid credentials');
});
```

## Test Behavior, Not Implementation
```typescript
// Bad -- tests internal state
expect(component.state.isLoading).toBe(false);

// Good -- tests what the user sees
expect(screen.queryByRole('progressbar')).not.toBeInTheDocument();
```

## One Assertion Per Test (logical)
Group related assertions only when they describe a single behavior. Split tests when failure messages would be ambiguous.

## Descriptive Test Names
```typescript
// Bad
it('works correctly', ...)

// Good
it('disables the submit button while the form is submitting', ...)
it('redirects to /dashboard after successful login', ...)
```

## Factory Functions
```typescript
function makeUser(overrides: Partial<User> = {}): User {
  return {
    id: 'user-1',
    email: 'test@example.com',
    name: 'Test User',
    role: 'viewer',
    ...overrides,
  };
}
```
