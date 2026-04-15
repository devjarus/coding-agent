---
name: ci-testing-standard
description: Every project ships with automated test coverage — CI workflow, test scripts, pre-commit hooks. Auto-detects platform (GitHub Actions, GitLab CI, Bitbucket Pipelines) and stack (Node, Python, Go, Swift, Rust). Apply after first feature ships to ensure changes never break silently.
---

# CI & Testing Standard

Every project the plugin builds must ship with a working CI pipeline. Tests that only run when the developer remembers to type `npm test` aren't tests in practice. The goal: **push to main → CI runs → red/green within 5 minutes.**

## When to Apply

- After the first feature ships (greenfield — no CI exists yet)
- When an existing project has code but no CI workflow
- When CI exists but doesn't cover the tests the evaluator ran
- When adding a new test type (integration, e2e) that CI doesn't know about

Do NOT apply during touch-up on projects that already have working CI.

## What to Set Up

### 1. Test Script

The project must have a single command that runs all tests. Read `package.json` / `Makefile` / `pyproject.toml` / `go.mod` / `Package.swift` to find what exists.

| Stack | Test command | If missing, add |
|-------|-------------|----------------|
| Node/TS | `npm test` or `pnpm test` | Add `"test": "vitest run"` (or `jest`, `mocha` — match what the implementor used) |
| Python | `pytest` | Add `[tool.pytest.ini_options]` to `pyproject.toml` |
| Go | `go test ./...` | Already works if test files exist |
| Swift | `swift test` | Already works if test targets exist |
| Rust | `cargo test` | Already works if test files exist |

### 2. CI Workflow

Auto-detect the git hosting platform and create the appropriate workflow:

#### GitHub Actions (default — most projects)

`.github/workflows/ci.yml`:

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4  # adjust for stack
        with:
          node-version: 22

      - name: Install
        run: npm ci  # or pnpm install --frozen-lockfile

      - name: Typecheck
        run: npm run typecheck  # if tsc exists in scripts

      - name: Lint
        run: npm run lint  # if lint script exists

      - name: Test
        run: npm test

      - name: Build
        run: npm run build  # if build script exists
```

#### GitLab CI

`.gitlab-ci.yml`:

```yaml
test:
  image: node:22
  script:
    - npm ci
    - npm run typecheck
    - npm run lint
    - npm test
    - npm run build
```

#### Bitbucket Pipelines

`bitbucket-pipelines.yml`:

```yaml
pipelines:
  default:
    - step:
        name: Test
        caches: [node]
        script:
          - npm ci
          - npm run typecheck
          - npm run lint
          - npm test
          - npm run build
```

### Stack-specific CI patterns

#### Node/TypeScript
```yaml
steps:
  - run: npm ci                    # frozen lockfile
  - run: npx tsc --noEmit          # typecheck
  - run: npm run lint               # eslint/biome
  - run: npm test                   # vitest/jest
  - run: npm run build              # next build / tsup / tsc
```

#### Python
```yaml
steps:
  - run: pip install -e ".[dev]"    # or pip install -r requirements-dev.txt
  - run: ruff check .               # lint
  - run: mypy src/                  # typecheck (if mypy configured)
  - run: pytest                     # tests
```

#### Go
```yaml
steps:
  - run: go vet ./...               # lint
  - run: go test ./...              # tests
  - run: go build ./...             # build
```

#### Swift (iOS/macOS)
```yaml
steps:
  - run: swift build                 # build
  - run: swift test                  # tests
# OR for Xcode projects:
  - run: xcodebuild test -scheme MyApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'
```

### 3. Pre-commit / Pre-push Hooks (optional but recommended)

Fast local feedback before CI. Use the lightest-weight option for the stack:

| Stack | Tool | What it runs |
|-------|------|-------------|
| Node/TS | `husky` + `lint-staged` | On pre-commit: lint + format staged files only. Fast (<5s). |
| Python | `pre-commit` framework | On pre-commit: ruff, mypy on changed files. |
| Go | `golangci-lint` in pre-commit | On pre-commit: vet + lint changed packages. |
| Any | `lefthook` | Language-agnostic, config in `lefthook.yml`. |

**Keep pre-commit fast (<10s).** Run lint and format on staged files only. Run full tests in CI, not pre-commit.

Example `husky` + `lint-staged` setup for Node:

```json
// package.json
{
  "lint-staged": {
    "*.{ts,tsx}": ["eslint --fix", "prettier --write"],
    "*.{json,md,css}": ["prettier --write"]
  }
}
```

```bash
# Install
npx husky init
echo "npx lint-staged" > .husky/pre-commit
```

## What the CI Must Cover

At minimum, CI must run everything the evaluator checks:

- [ ] **Build** — project compiles without errors
- [ ] **Typecheck** — zero type errors (if the project has types)
- [ ] **Lint** — zero warnings/errors (if a linter is configured)
- [ ] **Tests** — all tests pass (unit + integration)

Additional for web apps:
- [ ] **Build output** — `next build` / `vite build` succeeds (catches runtime import errors that typecheck misses)

Additional for libraries:
- [ ] **Publint** — `npx publint` validates package.json exports
- [ ] **ATTW** — `npx attw --pack .` validates TypeScript resolution

## Rules

1. **CI is mandatory.** A project without CI is a project that silently breaks. Set it up after the first feature, not "when we get around to it."
2. **CI must match what the evaluator tested.** If the evaluator ran `npm test` and `npm run build`, CI must run both. If CI runs fewer checks than the evaluator, the CI is incomplete.
3. **Don't over-engineer.** One workflow file, one job, sequential steps. Parallelize only when CI takes >10 minutes.
4. **Frozen lockfiles in CI.** `npm ci`, `pnpm install --frozen-lockfile`, `pip install -r requirements.txt` — not `npm install` which can drift.
5. **Pre-commit hooks are optional.** They add developer UX but aren't a replacement for CI. Don't block on setting them up if the CI workflow is the priority.
6. **Auto-detect, don't assume.** Read the existing project to determine: what package manager, what test runner, what build tool, what git hosting platform. Don't assume GitHub Actions if the project uses GitLab. Don't assume npm if the project uses pnpm.
