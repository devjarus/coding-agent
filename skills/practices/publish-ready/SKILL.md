---
name: publish-ready
description: Prepares a project for public distribution — open source setup, package.json exports, bundling, docs, CI/CD, GitHub templates, LICENSE, CONTRIBUTING, SECURITY. Learned from Next.js, Vite, shadcn/ui, Tailwind CSS, tRPC patterns.
---

# Publish Ready

Cleans up a project for public open source distribution. Every check is based on what top OSS projects actually do (Next.js, Vite, shadcn/ui, Tailwind CSS, tRPC).

## When to Apply

- Before first public release or npm publish
- Before open-sourcing an internal project
- When cleaning up a project for distribution

## Process

### Step 1 — Audit what exists

Read the project root. Check what's present, what's missing, what needs fixing.

### Step 2 — Fix package.json (rules/package-json.md)

The published package.json must have:

```json
{
  "name": "@scope/package",
  "version": "0.1.0",
  "type": "module",
  "license": "MIT",
  "exports": {
    ".": {
      "import": { "types": "./dist/index.d.mts", "default": "./dist/index.mjs" },
      "require": { "types": "./dist/index.d.cts", "default": "./dist/index.cjs" }
    }
  },
  "files": ["dist"],
  "engines": { "node": ">=20" },
  "publishConfig": { "access": "public" }
}
```

Key rules:
- **`exports` over `main`/`module`** — conditional subpath exports with types for both ESM and CJS
- **`files` explicit allowlist** — never use `.npmignore`. List exactly what ships: `["dist"]`
- **`type: "module"`** — ESM by default (4/5 top projects do this)
- **`engines`** — specify minimum Node version (>=20)
- **`publishConfig.access: "public"`** — required for scoped packages
- **Pin dependency versions** — `^x.y.z` ranges, never `"latest"` or `"*"`

### Step 3 — Set up bundling (rules/bundling.md)

Use **tsup** or **tsdown** for TypeScript libraries:

```typescript
// tsup.config.ts
import { defineConfig } from 'tsup'
export default defineConfig({
  entry: ['src/index.ts'],
  format: ['esm', 'cjs'],
  dts: true,
  clean: true,
  splitting: false,
  sourcemap: true,
})
```

Add to package.json scripts:
```json
{
  "scripts": {
    "build": "tsup",
    "dev": "tsup --watch",
    "typecheck": "tsc --noEmit",
    "prepublishOnly": "npm run build"
  }
}
```

### Step 4 — Required files at root

Create these if missing:

**LICENSE** (MIT — used by all 5 top projects):
```
MIT License

Copyright (c) [year] [name]

Permission is hereby granted, free of charge...
```

**CONTRIBUTING.md** — present in all 5 top projects:
```markdown
# Contributing

## Development Setup
[exact install + build + test commands]

## Pull Request Process
1. Fork the repo
2. Create a feature branch
3. Make your changes with tests
4. Run the full test suite
5. Submit a PR

## Code Style
[link to ESLint/Prettier config or describe conventions]

## Reporting Issues
[link to issue templates]
```

**SECURITY.md**:
```markdown
# Security Policy

## Reporting a Vulnerability
Please report security vulnerabilities to [email].
Do NOT open public issues for security vulnerabilities.

## Supported Versions
| Version | Supported |
|---------|-----------|
| x.x.x   | Yes       |
```

**CODE_OF_CONDUCT.md** — use Contributor Covenant v2.1

### Step 5 — GitHub templates (rules/github-templates.md)

Create `.github/` directory with:

**`.github/ISSUE_TEMPLATE/bug_report.yml`** — structured YAML form:
```yaml
name: Bug Report
description: Report a bug
labels: [bug]
body:
  - type: textarea
    attributes:
      label: Description
      description: What happened?
    validations:
      required: true
  - type: textarea
    attributes:
      label: Reproduction
      description: Steps to reproduce
    validations:
      required: true
  - type: input
    attributes:
      label: Version
  - type: textarea
    attributes:
      label: Environment
```

**`.github/ISSUE_TEMPLATE/feature_request.yml`**

**`.github/ISSUE_TEMPLATE/config.yml`**:
```yaml
blank_issues_enabled: false
contact_links:
  - name: Questions
    url: https://github.com/[org]/[repo]/discussions
    about: Ask questions in Discussions
```

**`.github/pull_request_template.md`**:
```markdown
## What

[Brief description]

## Why

[Motivation]

## How

[Approach]

## Checklist

- [ ] Tests pass
- [ ] Types pass (`tsc --noEmit`)
- [ ] Lint passes
- [ ] Docs updated (if applicable)
```

### Step 6 — CI/CD (rules/ci-cd.md)

**`.github/workflows/ci.yml`** — runs on every PR:
```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm run typecheck
      - run: pnpm run lint
      - run: pnpm run test
      - run: pnpm run build
```

**`.github/workflows/release.yml`** — publishes on tag push:
```yaml
name: Release
on:
  push:
    tags: ['v*']
permissions:
  contents: write
  id-token: write  # npm provenance
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          registry-url: https://registry.npmjs.org
      - run: pnpm install --frozen-lockfile
      - run: pnpm run build
      - run: npm publish --provenance --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### Step 7 — Final checklist

Before publishing, verify:

- [ ] `npm pack --dry-run` shows only intended files
- [ ] `npx publint` passes (validates package.json exports)
- [ ] `npx attw --pack .` passes (checks TypeScript resolution)
- [ ] Build output works: `node -e "import('.')"` and `node -e "require('.')"` both succeed
- [ ] README has: description, install command, quick example, API docs link, license badge
- [ ] No secrets in repo (`.env`, API keys, tokens)
- [ ] `.gitignore` covers: `node_modules`, `dist`, `.env`, `.DS_Store`
- [ ] All tests pass
- [ ] TypeScript compiles with no errors

## Rules

- **`files` over `.npmignore`** — explicit allowlist, never a denylist
- **Dual ESM/CJS** — use conditional exports for both
- **MIT License** — industry standard for OSS libraries
- **npm provenance** — sign packages via GitHub Actions `id-token: write`
- **Don't ship tests** — use `files: ["dist"]`, not the entire src
- **Pin your lockfile** — `pnpm-lock.yaml` committed, CI uses `--frozen-lockfile`
