---
name: project-detection
description: Detect project tech stack, framework, and configuration before starting work. Use at the beginning of any task in a new or unfamiliar codebase to understand what you're working with.
---

# Project Detection

Inspect the codebase before proposing or making any changes. Structured detection sequence so every specialist starts with accurate context rather than assumptions.

## When to Apply

- Starting work on an unfamiliar codebase
- Scaffolder setting up a new project
- Any specialist beginning work without clear context
- Brainstormer or Planner analyzing a brownfield project

## Detection Steps (rules/detection-steps.md)

1. **Package Manager & Language** -- check lockfiles and manifest files (never skip)
2. **Framework** -- check deps and config files; verify directory structure signals
3. **Styling** -- Tailwind v3 vs v4, CSS-in-JS, CSS Modules, Sass
4. **Database & ORM** -- Prisma, Drizzle, SQLAlchemy, Mongoose; check docker-compose
5. **Testing** -- Jest, Vitest, Playwright, Cypress, pytest
6. **Infrastructure** -- Dockerfile, CI/CD, deployment platform, env vars
7. **Code Quality** -- ESLint, Prettier, Biome, TypeScript strict mode, path aliases

## Rules

- **CRITICAL:** Always run detection before proposing changes to an unfamiliar codebase. Never assume -- verify config files.
- **CRITICAL:** If a config file and a dependency disagree, flag the inconsistency rather than silently choosing one.
- **HIGH:** Detection results inform which specialists are dispatched and what patterns they follow.
- **HIGH:** Surface path aliases and import conventions early -- specialists need them for correct imports.
- **MEDIUM:** Re-run detection after scaffolding to update context.
- **LOW:** Do not read `.env` or `.env.local` contents -- only note their existence.
