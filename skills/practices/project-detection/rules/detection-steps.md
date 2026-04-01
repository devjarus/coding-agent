# Project Detection Steps

Work through each step in order. Skip steps that are clearly irrelevant, but never skip Step 1.

## Step 1: Package Manager & Language

| File to check | Indicates |
|---|---|
| `package.json` | Node.js / JavaScript / TypeScript |
| `go.mod` | Go |
| `pyproject.toml` or `requirements.txt` | Python |
| `Cargo.toml` | Rust |
| `pom.xml` or `build.gradle` | Java / Kotlin (JVM) |
| `composer.json` | PHP |

For Node.js, identify package manager from lockfile:

| Lockfile | Package manager |
|---|---|
| `package-lock.json` | npm |
| `pnpm-lock.yaml` | pnpm |
| `yarn.lock` | Yarn |
| `bun.lockb` | Bun |

## Step 2: Framework

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

## Step 3: Styling

| File / dependency | Indicates |
|---|---|
| `tailwind.config.*` | Tailwind CSS v3 |
| `@tailwindcss/postcss` in deps | Tailwind CSS v4 |
| `postcss.config.*` | PostCSS pipeline |
| `styled-components` or `@emotion/*` | CSS-in-JS |
| `*.module.css` files | CSS Modules |
| `*.scss` files | Sass / SCSS |

**Tailwind version distinction:** v3 uses `tailwind.config.js`; v4 drops the config file and relies on `@tailwindcss/postcss` + CSS-first configuration.

## Step 4: Database & ORM

| File / directory | Indicates |
|---|---|
| `prisma/` | Prisma ORM |
| `drizzle.config.*` | Drizzle ORM |
| `knexfile.*` | Knex query builder |
| `alembic/` | SQLAlchemy + Alembic |
| `typeorm` in deps | TypeORM |
| `mongoose` in deps | MongoDB via Mongoose |

Also check `docker-compose.yml` for database service images.

## Step 5: Testing

| File | Indicates |
|---|---|
| `jest.config.*` | Jest |
| `vitest.config.*` | Vitest |
| `playwright.config.*` | Playwright (E2E) |
| `cypress.config.*` | Cypress (E2E) |
| `pytest.ini`, `conftest.py` | pytest |

Also check `package.json` scripts for `test`, `test:unit`, `test:e2e`.

## Step 6: Infrastructure

| File / directory | Indicates |
|---|---|
| `Dockerfile` | Container build |
| `docker-compose.yml` | Local container orchestration |
| `.github/workflows/` | GitHub Actions CI/CD |
| `.gitlab-ci.yml` | GitLab CI/CD |
| `vercel.json` | Vercel deployment |
| `terraform/` | Terraform IaC |
| `.env.example` | Expected environment variables |

## Step 7: Code Quality

| File | Indicates |
|---|---|
| `.eslintrc.*` or `eslint.config.*` | ESLint |
| `.prettierrc.*` | Prettier |
| `biome.json` | Biome |
| `.editorconfig` | Editor normalization |
| `tsconfig.json` | TypeScript; check `strict`, `paths`, `baseUrl` |

## Output Format

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
- TypeScript path aliases: @/* -> src/*
- Tailwind config: tailwind.config.ts (custom theme)
- API pattern: Next.js Route Handlers in app/api/
```
