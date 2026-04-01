# Testing Specialist Core Expertise

## Test Pyramid
- Unit tests: fast, isolated, no I/O -- cover pure functions, hooks, utilities, business logic
- Integration tests: components with state, API handlers with DB layer
- E2E tests: simulate real user flows -- reserve for critical journeys, not coverage padding
- Proportions: many unit, fewer integration, minimal e2e

## Vitest / Jest Configuration
- `vitest.config.ts` / `jest.config.ts`: `testEnvironment`, `setupFiles`, `globalSetup`, `moduleNameMapper`, `coverage` thresholds
- TypeScript support: `ts-jest` (Jest) or native (Vitest) with strict mode in tests
- Coverage: `v8` (Vitest) or `babel` (Jest) -- aim for meaningful coverage on business logic

## React Testing Library
- Query priority: `getByRole` > `getByLabelText` > `getByText` > `getByDisplayValue` > `getByAltText` > `getByTitle` > `getByTestId`
- `userEvent` over `fireEvent` for realistic interaction simulation
- `screen` API for queries; `within()` to scope to subtree
- `waitFor`, `findBy*` for async assertions -- never use arbitrary `setTimeout`
- `renderHook` for testing custom hooks in isolation

## Playwright for E2E
- Page Object Model for reusable page interactions
- Locator-based assertions: `expect(locator).toBeVisible()` / `.toHaveText()` / `.toHaveValue()`
- `page.route()` to intercept and mock network requests at browser level
- Trace viewer, screenshots, and video for debugging CI failures
- Parallelization with `workers` and test sharding

## Test Fixtures and Factories
- Factory functions over hard-coded test data -- composable with overrides
- Keep fixtures close to tests; colocate `__fixtures__` directories
- Use `faker` or manual factories for realistic deterministic data

## MSW (Mock Service Worker)
- API mocking at network level -- real fetch calls, MSW intercepts
- `setupServer` (Node) and `setupWorker` (browser)
- Base handlers in `mocks/handlers.ts`, test-specific overrides with `server.use()`
- Reset handlers after each test: `afterEach(() => server.resetHandlers())`

## CI Test Parallelization
- Shard Playwright: `--shard=1/4`, `--shard=2/4` etc.
- Vitest/Jest: `--maxWorkers` tuned to CI runner CPU count
- Separate jobs: unit/integration fast, e2e separate -- fail fast on cheap tests
