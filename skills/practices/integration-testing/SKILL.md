---
name: integration-testing
description: Integration testing patterns using stateful API emulation, service containers, and contract testing. Use when testing code that interacts with external APIs, databases, or third-party services.
---

## When to Apply
- Testing code that calls external APIs (GitHub, Stripe, AWS, etc.)
- Testing database interactions beyond unit tests
- Verifying frontend-backend contracts
- CI/CD pipelines where real services aren't available

## Priority Rules (inspired by Vercel agent-skills format)

### CRITICAL Priority
- INT-01: Never call real external APIs in tests — use emulators, service containers, or test doubles
- INT-02: Tests must be deterministic — same input produces same output every run
- INT-03: Test state must be isolated — each test starts clean, no shared mutable state between tests

### HIGH Priority
- INT-04: Use service containers (Docker) for databases in integration tests — not mocks
- INT-05: API contract tests verify request/response shapes match between producer and consumer
- INT-06: Use `emulate` or similar tools for third-party API testing (GitHub, AWS S3, Slack) — they provide stateful localhost servers with real protocol behavior

### MEDIUM Priority
- INT-07: Seed test data via config, not inline setup — makes tests readable and state reproducible
- INT-08: Reset state between tests — use beforeEach/afterEach hooks to wipe and reseed
- INT-09: Test error paths — network failures, rate limits, auth failures, malformed responses

### Patterns

#### Pattern 1: Database Integration Tests
- Use docker-compose for Postgres/Redis/MongoDB in CI
- Run migrations before tests, reset between test suites
- Use transactions for test isolation (begin before test, rollback after)

#### Pattern 2: API Emulation (Vercel emulate style)
- Start emulator before tests: `createEmulator({ service: 'github', port: 4001 })`
- Point env vars to localhost: `GITHUB_API_URL=http://localhost:4001`
- Seed with test data: users, repos, tokens
- Reset between tests: `emulator.reset()`
- Assert via the emulated API or by inspecting state

#### Pattern 3: Contract Testing
- Define shared API contracts (OpenAPI spec, TypeScript types, Zod schemas)
- Frontend tests verify they send the right request shape
- Backend tests verify they return the right response shape
- Both sides test against the same contract definition

#### Pattern 4: Network Failure Testing
- Simulate timeouts, connection refused, 500 errors
- Verify retry logic works (exponential backoff)
- Verify circuit breaker triggers after N failures
- Verify graceful degradation (show cached data, error UI)

## Anti-Patterns
- Mocking everything — hides integration bugs
- Sharing test databases between parallel test suites — causes flaky tests
- Testing against production APIs — slow, expensive, non-deterministic
- Ignoring error paths — happy-path-only tests miss real failures
