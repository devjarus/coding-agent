---
name: service-architecture
description: Patterns for structuring applications with external clients, services, and infrastructure — singletons, client factories, connection pools, retry wrappers, graceful shutdown, and service layer organization. Apply when an app connects to databases, APIs, caches, queues, or any external system.
---

# Service Architecture

How to structure the code between your business logic and external systems (databases, APIs, caches, queues, LLM providers). Covers lifecycle management, client creation, error boundaries, and the patterns that prevent "it works on my machine" bugs.

## When to Apply

- App connects to any external system (DB, Redis, S3, Stripe, OpenAI, etc.)
- Multiple services share the same client instance
- Need connection pooling, retries, timeouts, or graceful shutdown
- Building a CLI tool, API server, or agent that calls external APIs

## Client Lifecycle Patterns

### Singleton — Create Once, Share Everywhere

Use for clients that are expensive to create and safe to share (DB pools, HTTP clients with connection reuse, SDK clients).

```typescript
// clients.ts — factory creates singleton instances
export function createClients(config: AppConfig) {
  const db = new Pool({
    connectionString: config.database.url,
    max: config.database.poolSize ?? 20,
    idleTimeoutMillis: 30_000,
  });

  const redis = new Redis(config.redis.url, {
    maxRetriesPerRequest: 3,
    retryStrategy: (times) => Math.min(times * 200, 2000),
  });

  const stripe = new Stripe(config.stripe.secretKey, {
    apiVersion: "2024-12-18",
    timeout: 10_000,
    maxNetworkRetries: 2,
  });

  const s3 = new S3Client({
    region: config.aws.region,
    credentials: config.aws.credentials,
  });

  return { db, redis, stripe, s3 };
}

// composition-root.ts
const clients = createClients(config);
const userService = new UserService(clients.db, clients.redis, logger);
const paymentService = new PaymentService(clients.stripe, clients.db, logger);
```

**Rules for singletons:**
- Create in composition root, inject everywhere
- Never create inside a request handler or service method
- Always shut down on process exit (see Graceful Shutdown)

### Per-Request — Create Fresh Each Time

Use for clients that carry request-specific state or can't be shared (database transactions, authenticated API clients with per-user tokens).

```typescript
// Transaction per request
app.use(async (req, res, next) => {
  const tx = await db.beginTransaction();
  req.tx = tx;
  try {
    await next();
    await tx.commit();
  } catch (err) {
    await tx.rollback();
    throw err;
  }
});

// Per-user API client
function createUserGitHubClient(accessToken: string) {
  return new Octokit({ auth: accessToken });
}
```

### Lazy Singleton — Create on First Use

Use when the client might not be needed in every code path, or initialization is slow.

```typescript
class LazyClient<T> {
  private instance: T | null = null;
  constructor(private factory: () => T) {}

  get(): T {
    if (!this.instance) {
      this.instance = this.factory();
    }
    return this.instance;
  }

  async shutdown(): Promise<void> {
    if (this.instance && 'close' in this.instance) {
      await (this.instance as any).close();
    }
  }
}

// Usage
const searchClient = new LazyClient(() => new MeiliSearch({ host: config.search.url }));
// Only creates MeiliSearch client when first accessed
```

## Connection Pooling

Every database and HTTP client should use connection pooling. Creating a new connection per request is slow and can exhaust server resources.

```typescript
// Database — pool is the singleton, connections are per-query
const pool = new Pool({ max: 20 });       // 20 connections shared
const result = await pool.query(sql);      // borrows a connection, returns it after

// HTTP — reuse agent/client
const httpClient = new undici.Pool(baseUrl, {
  connections: 10,
  pipelining: 1,
  keepAliveTimeout: 30_000,
});
```

```python
# Python — httpx with connection pooling
client = httpx.AsyncClient(
    base_url="https://api.stripe.com",
    timeout=10.0,
    limits=httpx.Limits(max_connections=20, max_keepalive_connections=10),
)
# Use client across requests — don't create per request
```

```go
// Go — http.Client is safe to share, reuses connections by default
var httpClient = &http.Client{
    Timeout: 10 * time.Second,
    Transport: &http.Transport{
        MaxIdleConns:        100,
        MaxIdleConnsPerHost: 10,
        IdleConnTimeout:     30 * time.Second,
    },
}
```

## Retry & Timeout Wrappers

External calls fail. Wrap them with retries and timeouts.

