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

**`process.env` / `os.environ` is accessed in exactly ONE file -- the config module. Everything else imports from it.**

## Rules

### CRITICAL

- **CFG-01:** Single config module -- one file reads env vars, exports a typed frozen object
- **CFG-02:** Validate at startup -- Zod (TS), Pydantic (Python), envconfig (Go); exit on failure
- **CFG-03:** No secrets in code or config files -- secrets from env vars only; `.env` gitignored
- **CFG-04:** No silent defaults for required values -- required config fails loudly if missing

### HIGH

- **CFG-05:** Typed config object -- ports are numbers, booleans are booleans, URLs are validated
- **CFG-06:** Separate server and client config -- `NEXT_PUBLIC_` in client.ts, secrets in server.ts
- **CFG-07:** `.env.example` is documentation -- every var listed with description and safe default
- **CFG-08:** Derive flags from env once -- `config.isProduction` not `process.env.NODE_ENV === 'production'`

### MEDIUM

- **CFG-09:** Config vs constants -- config changes between envs; constants don't
- **CFG-10:** Group config by domain -- `config.database.url`, `config.auth.jwtSecret`
- **CFG-11:** Freeze the config object -- `Object.freeze()` or equivalent
- **CFG-12:** Lint against direct env access -- ESLint `no-process-env` rule

### LOW

- **CFG-13:** Don't overengineer -- `.env` + typed config module + secrets manager is enough
- **CFG-14:** Monorepo: shared schemas, separate `.env` per service

## Framework Patterns (rules/patterns-by-framework.md)

- Node.js/TypeScript with Zod schema + `safeParse` + `Object.freeze`
- Python/FastAPI with Pydantic `BaseSettings` + `@lru_cache`
- Go with `envconfig` struct tags + `required:"true"`
- Next.js with separate `server.ts` and `client.ts` config modules

## Anti-Patterns

- `process.env.X` scattered in 40 files -- use single config module
- `process.env.X || 'default'` -- silent failure with wrong value
- Secrets in committed files -- `.env.example` committed, `.env` gitignored
- `if (NODE_ENV === 'production')` everywhere -- derive semantic flags in config
- YAML config inheritance chains -- overengineered; use env vars
- Config server for 3 services -- unnecessary operational overhead
