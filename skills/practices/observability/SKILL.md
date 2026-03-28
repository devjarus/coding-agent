---
name: observability
description: Logging, health checks, error tracking, and monitoring patterns for production applications. Use when scaffolding projects, implementing services, or reviewing production readiness.
---

# Observability

## When to Apply
- Scaffolder setting up a new project
- Backend specialists implementing services
- Infra specialists setting up deployment
- Reviewer checking production readiness

---

## Priority Rules

### CRITICAL

- **OBS-01: Health check endpoint** — every service exposes `GET /health` (or `/healthz`) returning `200` when ready, `503` when not. Used by load balancers, container orchestrators, and monitoring.
- **OBS-02: Structured logging** — JSON format with consistent fields: `timestamp`, `level`, `message`, `requestId`, `error` (with stack). Never `console.log` in production.
- **OBS-03: Error tracking** — uncaught exceptions and unhandled rejections are captured and reported (Sentry, Bugsnag, or equivalent). Include: stack trace, user context, request context.

### HIGH

- **OBS-04: Request logging** — every HTTP request logged with: `method`, `path`, `status`, `duration`, `requestId`. Use middleware, not per-route logging.
- **OBS-05: Correlation IDs** — generate a unique `requestId` for each request, propagate through all downstream calls and logs. Essential for debugging distributed issues.
- **OBS-06: Graceful shutdown** — handle `SIGTERM`: stop accepting new requests, drain in-flight requests (with timeout), close DB/Redis connections, then exit.

### MEDIUM

- **OBS-07: Startup logging** — log config (non-secret), connected services, listening port at startup. Makes deployment debugging much easier.
- **OBS-08: Dependency health** — health check should verify connectivity to critical dependencies (database, Redis, external APIs). Return degraded status if optional deps are down.
- **OBS-09: Metrics endpoint** — expose `/metrics` (Prometheus format) or equivalent for: request count, error rate, response time percentiles, active connections.

### LOW

- **OBS-10: Log levels** — use them correctly: `error` (action required), `warn` (unexpected but handled), `info` (state changes), `debug` (development only, never in prod).
- **OBS-11: Alerting rules** — define: error rate > 1% = warning, error rate > 5% = critical, p99 latency > 2s = warning, health check fail = critical.

---

## Patterns

### Health Check (Node.js)

`GET /health` checks DB and Redis connectivity, returns `{ status, checks: { database, redis }, uptime }`. Respond `200` when all critical deps are healthy, `503` when any critical dep is down. Include response time per dependency check to aid diagnosis.

```js
app.get('/health', async (req, res) => {
  const checks = {
    database: await checkDb(),   // { status: 'ok' | 'fail', latencyMs }
    redis:    await checkRedis(),
  };
  const allOk = Object.values(checks).every(c => c.status === 'ok');
  res.status(allOk ? 200 : 503).json({
    status: allOk ? 'ok' : 'degraded',
    checks,
    uptime: process.uptime(),
  });
});
```

### Structured Logger Setup

Configure pino (preferred) or winston to emit JSON, bind `requestId` per request via child logger, and read log level from `LOG_LEVEL` env var (default `info`).

```js
// logger.js
import pino from 'pino';
export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  base: { service: process.env.SERVICE_NAME },
});

// middleware — bind requestId to every log in the request lifecycle
app.use((req, _res, next) => {
  req.log = logger.child({ requestId: req.headers['x-request-id'] ?? crypto.randomUUID() });
  next();
});
```

### Graceful Shutdown

On `SIGTERM`, stop the HTTP server from accepting new connections, wait for in-flight requests to finish (bounded by a timeout), then close DB/cache connections before exiting.

```js
process.on('SIGTERM', async () => {
  logger.info('SIGTERM received — shutting down');
  server.close(async () => {
    await db.end();
    await redis.quit();
    logger.info('Shutdown complete');
    process.exit(0);
  });
  // Force-exit if drain takes too long
  setTimeout(() => { logger.error('Shutdown timeout — forcing exit'); process.exit(1); }, 10_000);
});
```

---

## What the Scaffolder Should Set Up

- Health check endpoint (at minimum `GET /health`)
- Structured logger configured (pino/winston, JSON output)
- Graceful shutdown handler (`SIGTERM`)
- `.env` variable for `LOG_LEVEL` (default `info`)
