# Security & Build Optimization

## CRITICAL -- Security

- **DOC-01:** Non-root user with explicit UID/GID -- `addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup appuser`. Never run as root in production.
- **DOC-02:** No secrets in images -- never use `ENV` for secrets (visible in `docker history`). Use BuildKit secrets (`--mount=type=secret`) at build time, mounted secrets or env vars at runtime.
- **DOC-03:** Pin base image versions -- `node:20.11-alpine3.19`, not `node:latest`. Pin to patch level.
- **DOC-04:** Scan images in CI -- `docker scout quickview`, Trivy, or Snyk on every build. Block deploy on critical/high CVEs.

## CRITICAL -- Build Optimization

- **DOC-05:** Multi-stage builds -- separate deps, build, and runtime stages. Production image contains only compiled artifacts + runtime deps.
- **DOC-06:** Layer caching order -- copy dependency files (`package*.json`, `requirements.txt`, `go.sum`) BEFORE source code.
- **DOC-07:** Comprehensive .dockerignore -- exclude `.git`, `node_modules`, `dist`, `*.md`, `.env*`, test files.

## BuildKit Secrets (Build-Time)

```dockerfile
# syntax=docker/dockerfile:1
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN=$(cat /run/secrets/npm_token) \
    echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > .npmrc && \
    npm ci && \
    rm -f .npmrc
```

```bash
docker build --secret id=npm_token,src=./.npm_token .
```

## Cross-Platform Builds

```bash
docker buildx create --name multiarch --use
docker buildx build --platform linux/amd64,linux/arm64 -t myapp:latest --push .
```
