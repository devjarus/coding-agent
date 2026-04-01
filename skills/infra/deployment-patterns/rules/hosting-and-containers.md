# Hosting Strategy & Containerization

## DEP-01: Hosting Strategy Selection (CRITICAL)

Choose based on the workload, not the trend:

| Strategy | Best For | Tradeoffs | Examples |
|----------|----------|-----------|---------|
| **Serverless functions** | Event-driven, bursty traffic, simple APIs | Cold starts, 15-min timeout, no persistent connections | AWS Lambda, Vercel Functions, Cloudflare Workers |
| **Serverless containers** | APIs, web apps that need more control | Still cold starts, but longer timeouts | AWS Fargate, Google Cloud Run, Azure Container Apps |
| **Container orchestration** | Complex multi-service systems, high traffic | Operational overhead, requires K8s knowledge | ECS, EKS, GKE, self-hosted K8s |
| **PaaS** | Quick deploys, small teams, MVPs | Less control, potential vendor lock-in | Railway, Render, Fly.io, Heroku |
| **Edge** | Static sites, low-latency global delivery | Limited compute, no persistent state | Cloudflare Pages, Vercel Edge, Netlify |
| **VMs** | Legacy apps, GPU workloads, full OS control | Manual scaling, patching, security | EC2, GCE, Azure VMs, DigitalOcean Droplets |

**Decision framework:**
```
Is it a static site or SPA?
+-- YES -> Edge (Cloudflare Pages, Vercel, Netlify)
+-- NO -> Does it need WebSockets or long-running connections?
    +-- YES -> Containers (Cloud Run, Fargate, Railway)
    +-- NO -> Is traffic bursty with idle periods?
        +-- YES -> Serverless (Lambda, Vercel Functions)
        +-- NO -> Is it a complex multi-service system?
            +-- YES -> Container orchestration (ECS/EKS, GKE)
            +-- NO -> PaaS (Railway, Render, Fly.io)
```

## DEP-02: Containerization (CRITICAL)

Every deployable service should have a Dockerfile. Apply the docker-specialist and docker-best-practices skills for the Dockerfile itself.

**Multi-stage build for production:**
```dockerfile
# Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production
FROM node:20-alpine
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=builder --chown=app:app /app/dist ./dist
COPY --from=builder --chown=app:app /app/node_modules ./node_modules
USER app
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "dist/server.js"]
```

**Container registry flow:**
```
Build -> Tag -> Push -> Deploy
docker build -t myapp:$(git rev-parse --short HEAD) .
docker tag myapp:abc123 registry.example.com/myapp:abc123
docker push registry.example.com/myapp:abc123
```

**Registry options:** Docker Hub, GitHub Container Registry (ghcr.io), AWS ECR, Google Artifact Registry, Azure ACR. Use the one matching your cloud provider.

## DEP-03: Environment Management (CRITICAL)

**Three environments minimum:** dev, staging, production. Same image artifact flows through all three -- only configuration changes.

**Environment config pattern:**
```
.env.example          # Committed -- documents all variables, no real values
.env.development      # Local dev -- gitignored
.env.staging          # Staging -- in secrets manager, NOT in git
.env.production       # Production -- in secrets manager, NOT in git
```

**Rules:**
- Never commit real secrets. `.env` files with real values are gitignored.
- `.env.example` documents every variable with a placeholder and description.
- Production secrets live in a secrets manager (AWS Secrets Manager, Vault, Doppler, Infisical), not in CI/CD env vars.
- Environment parity: dev/staging/prod differ only in scale and secrets, not in architecture.

**Feature flags** for progressive rollout:
```typescript
// Simple: environment variable
const ENABLE_NEW_CHECKOUT = process.env.FEATURE_NEW_CHECKOUT === "true";

// Better: feature flag service (LaunchDarkly, Unleash, Flagsmith)
const flags = await flagService.getFlags(userId);
if (flags.newCheckout) { ... }
```
