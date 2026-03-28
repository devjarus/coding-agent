---
name: ci-cd-patterns
description: CI/CD pipeline structure, principles, testing strategies, and deployment patterns. Use when designing, reviewing, or debugging pipelines.
---
# CI/CD Patterns

## Pipeline Structure
Every pipeline follows this ordered sequence:

```
install → lint → test → build → deploy
```

Each stage must pass before the next begins. Never skip a stage to speed up a deploy.

## Core Principles
- Run on **every push and every PR** — no exceptions
- A failing pipeline **blocks the merge**; the branch is not deployable until green
- **Cache dependencies** between runs (node_modules, pip cache, Go module cache) to minimize install time
- **Parallelize independent jobs** — lint and unit tests can run at the same time; they do not need to be sequential
- Target a total pipeline duration of **under 10 minutes** for developer feedback loop

## Testing in CI
- Use **exactly the same test commands** as developers run locally — no special CI-only flags
- Spin up real **service containers** (databases, queues) rather than in-process mocks for integration tests
- Use **fail-fast** mode: stop the test run on the first failure to surface signal quickly
- Store test reports and coverage artifacts for later inspection

```yaml
# Example: GitHub Actions service container
services:
  postgres:
    image: postgres:16-alpine
    env:
      POSTGRES_PASSWORD: test
    options: >-
      --health-cmd pg_isready
      --health-interval 10s
      --health-timeout 5s
      --health-retries 5
```

## Deployment
| Environment | Trigger | Approval |
|-------------|---------|----------|
| Staging | Automatic on merge to main | None |
| Production | Manual trigger or scheduled | Required |

- Use **blue/green** or **rolling** deployment strategies to avoid downtime
- Configure **automatic rollback** when the post-deploy health check fails
- Run **database migrations before** deploying new application code (migrations must be backward compatible with the old code version)
- Never deploy secrets via environment variables baked into the image — inject at runtime via a secrets manager or platform secret store

## Rollback
- Health checks must be defined and passing before traffic is switched
- Keep the previous deployment artifact tagged and ready to re-promote — do not rely on rebuilding
- Document the rollback command or button prominently so any team member can execute it under pressure
