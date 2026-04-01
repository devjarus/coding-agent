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

## Rules

### CRITICAL -- Security & Build (rules/security-and-optimization.md)

- **DOC-01:** Non-root user with explicit UID/GID
- **DOC-02:** No secrets in images; use BuildKit secrets
- **DOC-03:** Pin base image versions to patch level
- **DOC-04:** Scan images in CI; block deploy on critical CVEs
- **DOC-05:** Multi-stage builds separating deps, build, and runtime
- **DOC-06:** Layer caching order -- deps before source code
- **DOC-07:** Comprehensive .dockerignore

### HIGH -- Compose & Image Size (rules/compose-and-templates.md)

- **DOC-08:** Health checks on every service with `condition: service_healthy`
- **DOC-09:** Custom networks for isolation
- **DOC-10:** Resource limits for CPU and memory
- **DOC-11:** Named volumes for persistence
- **DOC-12:** Minimal base images (Alpine or distroless)
- **DOC-13:** Clean caches in same RUN layer
- **DOC-14:** Copy only artifacts to production stage

### MEDIUM -- Dev & Performance (rules/compose-and-templates.md)

- **DOC-15:** Separate dev and prod compose targets
- **DOC-16:** Hot reload via volume mounts (exclude node_modules)
- **DOC-17:** Debug port exposure in dev only
- **DOC-18:** BuildKit cache mounts for faster rebuilds
- **DOC-19:** Parallel builds with `docker buildx bake`
- **DOC-20:** Restart policies with max_attempts

## Anti-Patterns

- Running as root in production
- Secrets in ENV or image layers (use BuildKit secrets)
- Unpinned base images (`node:latest`)
- No .dockerignore (slow builds, large context)
- No health checks (platform cannot detect unhealthy containers)
- `restart: always` masking underlying issues
- Bind mounts for production data (use named volumes)
