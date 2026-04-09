---
name: config-management
description: Centralized config and lightweight dependency injection — single config module, validated at startup, factory/constructor injection for wiring, composition root pattern. No heavy DI frameworks unless the app actually needs them.
---

# Config & Dependency Injection

Two related concerns: where config comes from, and how dependencies are wired. Both follow the same principle — **centralize and inject, don't scatter and import**.

## When to Apply

- Scaffolding a new project (set up config module + composition root in Wave 1)
- Code reads env vars directly in business logic
- Hardcoded values (URLs, ports, secrets)
- Services create their own dependencies (new DB() inside a handler)
- Tests can't swap dependencies without mocking imports
- Complex app with 10+ services that need wiring

## Config Rules

### The Core Rule

**`process.env` / `os.environ` / `System.getenv` is accessed in exactly ONE file — the config module. Everything else receives config via injection.**

### Critical

- **CFG-01:** Single config module — one file reads env vars, exports a typed frozen object
- **CFG-02:** Validate at startup — exit on failure, not silent defaults for required values
- **CFG-03:** No secrets in code — secrets from env vars only, `.env` gitignored, `.env.example` committed
- **CFG-04:** Config is a dependency — inject it (or its subset), don't import it globally

### High

- **CFG-05:** Typed config — ports are numbers, booleans are booleans, URLs are validated
- **CFG-06:** Group by domain — `config.database.url`, `config.auth.jwtSecret`
- **CFG-07:** Derive flags once — `config.isProduction` not `process.env.NODE_ENV === 'production'`
- **CFG-08:** Pass subsets, not the whole config — EmailService gets smtp config, not all of config

For framework-specific config patterns, see [rules/patterns-by-framework.md](rules/patterns-by-framework.md).

## Dependency Injection

### The Universal Pattern (all languages)

```
1. Define interfaces/protocols for dependencies
2. Accept them via constructor/factory parameters
3. Wire everything in ONE place (composition root)
4. For tests, pass fakes directly — no framework needed
5. Config is just another dependency
```

### When to Use What

| Complexity | Pattern | Example |
|------------|---------|---------|
| Simple (< 15 services) | Factory functions + constructor injection | Most apps start here |
| Medium (15-50 services) | Composition root with grouped factory functions | Growing apps |
| Complex (50+ services, multiple entry points) | Lightweight container (awilix, Wire, Dagger) | Large apps, monorepos |
| Framework provides it | Use the framework's DI (FastAPI Depends, Spring, SwiftUI Environment) | When it's idiomatic |

**Default: start with factory functions. Add a container only when the composition root becomes painful.**

### Composition Root

One file/function that wires all dependencies. The ONLY place that knows about concrete implementations.

```
src/
├── composition-root.ts    ← wires everything, knows all concrete classes
├── config.ts              ← reads env vars, exports typed config
├── services/
│   ├── user-service.ts    ← accepts interfaces, knows nothing about DB/config
│   └── order-service.ts
├── repositories/
│   ├── user-repo.ts       ← implements interface, accepts db connection
│   └── order-repo.ts
└── index.ts               ← calls composition root, starts server
```

For language-specific composition root patterns, see [rules/dependency-injection.md](rules/dependency-injection.md).

### Testing — Why DI Matters

```
WITHOUT DI:
  Service imports DB directly → can't test without real DB
  Service imports config directly → can't test with different config
  Must mock imports → fragile, tied to file paths

WITH DI:
  Service accepts interfaces → pass fakes in tests
  No mocking library needed for most tests
  Tests are fast, isolated, don't need infrastructure
```

### Anti-Patterns

- **Global singletons** — `shared` / `instance` / module-level vars. Makes testing painful.
- **Service locator** — `Container.resolve(Thing)` inside business logic hides dependencies.
- **Field injection** — `@Autowired lateinit var repo` hides what a class needs.
- **Importing the DB/config directly** — `import { db } from '../db'` hardwires the dependency.
- **Over-abstracting** — don't create an interface for something with only one implementation. Create it when you need a second implementation or need to mock in tests.
- **Injecting the whole config** — pass only what the service needs, not the entire config object.

## Implementation Checklist

Wave 1 (foundation) should set up:

- [ ] Config module — single file, typed, validated at startup
- [ ] `.env.example` — every var with description and safe default
- [ ] Composition root — one file that wires all dependencies
- [ ] Services accept dependencies via constructor, not import
- [ ] Config subset injection — services get only the config they need

## Evaluator Checklist

- [ ] No direct env var access outside config module
- [ ] Config validated at startup (fails loudly on missing required values)
- [ ] No secrets in committed files
- [ ] Services accept dependencies via constructor/factory (not global imports)
- [ ] Composition root exists and is the only place that knows concrete implementations
- [ ] Tests use injected fakes, not import mocking
