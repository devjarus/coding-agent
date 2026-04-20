---
name: test-doubles-strategy
description: Decide when to use unit vs integration vs e2e tests, and when to mock vs use the real thing per dependency. Dependency injection is the enabler — without it you end up monkey-patching imports. Apply when writing tests of any kind.
---

# Test Doubles Strategy

Three decisions, in order:

1. **What level of test am I writing?** (unit / integration / e2e)
2. **For each dependency the code under test touches, do I use the real thing or a double?**
3. **If a double, which kind?** (fake, stub, spy, mock — they're not synonyms)

Dependency injection is the mechanism that makes choice #2 cheap. Without DI, swapping a dependency means patching the module loader, which is brittle and ties the test to implementation details.

## Test Levels — Pick One Per File

| Level | What runs | What's real | What's faked | Target speed |
|-------|-----------|-------------|--------------|--------------|
| **Unit** | One function/class | Nothing external | All I/O dependencies | <10ms |
| **Integration** | Your code + 1 real external | Code + one adapter (DB, queue, cache) | Everything else | 100ms–2s |
| **E2E** | Full system from outside | Everything you own | Only third parties you can't run (Stripe, OAuth providers) | 5s–30s |

### How many of each

Shape: many unit, fewer integration, handful of e2e. Not because of the "pyramid" as dogma — because unit tests give you precise failure locality, e2e gives you confidence the seams work, integration bridges the two.

**If you only write one level, write integration.** Unit tests with everything mocked can pass while prod is broken. E2E is too slow for TDD loops. Integration catches the most real bugs per minute of dev time.

## Mock vs Real — By Dependency Type

| Dependency | Unit test | Integration test | E2E test |
|-----------|-----------|------------------|----------|
| **Your own pure functions** | Real (just call them) | Real | Real |
| **Database** | In-memory fake OR don't test this layer | **Real** via testcontainers / docker-compose | Real |
| **HTTP to 3rd party (Stripe, GitHub, OpenAI)** | Stub at adapter boundary | Recorded fixtures (nock/msw/VCR) OR local emulator | Sandbox account if provider offers one, else recorded |
| **Filesystem** | `memfs` or temp dir | Real temp dir | Real |
| **Time / Date.now / timers** | Fake clock (sinon, vi.useFakeTimers) | Fake clock | Real, with generous timeouts |
| **Randomness / UUIDs** | Injected RNG returning fixed values | Same | Real |
| **Env vars / config** | Pass config as param | Test-scoped config | Real test env |
| **Message queue / pubsub** | In-memory fake | Real broker in testcontainers | Real |
| **Internal microservice** | Stub the client | Real if practical, else contract test + stub | Real |
| **Browser / Playwright** | N/A | N/A | Real browser |

### The rule that resolves most arguments

> **Don't mock what you don't own.** Wrap it in an adapter you do own, and fake the adapter.

If you `jest.mock('stripe')` and they ship a breaking change in v20, your tests still pass and your prod breaks. If you have a `PaymentGateway` interface and a `StripePaymentGateway` adapter, your unit tests fake `PaymentGateway`, and you have one integration test against real Stripe (or their recorded test mode) that catches upstream breaks.

## The Four Kinds of Double (not synonyms)

| Kind | What it does | When to use |
|------|--------------|------------|
| **Fake** | Working implementation with a shortcut (in-memory DB, in-memory queue) | Unit tests of code that needs realistic behavior from the dep |
| **Stub** | Returns canned answers, no verification | "Given this HTTP response, does my code do X?" |
| **Spy** | Wraps real or stub, records calls for assertion | "Did we call the logger with this level?" |
| **Mock** | Stub + pre-programmed expectations, fails if calls don't match | Rare. Use only when the *interaction* is the behavior under test |

Default to **fakes and stubs**. Reach for mocks only when "did we call X with Y in this order" is the actual requirement. Over-mocking produces tests that break on every refactor without catching real bugs.

## How Dependency Injection Enables This

Without DI, you end up with this:

```ts
// user-service.ts
import { db } from "./db";
export async function getUser(id: string) {
  return db.query("select ...", [id]);
}

// user-service.test.ts
jest.mock("./db"); // fragile — ties test to import path
(db.query as jest.Mock).mockResolvedValue({ id: "u1" });
```

The test is coupled to the file layout. Rename `./db` → test breaks without a signal. Move the import → test breaks. Add a second db client → ambiguous mock.

With DI:

```ts
// user-service.ts
export function createUserService(deps: { db: Db; clock: Clock }) {
  return {
    getUser: (id: string) => deps.db.query("select ...", [id]),
  };
}

// user-service.test.ts — no module patching
const fakeDb: Db = { query: async () => ({ id: "u1" }) };
const fakeClock: Clock = { now: () => new Date("2026-01-01") };
const svc = createUserService({ db: fakeDb, clock: fakeClock });
```

The test talks to the same contract production does. Refactoring the import graph doesn't touch the test. Swapping the real DB for a docker-compose Postgres in integration tests is a one-line change at the composition root.

See `config-management/rules/dependency-injection.md` for the DI pattern per language (TS, Python, Java, Go, Swift).

## Practical Patterns

### 1. Fake objects beat mock libraries for data-shaped dependencies

```ts
// Better than jest.mock + mockResolvedValue for a repo:
function fakeUserRepo(seed: User[] = []): UserRepository {
  const users = new Map(seed.map((u) => [u.id, u]));
  return {
    findById: async (id) => users.get(id) ?? null,
    save: async (u) => { users.set(u.id, u); return u; },
  };
}
```

The fake is real code, typed against the same interface. Refactoring the interface breaks the fake (good — forces you to update both).

### 2. Inject the clock, never call `Date.now()` directly

```ts
type Clock = { now(): Date };
const realClock: Clock = { now: () => new Date() };

// in code under test
if (deps.clock.now() > expiry) { /* ... */ }

// in test
const fixed: Clock = { now: () => new Date("2026-04-19T12:00:00Z") };
```

Time-dependent bugs are a leading cause of flakes. This eliminates them.

### 3. Boundary adapters for third-party SDKs

```ts
// stripe-gateway.ts — the ONLY file that imports from 'stripe'
export interface PaymentGateway {
  charge(amountCents: number, card: CardRef): Promise<ChargeResult>;
}

export class StripePaymentGateway implements PaymentGateway {
  constructor(private client: Stripe) {}
  async charge(cents: number, card: CardRef) {
    const result = await this.client.charges.create({ amount: cents, source: card.token });
    return { id: result.id, status: result.status };
  }
}
```

- Unit tests: fake `PaymentGateway`
- Integration tests: real `StripePaymentGateway` pointed at Stripe's test mode
- Migration to Adyen someday: write `AdyenPaymentGateway`, tests don't change

### 4. Integration tests get ONE real dep per test

An integration test for the user service uses real Postgres. It stubs the mailer, the payment gateway, and the analytics client. That keeps the test failure message meaningful: if it fails, the issue is in the user/db integration, not somewhere downstream.

## Anti-Patterns

| Smell | Why it's bad | Fix |
|-------|--------------|-----|
| `jest.mock('../db')` in every test file | Tests coupled to file paths | Constructor-inject the db |
| Mocking your own class's methods | Testing the mock, not the code | Refactor: extract the dependency |
| Snapshot tests of mock call histories | Reviewing them becomes ignoring them | Assert specific behaviors, not every call |
| One giant `setupMocks()` in `beforeEach` | Tests can't be read in isolation | Build the world per test, or extract one named fake factory |
| Mocking to make a flaky test pass | Hides the real bug | Find the race/time/ordering issue |
| Integration tests with `jest.mock('pg')` | It's not an integration test anymore | Run a real Postgres (testcontainers) |
| Asserting on private internals via spy | Refactor breaks test without changing behavior | Assert on observable outputs |

## Rules

1. **Test level is a choice, not a mood.** Name the file accordingly: `*.test.ts` / `*.unit.test.ts` / `*.integration.test.ts` / `*.e2e.test.ts` so the test runner can split them.
2. **DI is non-negotiable for anything that touches I/O.** If you need `jest.mock` to test a function, the function's dependencies should have been parameters.
3. **Don't mock what you don't own.** Wrap in an adapter; fake the adapter.
4. **Fakes > stubs > mocks.** Reach down the list only when the one above doesn't fit.
5. **One real dependency per integration test.** Everything else is a fake. Keeps failure localization intact.
6. **Never mock the thing under test.** If you feel the urge, the abstraction is wrong.
7. **Time, randomness, and the filesystem are dependencies.** Inject them. Flaky tests disappear.
8. **If a test passes with the implementation deleted, it's not a test.** (run the "mutation test" mentally before committing.)

## Decision Checklist (Before Writing a Test)

- [ ] What level? (unit / integration / e2e)
- [ ] What's the single behavior this test proves?
- [ ] For each dependency: real, fake, stub, or mock — and why?
- [ ] Is the code under test receiving its dependencies via constructor/parameter, or reaching into the module graph? (Fix before writing the test.)
- [ ] If this test passes with the production code deleted, is it actually testing anything?