```typescript
// Generic retry wrapper
async function withRetry<T>(
  fn: () => Promise<T>,
  opts: { maxRetries?: number; baseDelayMs?: number; retryOn?: (err: any) => boolean } = {}
): Promise<T> {
  const { maxRetries = 3, baseDelayMs = 500, retryOn = () => true } = opts;
  let lastError: Error;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err as Error;
      if (attempt === maxRetries || !retryOn(err)) throw lastError;
      const delay = baseDelayMs * Math.pow(2, attempt); // exponential backoff
      await new Promise(r => setTimeout(r, delay));
    }
  }
  throw lastError!;
}

// Usage — retry on rate limits and server errors
const result = await withRetry(
  () => stripe.charges.create({ amount: 1000, currency: "usd" }),
  {
    maxRetries: 3,
    retryOn: (err) => err.statusCode === 429 || err.statusCode >= 500,
  }
);
```

**Timeout pattern:**
```typescript
// AbortController for fetch timeouts
async function fetchWithTimeout(url: string, timeoutMs: number = 10_000) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}
```

**Rules:**
- **Always set timeouts.** No external call should hang forever.
- **Retry only on transient errors** (429, 500, 502, 503, network timeout). Never retry 400/401/403/404.
- **Exponential backoff with jitter.** Don't hammer a failing service.
- **Circuit breaker for critical paths.** If a service fails N times in M seconds, stop calling it temporarily.

## Graceful Shutdown

Every singleton client must be shut down when the process exits. Leaked connections exhaust pool limits.

```typescript
// shutdown.ts
type ShutdownFn = () => Promise<void>;
const shutdownFns: ShutdownFn[] = [];

export function onShutdown(fn: ShutdownFn) {
  shutdownFns.push(fn);
}

async function shutdown(signal: string) {
  logger.info({ signal }, "Shutting down");
  for (const fn of shutdownFns.reverse()) { // reverse order: last created, first closed
    try { await fn(); } catch (err) { logger.error({ err }, "Shutdown error"); }
  }
  process.exit(0);
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));

// Register in composition root
onShutdown(() => clients.db.end());
onShutdown(() => clients.redis.quit());
onShutdown(() => server.close());
```

**Rules:**
- Shut down in reverse order (HTTP server first → services → DB last)
- Set a force-exit timeout (10s) in case graceful shutdown hangs
- In containers: handle SIGTERM (Docker/K8s sends this, not SIGINT)

## Service Layer Organization

```
src/
├── config.ts                  # Reads env vars, exports typed config
├── clients.ts                 # Creates singleton external clients
├── composition-root.ts        # Wires everything together
│
├── services/                  # Business logic — depends on repositories, NOT on clients directly
│   ├── user-service.ts        # Accepts UserRepository interface
│   └── payment-service.ts     # Accepts PaymentGateway interface
│
├── repositories/              # Data access — wraps database clients
│   ├── user-repo.ts           # Accepts Pool, implements UserRepository
│   └── order-repo.ts
│
├── gateways/                  # External API wrappers — wraps SDK clients
│   ├── stripe-gateway.ts      # Accepts Stripe client, implements PaymentGateway
│   ├── email-gateway.ts       # Accepts SendGrid client
│   └── search-gateway.ts      # Accepts MeiliSearch client
│
├── middleware/                 # HTTP concerns (auth, logging, error handling)
└── routes/                    # HTTP handlers — thin, delegate to services
```

**Layering rules:**
- **Routes** call **Services** (never call repositories or clients directly)
- **Services** call **Repositories** and **Gateways** (never import DB/SDK directly)
- **Repositories** wrap database access
- **Gateways** wrap external API access
- **Clients** are singletons created in composition root, injected into repos/gateways

## Anti-Patterns

- **Creating clients inside request handlers** — creates per-request connections, exhausts pool
- **No shutdown handler** — leaked DB connections, unfinished writes
- **Retrying non-retryable errors** — retrying 401/404 wastes time and may trigger rate limits
- **No timeouts on external calls** — one slow API blocks the entire server
- **Services importing clients directly** — hardwired, untestable
- **"God service" that does everything** — break by domain (UserService, PaymentService, not AppService)
- **Mixing HTTP concerns with business logic** — routes should be thin, services should be framework-agnostic

## Rules

1. **Create clients once (singleton), inject everywhere.** Never `new Pool()` inside a handler.
2. **Every external call has a timeout.** No infinite hangs.
3. **Retry only transient errors.** 429, 500-503, network timeout. Not 400/401/404.
4. **Graceful shutdown shuts down everything.** DB, Redis, HTTP server, in reverse order.
5. **Services don't know about infrastructure.** They call repository/gateway interfaces, not DB/SDK directly.
6. **Gateway per external system.** Stripe Gateway, Email Gateway — isolates external API changes.
