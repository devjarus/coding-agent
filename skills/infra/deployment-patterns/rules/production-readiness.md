# Production Readiness & Rollback

## DEP-06: Production Readiness Checklist (HIGH)

Before going live, verify:

**Infrastructure:**
- [ ] Health check endpoint exists and returns meaningful status
- [ ] Graceful shutdown handles SIGTERM (drain connections, close DB pools)
- [ ] Resource limits set (CPU, memory) -- no unbounded consumption
- [ ] Auto-scaling configured based on CPU/memory/request count
- [ ] Logging is structured JSON with request IDs (not `console.log`)

**Reliability:**
- [ ] Database has automated backups with tested restore procedure
- [ ] Retry logic with exponential backoff for external API calls
- [ ] Circuit breaker for dependencies that might go down
- [ ] Timeouts set on all outbound HTTP calls
- [ ] Error tracking configured (Sentry, Datadog, Bugsnag)

**Security:**
- [ ] HTTPS enforced -- HTTP redirects to HTTPS
- [ ] Security headers set (HSTS, CSP, X-Frame-Options, X-Content-Type-Options)
- [ ] No debug mode, no stack traces in production error responses
- [ ] Secrets rotated from any development/staging values
- [ ] Dependency audit passes with no critical vulnerabilities

**Observability:**
- [ ] Metrics dashboard exists (request rate, error rate, latency p50/p95/p99)
- [ ] Alerting configured for error rate spikes and latency degradation
- [ ] Log aggregation configured (CloudWatch, Datadog, Grafana/Loki)
- [ ] Tracing enabled for distributed systems (OpenTelemetry, Datadog APM)

## DEP-07: Rollback Strategy (MEDIUM)

**Always have a rollback plan before deploying:**

```bash
# Container rollback -- redeploy previous image
docker pull registry/myapp:previous-sha
deploy.sh previous-sha

# Database rollback -- run down migration
npm run migrate:down  # or equivalent

# Feature flag rollback -- disable the flag
flag-service disable new-checkout
```

**Rollback order matters:**
1. Disable feature flags first (instant, no deploy needed)
2. Rollback application code (redeploy previous container)
3. Rollback database only if absolutely necessary (risky -- data may have been written)
