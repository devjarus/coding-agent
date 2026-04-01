# Compose Orchestration & Build Templates

## HIGH -- Compose Orchestration

- **DOC-08:** Health checks on every service -- `depends_on` with `condition: service_healthy`
- **DOC-09:** Custom networks for isolation -- frontend on public bridge, backend on internal
- **DOC-10:** Resource limits -- set `deploy.resources.limits` for CPU and memory
- **DOC-11:** Named volumes for persistence -- databases, uploads, stateful data

## HIGH -- Image Size

- **DOC-12:** Minimal base images -- Alpine (~5MB) or distroless (~20MB) for production
- **DOC-13:** Clean caches in same RUN layer -- `apt-get install && rm -rf /var/lib/apt/lists/*`
- **DOC-14:** Copy only artifacts -- `COPY --from=build /app/dist ./dist`

## MEDIUM -- Dev Workflow

- **DOC-15:** Separate dev and prod targets -- `target: development` in compose for dev
- **DOC-16:** Hot reload via volumes -- mount source, exclude deps
- **DOC-17:** Debug port exposure -- `9229:9229` for Node.js inspector, dev only

## MEDIUM -- Performance

- **DOC-18:** BuildKit cache mounts -- `RUN --mount=type=cache,target=/root/.npm npm ci`
- **DOC-19:** Parallel builds -- `docker buildx bake`
- **DOC-20:** Restart policies -- `restart: on-failure` with `max_attempts`

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
RUN addgroup -g 1001 -S appgroup && adduser -u 1001 -S appuser -G appgroup
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
RUN groupadd -g 1001 appgroup && useradd -u 1001 -g appgroup -s /bin/false appuser
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
# docker-compose.dev.yml
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
