# Config Management Patterns by Framework

## Node.js / TypeScript (Zod)

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

## Python / FastAPI (Pydantic)

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

## Go (envconfig)

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

## Next.js (separate server/client)

```typescript
// lib/config/server.ts -- NEVER import in client components
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
// lib/config/client.ts -- safe for browser
import { z } from 'zod';
export const clientConfig = z.object({
  apiUrl: z.string().url(),
  appEnv: z.enum(['development', 'staging', 'production']),
}).parse({
  apiUrl: process.env.NEXT_PUBLIC_API_URL,
  appEnv: process.env.NEXT_PUBLIC_APP_ENV,
});
```

## What the Scaffolder Must Create

```
.env.example           # All vars documented, safe defaults, no real secrets
.env                   # Local dev defaults (gitignored if contains secrets)
.gitignore             # Includes: .env.local, .env.production, .env.*.local
src/config/
  index.ts             # Singleton config loader -- the ONLY file that reads process.env
  schema.ts            # Zod/Pydantic schema with types, defaults, validation
```

## Environment Strategy

| Environment | Config delivery | Secrets |
|---|---|---|
| Local dev | `.env` file + docker-compose | Fake/test values |
| CI/CD | CI platform env vars | CI secrets store |
| Staging | Deployment platform env vars | Secrets manager |
| Production | Secrets manager -> injected at deploy | AWS SSM, GCP Secret Manager, Vault |

## Complexity Decision Tree

```
Changing config at runtime without redeploy?
+-- YES -> External feature flags (LaunchDarkly, Unleash)
+-- NO  -> Env vars are correct

> 10 services sharing config?
+-- YES -> Shared config package + secrets manager
+-- NO  -> Per-service .env + config module

Non-engineers changing flags in production?
+-- YES -> Feature flag service
+-- NO  -> FEATURE_X=true env var
```
