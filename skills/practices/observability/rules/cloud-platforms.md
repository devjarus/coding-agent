# Cloud Platform Logging

## AWS CloudWatch

**Structured JSON is required.** CloudWatch Logs Insights can only query JSON fields.

```json
{
  "timestamp": "2026-04-05T10:15:30.123Z",
  "level": "ERROR",
  "message": "Payment failed",
  "service": "payment-api",
  "request_id": "abc-123",
  "duration_ms": 245
}
```

Query with Insights:
```sql
fields @timestamp, level, message, request_id
| filter level = "ERROR"
| sort @timestamp desc
```

**Embedded Metric Format (EMF)** — metrics from logs, no API calls:
```typescript
import { createMetricsLogger, Unit } from "aws-embedded-metrics";
const metrics = createMetricsLogger();
metrics.putMetric("PaymentDuration", durationMs, Unit.Milliseconds);
await metrics.flush();
```

**Rules:**
- Log group naming: `/application/{env}/{service}`
- Set retention: 30 days prod, 7 days dev (default "never expire" accumulates cost)
- Use EMF for custom metrics instead of PutMetricData API (free vs per-call)
- Metric filters for alarms: `{ $.level = "ERROR" }` → SNS alert

## AWS X-Ray

```typescript
import AWSXRay from "aws-xray-sdk";
app.use(AWSXRay.express.openSegment("payment-api"));
// Auto-instrument AWS SDK + HTTP:
AWSXRay.captureAWS(require("aws-sdk"));
AWSXRay.captureHTTPsGlobal(require("http"));
```

**Rules:**
- Annotations (indexed, searchable) for fields you filter on. Metadata for everything else.
- Prefer OpenTelemetry + X-Ray exporter for new projects (vendor-neutral).

## Google Cloud Logging

**Just write JSON to stdout** on Cloud Run/GKE — the agent picks it up.

```json
{
  "severity": "ERROR",
  "message": "Payment failed",
  "logging.googleapis.com/trace": "projects/my-project/traces/abc123"
}
```

**Rules:**
- Use `severity` not `level` (GCP only recognizes `severity`)
- Include `logging.googleapis.com/trace` to link logs to Cloud Trace
- Don't use the Cloud Logging client library in containers — stdout is sufficient

## Datadog

```typescript
import tracer from "dd-trace"; // MUST be first import
tracer.init({ service: "payment-api", logInjection: true });
```

**Rules:**
- `dd-trace` MUST be first import (monkey-patches HTTP/DB clients)
- `logInjection: true` adds `dd.trace_id`/`dd.span_id` to logs for APM correlation
- Unified service tagging: `service`, `env`, `version` on everything

## Vercel

- Runtime logs appear automatically from console.log/pino
- **Configure Log Drain** on day one (1h retention on Pro without it)
- JSON logging (pino) so the drain destination can parse fields
- Don't log in edge middleware hot paths (CPU limits)

## OpenTelemetry (Vendor-Neutral)

When you need to switch backends or export to multiple:

```typescript
// Node.js — load before any other import
import { NodeSDK } from "@opentelemetry/sdk-node";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({ url: "http://otel-collector:4318/v1/traces" }),
  instrumentations: [getNodeAutoInstrumentations()],
});
sdk.start();
```

Java: just add the agent JAR — zero code changes:
```bash
java -javaagent:opentelemetry-javaagent.jar -Dotel.service.name=payment-api -jar app.jar
```

**Rules:**
- Use OTel Collector as middleware between app and backend (decouples vendor)
- Auto-instrumentation first, manual spans only for business logic
- Always `span.end()` — unclosed spans leak memory

## Decision Matrix

| Scenario | Logger | Tracing | Metrics |
|----------|--------|---------|---------|
| AWS-native | pino/logback → CloudWatch | X-Ray or OTel+X-Ray exporter | EMF or CloudWatch agent |
| GCP-native | JSON to stdout | Cloud Trace | Cloud Monitoring |
| Datadog | pino/structlog + dd-trace | dd-trace APM | dd-trace custom metrics |
| Vercel/Next.js | pino + Log Drain | Sentry or OTel | Vercel Analytics |
| Vendor-neutral | pino/structlog/slog | OpenTelemetry | OpenTelemetry |
| Spring Boot | logstash-logback-encoder | OTel Java agent or Spring Cloud Sleuth | Micrometer + Prometheus |
