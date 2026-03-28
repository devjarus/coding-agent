---
name: config-management
description: Centralized configuration patterns — single config module, validated at startup, typed, with environment-aware defaults. Use when scaffolding projects, reviewing config, or fixing hardcoded values.
---

# Config Management

## When to Apply

- Scaffolding a new project (Scaffolder agent)
- Reviewing code that accesses environment variables directly
- Fixing hardcoded values (URLs, ports, secrets, feature flags)
- Setting up environment-specific configuration (dev/staging/prod)
- Any specialist writing code that needs config values

## The Core Rule

**`process.env` / `os.environ` is accessed in exactly ONE file — the config module. Everything else imports from it.**

This single rule eliminates scattered config, unvalidated access, typos in env var names, and silent fallback bugs.

## Priority Rules

### CRITICAL

- CFG-01: **Single config module** — one file reads env vars, exports a typed frozen object. Nothing else touches `process.env`.
- CFG-02: **Validate at startup** — use Zod (TS), Pydantic (Python), or envconfig (Go). If validation fails, `process.exit(1)` with field-level errors. Never run with bad config.
- CFG-03: **No secrets in code or config files** — secrets come from env vars, never hardcoded. `.env` with real secrets is gitignored. `.env.example` is committed.
- CFG-04: **No silent defaults for required values** — `process.env.JWT_SECRET || 'secret'` is a production incident waiting to happen. Required config must fail loudly if missing.

### HIGH

- CFG-05: **Typed config object** — not raw strings. Ports are numbers, booleans are booleans, URLs are validated URLs. Prevents `"undefined"` string bugs.
- CFG-06: **Separate server and client config** — in Next.js, `NEXT_PUBLIC_` vars go in `lib/config/client.ts`, server secrets in `lib/config/server.ts`. Never import server config in client components.
- CFG-07: **.env.example is documentation** — every env var the app needs is listed with a description and safe default. Keep it in sync.
- CFG-08: **Derive flags from env once** — instead of `if (process.env.NODE_ENV === 'production')` scattered in 15 files, set `config.isProduction` and `config.features.detailedErrors` in the config module.

### MEDIUM

- CFG-09: **Config vs constants** — config changes between environments (URLs, ports, secrets). Constants don't (max retries, pagination defaults). Don't put constants in env vars.
- CFG-10: **Group config by domain** — `config.database.url`, `config.auth.jwtSecret`, `config.features.beta` — not a flat object with 40 fields.
- CFG-11: **Freeze the config object** — `Object.freeze()` or equivalent. Config is read at startup and never mutated.
- CFG-12: **Lint against direct env access** — use ESLint `no-process-env` rule or equivalent to enforce the single config module pattern.

### LOW

- CFG-13: **Don't overengineer** — a startup with < 5 services doesn't need Consul, config servers, or 6-level YAML inheritance. `.env` + typed config module + secrets manager is enough.
- CFG-14: **Monorepo: shared schemas, separate .env** — share validation schemas across services, but each service has its own `.env.example` and config module.

## What the Scaffolder Must Create

For every new project:

```
.env.example           # All vars documented, safe defaults, no real secrets
.env                   # Local dev defaults (gitignored if contains secrets)
.gitignore             # Includes: .env.local, .env.production, .env.*.local
src/config/
  index.ts             # Singleton config loader — the ONLY file that reads process.env
  schema.ts            # Zod/Pydantic schema with types, defaults, validation
```

## Patterns by Framework

### Node.js / TypeScript (Zod)

```typescript
// src/config/schema.ts
import { z } from 'zod';

export const configSchema = z.object({
  env: z.enum(['development', 'staging', 'production', 'test']),
  server: z.object({
    port: z.coerce.number().int().min(1024).max(65535).default(3000),
    host: z.string().default('0.0.0.0'),
  }),
  database: z.object({
    url: z.string().url(),
    poolMax: z.coerce.number().int().default(10),
  }),
  auth: z.object({
    jwtSecret: z.string().min(32),
    jwtExpirySeconds: z.coerce.number().default(86400),
  }),
});

export type Config = z.infer<typeof configSchema>;
```

