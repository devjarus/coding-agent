---
name: docker-best-practices
description: Docker containerization expert — multi-stage builds, security hardening, Compose orchestration, image optimization, dev workflows, and production deployment. Use when writing, reviewing, or debugging Dockerfiles, docker-compose files, or container configurations.
---

# Docker Best Practices

## When to Apply

- Writing or reviewing Dockerfiles
- Setting up docker-compose for dev or production
- Optimizing image size or build speed
- Hardening container security
- Debugging container issues (networking, volumes, health checks)
- Setting up dev workflows with hot reload

## Priority Rules

### CRITICAL — Security

- DOC-01: **Non-root user with explicit UID/GID** — `addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup appuser`. Never run as root in production.
- DOC-02: **No secrets in images** — never use `ENV` for secrets (visible in `docker history`). Use BuildKit secrets (`--mount=type=secret`) at build time, mounted secrets or env vars at runtime.
- DOC-03: **Pin base image versions** — `node:20.11-alpine3.19`, not `node:latest`. Pin to patch level for reproducible builds.
- DOC-04: **Scan images in CI** — `docker scout quickview`, Trivy, or Snyk on every build. Block deploy on critical/high CVEs.

### CRITICAL — Build Optimization

- DOC-05: **Multi-stage builds** — separate deps, build, and runtime stages. Production image contains only compiled artifacts + runtime deps.
- DOC-06: **Layer caching order** — copy dependency files (`package*.json`, `requirements.txt`, `go.sum`) BEFORE source code. Deps change less often than source.
- DOC-07: **Comprehensive .dockerignore** — exclude `.git`, `node_modules`, `dist`, `*.md`, `.env*`, test files, docs. Smaller build context = faster builds.

### HIGH — Compose Orchestration

- DOC-08: **Health checks on every service** — `depends_on` with `condition: service_healthy`, not just `service_started`. Services must declare when they're actually ready.
- DOC-09: **Custom networks for isolation** — frontend services on a public bridge, backend services on an internal network. Don't expose databases to the host.
- DOC-10: **Resource limits** — set `deploy.resources.limits` for CPU and memory in production. Prevent runaway containers from killing the host.
- DOC-11: **Named volumes for persistence** — databases, uploads, and any state that must survive container restarts. Never use bind mounts for production data.

### HIGH — Image Size

- DOC-12: **Minimal base images** — Alpine (~5MB) or distroless (~20MB) for production. Full Debian only when you need specific system libraries.
- DOC-13: **Clean caches in same RUN layer** — `apt-get install -y pkg && rm -rf /var/lib/apt/lists/*` in one `RUN`. Separate layers preserve the cache.
- DOC-14: **Copy only artifacts** — `COPY --from=build /app/dist ./dist` — not the entire build stage. No test files, no dev configs, no source maps.

### MEDIUM — Dev Workflow

- DOC-15: **Separate dev and prod targets** — `target: development` in compose for dev, `target: production` for deploy. Dev gets volume mounts + debug ports.
- DOC-16: **Hot reload via volumes** — mount source with `- .:/app` and exclude deps with `- /app/node_modules`. Use `nodemon`, `watchpack`, or framework dev servers.
- DOC-17: **Debug port exposure** — `9229:9229` for Node.js inspector, only in dev compose.

### MEDIUM — Performance

- DOC-18: **BuildKit cache mounts** — `RUN --mount=type=cache,target=/root/.npm npm ci` preserves package cache across builds. Much faster rebuilds.
- DOC-19: **Parallel builds** — `docker buildx bake` or multi-stage parallelism for independent build steps.
- DOC-20: **Restart policies** — `restart: on-failure` with `max_attempts` and `delay`. Don't use `restart: always` — it masks underlying issues.

## Multi-Stage Build Template (Node.js)

```dockerfile
# Stage 1: Dependencies
FROM node:20.11-alpine3.19 AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --only=production && cp -R node_modules /prod_modules
RUN npm ci

# Stage 2: Build
FROM node:20.11-alpine3.19 AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# Stage 3: Production
FROM node:20.11-alpine3.19 AS production
WORKDIR /app

RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

COPY --from=deps --chown=appuser:appgroup /prod_modules ./node_modules
COPY --from=build --chown=appuser:appgroup /app/dist ./dist
COPY --from=build --chown=appuser:appgroup /app/package.json ./

USER appuser
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["node", "-e", "fetch('http://localhost:3000/health').then(r => r.ok ? process.exit(0) : process.exit(1)).catch(() => process.exit(1))"]

CMD ["node", "dist/index.js"]
```

## Multi-Stage Build Template (Python)

```dockerfile
FROM python:3.12-slim AS build
WORKDIR /app
RUN pip install --no-cache-dir uv
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev
COPY . .

FROM python:3.12-slim AS production
WORKDIR /app

RUN groupadd -g 1001 appgroup && \
    useradd -u 1001 -g appgroup -s /bin/false appuser

COPY --from=build --chown=appuser:appgroup /app /app

USER appuser
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]

CMD ["uv", "run", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## Production Compose Template

```yaml
services:
  app:
    build:
      context: .
      target: production
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    env_file: .env
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - frontend
      - backend
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 128M
    restart: on-failure

  db:
    image: postgres:16-alpine
    volumes:
      - db-data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    networks:
      - backend
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 1G

  redis:
    image: redis:7-alpine
    volumes:
      - redis-data:/data
    networks:
      - backend
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true

volumes:
  db-data:
  redis-data:

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

## Dev Compose Override

```yaml
# docker-compose.dev.yml — use with: docker compose -f docker-compose.yml -f docker-compose.dev.yml up
services:
  app:
    build:
      target: development
    volumes:
      - .:/app
      - /app/node_modules
    ports:
      - "3000:3000"
      - "9229:9229"
    environment:
      NODE_ENV: development
      DEBUG: "app:*"
    command: npx nodemon --inspect=0.0.0.0:9229
```

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

## Common Issue Diagnostics

| Issue | Symptoms | Fix |
|---|---|---|
| Slow builds | 10+ min, cache invalidated on every change | Reorder layers (deps before source), use BuildKit cache mounts |
| Large images | > 500MB, slow deploys | Multi-stage, Alpine/distroless, copy only artifacts |
| Security scan failures | CVEs in base image | Pin and update base image, use `-slim` or distroless |
| Container runs as root | `ps aux` shows PID 1 as root | Add `USER` directive, create user with explicit UID |
| Service not ready | App connects before DB is up | `depends_on` with `condition: service_healthy` |
| Hot reload not working | Changes not reflected | Check volume mounts, ensure `/app/node_modules` is excluded |
| Port conflicts | `bind: address already in use` | Check `docker ps`, stop conflicting containers |
| DNS resolution errors | Service can't reach another | Ensure both on same custom network, use service name as hostname |

## Code Review Checklist

- [ ] Multi-stage build separates build and runtime
- [ ] Base images pinned to specific version
- [ ] Non-root user with explicit UID/GID
- [ ] No secrets in ENV or image layers
- [ ] .dockerignore is comprehensive
- [ ] HEALTHCHECK defined
- [ ] Resource limits set for production
- [ ] Dependencies cached before source code
- [ ] Package manager caches cleaned in same RUN layer
- [ ] Dev and prod targets are separate
