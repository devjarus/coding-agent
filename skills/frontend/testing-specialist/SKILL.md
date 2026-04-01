---
name: testing-specialist
description: Testing specialist knowledge — test architecture, Vitest/Jest configuration, React Testing Library, Playwright e2e tests, MSW API mocking, test factories, and CI parallelization strategies.
---

# Testing Specialist

Framework-agnostic test strategy with deep expertise in the modern JS/TS testing stack.

## When to Apply

- Setting up test infrastructure (Vitest, Jest, Playwright configuration)
- Writing unit tests for utilities, hooks, and business logic
- Writing integration tests for React components with MSW
- Writing Playwright e2e tests for critical user journeys
- Configuring CI test parallelization and sharding
- Designing test factories and fixtures
- Diagnosing flaky or failing tests

## Core Expertise (rules/core-expertise.md)

- Test pyramid: many unit, fewer integration, minimal e2e
- Vitest/Jest configuration: environments, setup files, coverage thresholds
- RTL query priority: `getByRole` > `getByLabelText` > `getByText` > `getByTestId`
- Playwright: Page Object Model, locator assertions, trace viewer, sharding
- MSW: network-level mocking, base handlers + test overrides, reset after each test
- Factories over hard-coded data; fixtures colocated with tests

## Coding Patterns (rules/coding-patterns.md)

- Arrange-Act-Assert structure for every test
- Test behavior (user-visible output), not implementation (internal state)
- One logical assertion per test; descriptive test names
- Factory functions with composable overrides

## Rules

1. **Follow TDD** -- write failing tests before implementation
2. **Tests must be deterministic** -- no random data without seed, no `Date.now()` without mock
3. **No test interdependence** -- each test sets up own state and cleans up
4. **Use RTL query priority** -- `getByRole` first; `getByTestId` only as last resort
5. **Prefer integration tests for UI** -- render full components, mock only network (MSW)
6. **Use Context7 MCP for documentation lookup**
7. **Apply debugging skill** for flaky test diagnosis

## Skills

- **tdd** -- test first, acceptance criteria as executable tests
- **e2e-testing** -- Playwright Page Object Model; critical user journeys
- **integration-testing** -- MSW for API mocking; full context providers

## Workflow

1. Read existing test setup files before writing any tests
2. Use Glob/Grep to locate existing test patterns -- follow conventions
3. Use Context7 MCP for testing library documentation
4. Write tests following arrange-act-assert with RTL query priority
5. Run test suite and ensure all pass
6. Check coverage if threshold configured
7. Fix any test-related lint violations
