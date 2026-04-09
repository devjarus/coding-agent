---
name: observability
description: Structured logging for any application — language-specific logger setup, log levels, what to log at each layer, request tracing. Mandatory for all implementations. Evaluator checks for it.
---

# Observability & Logging

Logging is mandatory for every application, not optional. An app without logging is undebuggable in production. The evaluator checks for it, and missing logging is a finding.

## When to Apply

- **Every implementation** — set up logging in Wave 1 (foundation)
- **Every tool/service/endpoint** — log inputs, outputs, timing, errors
- **Every evaluator review** — check that logging exists and is structured

## Logger by Language

Pick the right logger. Always structured JSON, always configurable level, always request tracing.

| Language | Logger | Key Feature |
|----------|--------|-------------|
| **Node.js/TS** | pino + pino-http | Fast, JSON, child loggers, redact option |
| **Python** | structlog | Context binding, async-safe via contextvars |
| **Java** | SLF4J + Logback + logstash-logback-encoder | MDC for request tracing, Spring profile support |
| **Go** | log/slog (stdlib, 1.21+) | Structured, zero deps, JSON handler |
| **Swift/iOS** | os.Logger | Native, Instruments integration, Console.app filtering |
| **React Native** | react-native-logs + Sentry | Severity-based, namespaced, crash reporting |

For framework-specific patterns (Spring Boot, Next.js, Django, FastAPI, Express, Gin), see [rules/frameworks.md](rules/frameworks.md).

For cloud platform integration (AWS CloudWatch, GCP, Datadog, Vercel, OpenTelemetry), see [rules/cloud-platforms.md](rules/cloud-platforms.md).

## What to Log at Each Layer

### API / HTTP Layer
```
Every request:  method, path, status, duration, requestId
Errors:         stack trace, request context, user context
Startup:        port, config (non-secret), connected services
Shutdown:       reason, pending requests count
```

### Business Logic / Services
```
Operations:     what's happening, with what input (redact secrets)
Decisions:      branching logic that affects output
External calls: URL, status, duration, response size
Errors:         full context, not just message
```

### Data Layer
```
Queries:        operation type, table/collection, duration (NOT the data itself)
Migrations:     version applied, duration, success/failure
Connection:     pool stats, reconnects, failures
```

### Tools / Agents (LLM apps)
```
Tool calls:     name, params, result summary, duration
LLM calls:      model, token usage (prompt + completion), duration
Subagents:      which agent, what task, duration, result summary
Errors:         full context + what the agent was trying to do
```

## Log Levels — Use Them Correctly

| Level | When | Example |
|-------|------|---------|
| **error** | Requires immediate attention. Something failed and can't recover. | DB connection lost, unhandled exception, critical API down |
| **warn** | Unexpected but handled. Worth investigating later. | Rate limited, retrying, fallback used, deprecated API called |
| **info** | Key state changes. The "story" of what happened. | Request start/end, user action, deployment started, query completed |
| **debug** | Developer diagnostics. Noisy. Off in production. | Full request/response body, cache hit/miss, SQL queries, tool params |

**Rules:**
- Default level in production: `info` or `warn`
- Default level in development: `debug`
- Never log secrets, passwords, tokens, or full credit card numbers
- Always configurable via env var (`LOG_LEVEL`) or CLI flag (`--log-level`)

## Implementation Checklist

The implementor must set up logging in Wave 1 (foundation):

- [ ] Logger library installed and configured (structured JSON output)
- [ ] Log level configurable via environment variable or CLI flag
- [ ] Request/query tracing (unique ID carried through all logs for one request)
- [ ] API/HTTP layer: request logging middleware (method, path, status, duration)
- [ ] Error handling: all caught errors logged with context (not silently swallowed)
- [ ] Startup: log configuration, connected services, listening port
- [ ] CLI apps: logs go to stderr, output goes to stdout

## Evaluator Checklist

The evaluator checks for logging in every review:

- [ ] Structured logger exists and is used (not `console.log` / `print` / `println`)
- [ ] Log level is configurable
- [ ] Errors are logged with context (stack trace, what was happening)
- [ ] No silent error swallowing (every catch logs or propagates)
- [ ] API requests are logged (middleware, not per-route)
- [ ] No secrets in logs (grep for passwords, tokens, API keys in log statements)

## Rules

1. **Logging is set up in Wave 1.** Not added later as an afterthought.
2. **Structured JSON, not strings.** `logger.info({ userId, action })` not `console.log("user did thing")`
3. **Every error is logged.** No silent catch blocks. No `try?` without logging.
4. **Request tracing.** One ID per request/query, carried through all logs.
5. **Configurable level.** Always. Via env var or CLI flag.
6. **Secrets never logged.** Grep for it. Evaluator flags it.
