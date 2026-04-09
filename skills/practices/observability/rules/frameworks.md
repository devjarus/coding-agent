# Framework-Specific Logging

Pick the right logger and pattern for the framework. Always structured JSON, always configurable level.

## Java / Spring Boot

**Logger:** SLF4J + Logback (Spring default) + `logstash-logback-encoder` for JSON

```java
// Request tracing via MDC
@Component
public class RequestTracingFilter extends OncePerRequestFilter {
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        try {
            MDC.put("traceId", Optional.ofNullable(req.getHeader("X-Request-ID"))
                .orElse(UUID.randomUUID().toString()));
            chain.doFilter(req, res);
        } finally {
            MDC.clear(); // MUST clear — threads are pooled
        }
    }
}
```

```yaml
# application.yml
logging:
  level:
    root: INFO
    com.yourcompany: DEBUG
    org.springframework: WARN
```

```xml
<!-- logback-spring.xml — use logback-SPRING.xml for profile support -->
<springProfile name="prod">
  <appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
    <encoder class="net.logstash.logback.encoder.LogstashEncoder"/>
  </appender>
</springProfile>
<springProfile name="dev">
  <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
    <encoder><pattern>%d{HH:mm:ss} [%X{traceId}] %-5level %logger{24} - %msg%n</pattern></encoder>
  </appender>
</springProfile>
```

**Key:** Always `MDC.clear()` in finally. Expose `/actuator/loggers` for runtime level changes. JSON in prod, readable in dev.

## Next.js

**Logger:** `pino` (server), `@sentry/nextjs` (client errors)

```typescript
// lib/logger.ts — server-side only
import pino from "pino";
export const logger = pino({
  level: process.env.LOG_LEVEL || "info",
  ...(process.env.NODE_ENV === "development" && { transport: { target: "pino-pretty" } }),
});
```

**Key:** Pino for server components/API routes. Sentry for client error boundaries. Configure Log Drain on Vercel (1h retention without it).

## Django

**Logger:** `django-structlog` + `structlog`

```python
# settings.py — RequestMiddleware MUST be first
MIDDLEWARE = ["django_structlog.middlewares.RequestMiddleware", ...]
```

**Key:** Use `structlog.contextvars` (not threadlocal) for async Django. Event-based logging: `logger.info("order_created", order_id=x)` not f-strings.

## FastAPI

**Logger:** `structlog` + custom middleware

```python
class LoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        structlog.contextvars.clear_contextvars()  # MUST clear per request
        structlog.contextvars.bind_contextvars(request_id=str(uuid.uuid4()))
        response = await call_next(request)
        return response
```

**Key:** `clear_contextvars()` at request start. Disable uvicorn access log if using middleware.

## Express

**Logger:** `pino-http` (structured, faster than morgan)

```typescript
import pinoHttp from "pino-http";
app.use(pinoHttp({
  logger,
  genReqId: (req) => req.headers["x-request-id"] || randomUUID(),
  redact: ["req.headers.authorization", "req.headers.cookie"],
}));
// Use req.log in handlers — it carries request context
```

**Key:** Use `req.log` not `logger` in route handlers. Use `redact` to strip auth headers.

## Go

**Logger:** `log/slog` (stdlib, Go 1.21+)

```go
logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
// Pass via context/middleware, not global
reqLogger := logger.With("requestId", requestID)
```

**Key:** Use `slog` for new Go 1.21+ projects. Pass logger via context, not global.

## Swift / iOS

**Logger:** `os.Logger` (native, Instruments integration)

```swift
let logger = Logger(subsystem: "com.app.name", category: "network")
logger.info("Request started: \(url)")
// Filter in Console.app by subsystem
```

**Key:** os.Logger is native — works with Instruments and Console.app. Use subsystem/category for filtering.

## React Native

**Logger:** `react-native-logs` + `@sentry/react-native`

```typescript
const log = logger.createLogger({ severity: __DEV__ ? "debug" : "warn" });
const authLog = log.extend("auth"); // namespaced
```

**Key:** Never console.log in production (tanks perf). Sentry for crashes, react-native-logs for structured events.

## CLI / Agent Applications

```typescript
// Logs to stderr (stdout reserved for output)
const logger = pino({
  level: verbose ? "debug" : "warn",
  transport: pretty ? { target: "pino-pretty", options: { destination: 2 } } : undefined,
});
const queryLog = logger.child({ queryId: crypto.randomUUID().slice(0, 8) });
```

**Key:** stderr for logs, stdout for output. Per-query child logger with unique ID.