```typescript
// src/config/index.ts
import 'dotenv/config';
import { configSchema } from './schema';

const result = configSchema.safeParse({
  env: process.env.NODE_ENV,
  server: { port: process.env.PORT, host: process.env.HOST },
  database: { url: process.env.DATABASE_URL, poolMax: process.env.DB_POOL_MAX },
  auth: { jwtSecret: process.env.JWT_SECRET, jwtExpirySeconds: process.env.JWT_EXPIRY },
});

if (!result.success) {
  console.error('Config validation failed:');
  result.error.issues.forEach((i) => console.error(`  ${i.path.join('.')}: ${i.message}`));
  process.exit(1);
}

export const config = Object.freeze(result.data);
```

### Python / FastAPI (Pydantic)

```python
# config/settings.py
from functools import lru_cache
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file='.env', env_nested_delimiter='__')

    env: str = 'development'
    server_port: int = Field(default=8000, ge=1024, le=65535)
    database_url: str
    jwt_secret: str = Field(min_length=32)

@lru_cache
def get_settings() -> Settings:
    return Settings()
```

### Go (envconfig)

```go
// config/config.go
package config

import (
    "log"
    "github.com/kelseyhightower/envconfig"
)

type Config struct {
    Env        string `envconfig:"NODE_ENV" default:"development"`
    Port       int    `envconfig:"PORT" default:"8080"`
    DatabaseURL string `envconfig:"DATABASE_URL" required:"true"`
    JWTSecret  string `envconfig:"JWT_SECRET" required:"true"`
}

func Load() *Config {
    cfg := &Config{}
    if err := envconfig.Process("", cfg); err != nil {
        log.Fatalf("config: %v", err)
    }
    return cfg
}
```

### Next.js (separate server/client)

```typescript
// lib/config/server.ts — NEVER import in client components
import { z } from 'zod';
export const serverConfig = z.object({
  databaseUrl: z.string().url(),
  jwtSecret: z.string().min(32),
}).parse({
  databaseUrl: process.env.DATABASE_URL,
  jwtSecret: process.env.JWT_SECRET,
});
```

```typescript
// lib/config/client.ts — safe for browser
import { z } from 'zod';
export const clientConfig = z.object({
  apiUrl: z.string().url(),
  appEnv: z.enum(['development', 'staging', 'production']),
}).parse({
  apiUrl: process.env.NEXT_PUBLIC_API_URL,
  appEnv: process.env.NEXT_PUBLIC_APP_ENV,
});
```

## Environment Strategy

| Environment | Config delivery | Secrets |
|---|---|---|
| Local dev | `.env` file + docker-compose for services | Fake/test values |
| CI/CD | CI platform env vars (GitHub Actions secrets) | CI secrets store |
| Staging | Deployment platform env vars | Secrets manager |
| Production | Secrets manager → injected at deploy time | AWS SSM/Secrets Manager, GCP Secret Manager, Vault |

## Anti-Patterns

| Anti-Pattern | Why It's Bad | Fix |
|---|---|---|
| `process.env.X` in 40 files | Scattered, unvalidated, impossible to audit | Single config module |
| `process.env.X \|\| 'default'` | Silent failure with wrong value | Zod schema with explicit defaults or required |
| Secrets in committed files | Security breach | `.env.example` committed, `.env` gitignored |
| `if (NODE_ENV === 'production')` everywhere | Scattered environment logic | Derive semantic flags in config module |
| YAML config inheritance chains | Overengineered, hard to debug | `.env` + typed config module |
| Config server for 3 services | Operational overhead without benefit | Env vars + secrets manager |

## Complexity Decision Tree

```
Changing config at runtime without redeploy?
├── YES → External feature flags (LaunchDarkly, Unleash)
└── NO  → Env vars are correct

> 10 services sharing config?
├── YES → Shared config package + secrets manager
└── NO  → Per-service .env + config module

Non-engineers changing flags in production?
├── YES → Feature flag service
└── NO  → FEATURE_X=true env var
```
