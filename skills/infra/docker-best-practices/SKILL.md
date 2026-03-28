---
name: docker-best-practices
description: Docker best practices for Dockerfiles, image size, security, and Compose configuration. Use when writing or reviewing Dockerfiles and docker-compose files.
---
# Docker Best Practices

## Dockerfile

### Structure
- Use **multi-stage builds** to keep the final image lean
- **Pin base image versions**: `node:20.11-alpine3.19`, not `node:latest`
- Run as a **non-root user**: create and switch to a dedicated app user
- Order layers for **cache efficiency**: copy dependency manifests first, install deps, then copy source
- Keep a **`.dockerignore`** that excludes `node_modules`, `.git`, build artifacts, and secrets
- One process per container — use a process supervisor only when truly necessary

```dockerfile
# Example multi-stage Node build
FROM node:20.11-alpine3.19 AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20.11-alpine3.19 AS runner
WORKDIR /app
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=deps /app/node_modules ./node_modules
COPY . .
USER appuser
EXPOSE 3000
CMD ["node", "server.js"]
```

## Image Size
- Prefer `alpine` or `-slim` variants of base images
- Clean package manager caches in the **same `RUN` layer**: `apt-get install ... && rm -rf /var/lib/apt/lists/*`
- Copy only what the application needs — not test files, docs, or dev configs
- Use `COPY --from=build` to bring only compiled artifacts into the final stage

## Security
- **Never bake secrets** into images — use runtime environment variables, mounted secrets, or a secrets manager
- **Scan images** for vulnerabilities in CI (e.g., `docker scout`, Trivy, Snyk)
- Mount the root filesystem **read-only** where possible: `--read-only` with tmpfs for writable paths
- Set **resource limits** in production: memory (`--memory`) and CPU (`--cpus`)

## Docker Compose
- Use **profiles** to make optional services (e.g., a mail catcher, monitoring) opt-in
- Add **health checks** to every service so dependents know when it is ready
- Use **`depends_on` with `condition: service_healthy`**, not just `service_started`
- Use **named volumes** for any data that must survive container restarts (databases, uploads)

```yaml
services:
  db:
    image: postgres:16-alpine
    volumes:
      - db-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  api:
    build: .
    depends_on:
      db:
        condition: service_healthy

volumes:
  db-data:
```
