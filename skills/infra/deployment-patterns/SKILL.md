---
name: deployment-patterns
description: Cloud-agnostic deployment patterns — containerization, hosting selection, env management, CI/CD, zero-downtime deploys, production readiness. Applies to any cloud or self-hosted infra.
---

# Deployment Patterns

## When to Apply

- Deploying an application for the first time
- Choosing a hosting strategy (serverless, containers, VMs, edge)
- Setting up CI/CD pipelines
- Managing multiple environments (dev, staging, production)
- Implementing zero-downtime deployments
- Preparing an application for production

## Rules

### CRITICAL (rules/hosting-and-containers.md)

- **DEP-01:** Hosting strategy selection -- choose based on workload (serverless, containers, PaaS, edge, VMs)
- **DEP-02:** Containerize every deployable service with multi-stage Dockerfiles
- **DEP-03:** Three environments minimum (dev, staging, prod); same image artifact, different config only

### HIGH (rules/cicd-and-deploys.md)

- **DEP-04:** CI/CD pipeline: Push -> Lint -> Test -> Build -> Scan -> Deploy Staging -> Smoke -> Deploy Prod
- **DEP-05:** Zero-downtime deploys via rolling update, blue-green, or canary strategies

### HIGH (rules/production-readiness.md)

- **DEP-06:** Production readiness checklist -- health checks, graceful shutdown, resource limits, structured logging, backups, security headers, alerting
- **DEP-07:** Rollback strategy -- feature flags first, then code, then database (last resort)

## Anti-Patterns

- "Works on my machine" deploys -- no Dockerfile, no CI, manual `scp` to servers
- Snowflake servers -- configured manually, not reproducible; use IaC
- Secrets in git -- even in private repos; use a secrets manager
- No health checks -- platform cannot tell if app is alive or dead
- Big bang deploys -- all traffic switches at once with no canary or staged rollout
- Coupled database + code deploys -- separate schema changes from code changes
- No rollback plan -- "we'll fix forward" works until it doesn't

## Priority Summary

| ID | Rule | Priority |
|----|------|----------|
| DEP-01 | Hosting strategy selection | CRITICAL |
| DEP-02 | Containerization | CRITICAL |
| DEP-03 | Environment management | CRITICAL |
| DEP-04 | CI/CD pipeline | HIGH |
| DEP-05 | Zero-downtime deployments | HIGH |
| DEP-06 | Production readiness checklist | HIGH |
| DEP-07 | Rollback strategy | MEDIUM |
