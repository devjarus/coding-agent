<!-- Single source of truth: the HUMAN-FACING deploy & CI/CD PROCEDURE (platform, release flow, where CI lives, rollback). Holds procedure, NOT values: no secrets, no env-var values, no per-deploy history, no per-env runtime state — those live outside version control. The only committed doc that describes the deploy process. -->

# Deployment

> How this project ships. Local build/test: [AGENTS.md](AGENTS.md). System topology: [docs/architecture.md](docs/architecture.md).

## Deploy Targets / Platform

<where it runs (the hosting platform/service), and the environments (e.g. staging, production).>

## Release Flow / CI-CD

<the steps from merge to live. The pipeline definition lives in `.github/workflows/` (or equivalent) — point to it, don't restate the YAML.>

```
<ASCII: commit → CI (lint/test/build) → artifact → deploy → verify>
```

## Rollback

<how to revert a bad deploy, and how to tell it worked.>

## Runtime configuration

Environment-variable **names** and per-environment runtime state are managed by your deployment platform / secret store, **not committed here**. This doc describes the *procedure*; it never holds secrets or values.
