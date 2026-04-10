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
7. **Logs are separate from outputs.** `logs/` directory (gitignored) is for debug telemetry. `reports/`, `output/`, `dist/` are for application products. Never write logs to the output directory. CLIs write logs to stderr and results to stdout so piping works.
8. **Emit a self-diagnosis startup log.** One `info` entry on startup with runtime version, platform, cwd, log file path, env-var presence (as booleans, never values), and upstream service URLs. Makes "works on my machine" bugs obvious from the first line of the log.

## CLI Logging Gotchas

CLI tools have a unique constraint: the process exits quickly. Async file writers that buffer logs in memory will lose those logs when `process.exit()` is called before the flush completes. This is a real bug, not a theoretical one.

**Pattern for Node.js CLIs with pino:**

```typescript
// WRONG — async file stream, logs lost on exit
const dest = pino.destination({ dest: logFile, sync: false });
// Crash on exit: "sonic boom is not ready yet"
// Symptom: log file is 0 bytes

// RIGHT — sync file stream for CLIs
const dest = pino.destination({ dest: logFile, sync: true });
// For a CLI that runs one query and exits, the sync overhead is negligible
// (hundreds of log lines, not millions). Async requires explicit flush
// handlers at every exit point, which is error-prone.
```

For **long-running servers**, prefer `sync: false` — the async path is faster and the process stays alive long enough for flushes to complete. Install a graceful shutdown handler that calls `logger.flush()` before exit.

Equivalent gotchas in other runtimes:
- **Python stdlib logging:** call `logging.shutdown()` in an `atexit` hook, or use `structlog` with a stream handler.
- **Go slog:** the stdlib handler writes synchronously to `os.Stderr` by default — no flush needed. Custom async handlers need their own flush on shutdown.
- **Java Logback:** use `addShutdownHook="true"` in the configuration, or call `((LoggerContext) LoggerFactory.getILoggerFactory()).stop()` in a shutdown hook.

## Null Object Pattern for Optional Loggers

Libraries, tools, and services often accept an optional logger parameter so callers can wire one in without forcing the dependency on everyone. The idiomatic fallback is a real-but-silent logger instance, not `null` or `undefined` checks at every call site.

**Node.js / pino** — use the built-in silent level:

```typescript
// src/utils/logger.ts
import pino from "pino";
export type Logger = pino.Logger;

// Standard Null Object pattern — a real pino instance that discards everything.
// Supports .child(), serializers, etc. without any runtime branching.
export const silentLogger: Logger = pino({ level: "silent" });
```

```typescript
// src/tools/web-search.ts
import { silentLogger } from "../utils/logger.js";
import type { Logger } from "../utils/logger.js";

export function createWebSearch(parentLogger?: Logger) {
  const log = parentLogger?.child({ tool: "web_search" }) ?? silentLogger;
  // ...log is always a real logger; no `if (log)` branches anywhere
}
```

**Python / structlog:**

```python
import structlog
# structlog.get_logger() with no configuration is effectively a no-op
# until configured. For explicit silent fallback:
from structlog.testing import LogCapture
silent_logger = structlog.wrap_logger(None, processors=[])
```

**Go / slog:**

```go
// Use io.Discard for a silent handler
silentLogger := slog.New(slog.NewJSONHandler(io.Discard, nil))
```

Rules for the Null Object pattern:
- **Real logger instance**, not an ad-hoc `{ info: () => {} }` object. Real instances support `.child()`, serializers, and level checks without special-casing.
- **Centralized**, not duplicated. Export `silentLogger` from `utils/logger.ts` (or equivalent) and import it everywhere. Hand-rolled no-ops in every file is a code smell.
- **Preserves the type**. `silentLogger: Logger` means callers get full type safety without `| null` unions.

## Factory Pattern for Testable, Logger-Aware Components

Module-level singletons make logger injection awkward. Use factories that accept an optional logger and return the configured component. Keep a backward-compatible default export so existing imports don't break.

```typescript
// Factory — primary API
export function createWebSearch(parentLogger?: Logger) {
  const log = parentLogger?.child({ tool: "web_search" }) ?? silentLogger;
  return tool(
    async ({ query }) => {
      const start = performance.now();
      log.debug({ query }, "web_search started");
      try {
        const results = await fetch(/* ... */);
        const elapsed = Math.round(performance.now() - start);
        log.info({ query, resultCount: results.length, elapsed }, "web_search complete");
        return formatResults(results);
      } catch (err) {
        const elapsed = Math.round(performance.now() - start);
        log.error({ err, query, elapsed }, "web_search failed");
        return `Search failed: ${(err as Error).message}`;
      }
    },
    { name: "web_search", description: "...", schema }
  );
}

// Backward-compatible default — existing tests/imports keep working
export const web_search = createWebSearch();
```

Benefits:
- **Test isolation** — tests pass a mock logger, assert on log calls.
- **Per-component context** — child loggers automatically tag every entry with `{ tool: "web_search" }`, making filtering trivial.
- **Graceful fallback** — omit the logger entirely and it still works (uses silent).

## Self-Diagnosis Startup Log

Every app should emit exactly one startup log entry with the runtime and environment context. This turns "I don't know what's different on your machine" into a one-line grep.

```typescript
logger.info(
  {
    nodeVersion: process.version,
    platform: process.platform,
    arch: process.arch,
    cwd: process.cwd(),
    logFile,
    env: {
      // Presence booleans — NEVER log the values themselves
      hasAnthropicKey: Boolean(process.env.ANTHROPIC_API_KEY),
      hasOpenAIKey: Boolean(process.env.OPENAI_API_KEY),
      SEARXNG_URL: process.env.SEARXNG_URL ?? "http://localhost:8080",
    },
  },
  "App starting"
);
```

Log this **once**, at the very top of the logger factory so it's guaranteed to fire. Include:
- Runtime version (Node.js, Python, Go, JVM)
- Platform and architecture
- Working directory
- Log file path (so users know where to find detail)
- Package version (read from `package.json`, `pyproject.toml`, etc.)
- Presence of each required env var as a boolean
- Upstream service URLs (redact tokens — URL host and path only)

This single line answers "is my environment set up correctly" without interactive debugging.
