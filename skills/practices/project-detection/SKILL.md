---
name: project-detection
description: Detect project tech stack, framework, and configuration before starting work. Use at the beginning of any task in a new or unfamiliar codebase to understand what you're working with.
---

# Project Detection

Inspect the codebase before proposing or making any changes. This skill walks through a structured detection sequence — like running `shadcn info --json` — so every specialist starts with accurate context rather than assumptions.

---

## When to Apply

- Starting work on an unfamiliar codebase
- Scaffolder setting up a new project
- Any specialist beginning work without clear context
- Brainstormer or Planner analyzing a brownfield project

---

## Detection Steps

Work through each step in order. Skip steps that are clearly irrelevant (e.g., skip database detection for a pure front-end static site), but never skip Step 1.

---

### Step 1: Package Manager & Language

Determine the primary language and package manager before anything else — every subsequent step depends on this.

| File to check | Indicates |
|---|---|
| `package.json` | Node.js / JavaScript / TypeScript |
| `go.mod` | Go |
| `pyproject.toml` or `requirements.txt` | Python |
| `Cargo.toml` | Rust |
| `pom.xml` or `build.gradle` | Java / Kotlin (JVM) |
| `composer.json` | PHP |

For Node.js projects, identify the package manager from the lockfile:

| Lockfile | Package manager |
|---|---|
| `package-lock.json` | npm |
| `pnpm-lock.yaml` | pnpm |
| `yarn.lock` | Yarn |
| `bun.lockb` | Bun |

---

### Step 2: Framework

Check `package.json` dependencies and config files. Do not guess — read the files.

**JavaScript / TypeScript**

| Dependency / config file | Framework |
|---|---|
| `next` in deps, `next.config.*` | Next.js |
| `react` in deps (no Next) | React (Vite, CRA, or custom) |
| `vue` in deps, `nuxt.config.*` | Vue / Nuxt |
| `svelte` in deps, `svelte.config.*` | Svelte / SvelteKit |
| `@angular/core`, `angular.json` | Angular |
| `express` in deps | Express |
| `fastify` in deps | Fastify |

**Directory structure signals**

| Path | Indicates |
|---|---|
| `src/app/` | Next.js App Router |
| `src/pages/` | Next.js Pages Router (or Vite) |
| `src/routes/` | SvelteKit |
| `app/` at root | Rails, Laravel, or Next.js App Router |

**Python**

| Dependency / file | Framework |
|---|---|
| `django` in deps | Django |
| `flask` in deps | Flask |
| `fastapi` in deps | FastAPI |

---

### Step 3: Styling

| File / dependency | Indicates |
|---|---|
| `tailwind.config.*` | Tailwind CSS v3 |
| `@tailwindcss/postcss` in deps | Tailwind CSS v4 |
| `postcss.config.*` | PostCSS pipeline |
| `styled-components` or `@emotion/*` in deps | CSS-in-JS |
| `*.module.css` files present | CSS Modules |
| `*.scss` files present | Sass / SCSS |
| `*.css` with `@import` only | Plain CSS |

**Tailwind version distinction:** v3 uses `tailwind.config.js`; v4 drops the config file and relies on `@tailwindcss/postcss` + CSS-first configuration.

---

### Step 4: Database & ORM

| File / directory | Indicates |
|---|---|
| `prisma/` directory | Prisma ORM |
| `drizzle.config.*` | Drizzle ORM |
| `knexfile.*` | Knex query builder |
| `alembic/` directory | SQLAlchemy + Alembic (Python) |
| `sqlalchemy` in deps | SQLAlchemy (Python) |
| `typeorm` in deps | TypeORM |
| `mongoose` in deps | MongoDB via Mongoose |

Also check `docker-compose.yml` for database service images (`postgres`, `mysql`, `mariadb`, `redis`, `mongo`, `elasticsearch`).

---

### Step 5: Testing

| File | Indicates |
|---|---|
| `jest.config.*` | Jest |
| `vitest.config.*` | Vitest |
| `.playwright/` or `playwright.config.*` | Playwright (E2E) |
| `cypress/` or `cypress.config.*` | Cypress (E2E) |
| `pytest.ini`, `conftest.py`, or `pyproject.toml [tool.pytest]` | pytest (Python) |

Also check `package.json` scripts for keys like `test`, `test:unit`, `test:e2e`, `coverage`.

---

### Step 6: Infrastructure

| File / directory | Indicates |
|---|---|
| `Dockerfile` | Container build |
| `docker-compose.yml` | Local container orchestration |
| `.github/workflows/` | GitHub Actions CI/CD |
| `.gitlab-ci.yml` | GitLab CI/CD |
| `vercel.json` | Vercel deployment |
| `netlify.toml` | Netlify deployment |
| `terraform/` | Terraform IaC |
| `cdk/` or `lib/*.stack.ts` | AWS CDK |
| `.env.example` | Expected environment variables |
| `.env.local` | Local overrides (do not read values — just note its presence) |

---

### Step 7: Code Quality

| File | Indicates |
|---|---|
| `.eslintrc.*` or `eslint.config.*` | ESLint |
| `.prettierrc.*` | Prettier |
| `biome.json` | Biome (linter + formatter) |
| `.editorconfig` | Editor normalization |
| `tsconfig.json` | TypeScript; check `strict`, `paths`, `baseUrl` |

For TypeScript projects, note:
- `"strict": true` in `tsconfig.json` — enforces strict null checks, no implicit any, etc.
- Path aliases under `compilerOptions.paths` — affects imports throughout the codebase.

---

## Output Format

After completing detection, produce a structured summary block at the top of your response or in the task context:

```
## Project Context

**Language:** TypeScript/JavaScript (Node.js 20)
**Package Manager:** pnpm
**Framework:** Next.js 14 (App Router)
**Styling:** Tailwind CSS v4
**Database:** PostgreSQL via Prisma
**Testing:** Vitest + Playwright
**Infrastructure:** Docker + Vercel
**Code Quality:** ESLint + Prettier, TypeScript strict mode
**Monorepo:** No (single package)

### Key Config
- TypeScript path aliases: @/* → src/*
- Tailwind config: tailwind.config.ts (custom theme)
- API pattern: Next.js Route Handlers in app/api/
```

Omit rows that do not apply. Add rows for anything significant not covered above (e.g., monorepo tooling like Turborepo or Nx, authentication libraries, feature flag services).

---

## Rules

- **CRITICAL:** Always run detection before proposing changes to an unfamiliar codebase. Never assume a framework or tool — verify by checking config files.
- **CRITICAL:** If a config file and a dependency disagree (e.g., `next.config.ts` present but `next` not in `package.json`), flag the inconsistency rather than silently choosing one.
- **HIGH:** Detection results should inform which specialists are dispatched and what patterns they follow (e.g., a Tailwind v4 project should not receive v3 config snippets).
- **HIGH:** Surface path aliases and import conventions early — specialists will need them to write correct imports.
- **MEDIUM:** Re-run detection after scaffolding to update context (new dependencies may have been added).
- **LOW:** Do not read the contents of `.env` or `.env.local` — only note their existence.
