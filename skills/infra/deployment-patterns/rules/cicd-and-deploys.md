# CI/CD & Zero-Downtime Deployments

## DEP-04: CI/CD Pipeline (HIGH)

**Pipeline stages:**
```
Push -> Lint -> Test -> Build -> Security Scan -> Deploy Staging -> Smoke Test -> Deploy Production
```

**GitHub Actions example:**
```yaml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npm run lint
      - run: npm test
      - run: npm run build

  deploy-staging:
    needs: test
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t myapp:${{ github.sha }} .
      - run: docker push $REGISTRY/myapp:${{ github.sha }}
      - run: deploy-to-staging.sh ${{ github.sha }}

  smoke-test:
    needs: deploy-staging
    runs-on: ubuntu-latest
    steps:
      - run: curl -f https://staging.myapp.com/health

  deploy-production:
    needs: smoke-test
    runs-on: ubuntu-latest
    environment: production  # requires manual approval in GitHub
    steps:
      - run: deploy-to-production.sh ${{ github.sha }}
```

**Key principles:**
- Same artifact (Docker image) deploys to all environments. Build once, deploy many.
- Staging deploy is automatic after tests pass. Production requires approval.
- Smoke test staging before promoting to production.
- Pin action versions (`@v4` not `@main`).
- Store secrets in GitHub Environments, not in workflow files.

## DEP-05: Zero-Downtime Deployments (HIGH)

**Rolling update** (default for most platforms):
- New containers start alongside old ones
- Health checks pass -> traffic shifts to new containers
- Old containers drain and terminate
- Requires health check endpoint (`/health` or `/ready`)

**Blue-green deployment:**
```
Production (blue) <- traffic
Staging (green) <- deploy new version here
  | smoke test passes
Switch: green <- traffic, blue <- standby
  | if problems
Rollback: blue <- traffic (instant)
```

**Canary deployment:**
```
100% traffic -> v1
  | deploy v2
95% -> v1, 5% -> v2 (canary)
  | monitor metrics (error rate, latency, 5xx)
  | if metrics OK, increase
70% -> v1, 30% -> v2
  | continue
0% -> v1, 100% -> v2
```

**Database migrations + zero-downtime:**
Apply the migration-safety skill. Key rule: schema changes must be backward-compatible.

```
Phase 1: Deploy migration (additive only -- new columns nullable, new tables)
Phase 2: Deploy new code (reads/writes new columns)
Phase 3: Backfill old data
Phase 4: Add constraints (NOT NULL, remove old columns) -- separate deploy
```
