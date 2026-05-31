---
name: project-docs
description: Generates minimal project documentation — README.md, ARCHITECTURE.md with Mermaid diagrams, and AGENTS.md. Run after first feature ships or when docs are missing. Reads the actual codebase to generate accurate docs, not boilerplate.
---

# Project Documentation Generator

Creates minimal, accurate project docs by reading the actual codebase. Not boilerplate — every line comes from what's really there.

## CLAUDE.md and AGENTS.md — no duplication

Claude Code reads `CLAUDE.md` at session startup. Most OSS projects use `AGENTS.md` as the canonical agent workflow document (stack, build/test commands, conventions, known issues). **Do not duplicate content between them** — duplication guarantees drift.

The rule: **one file is the source of truth, the other is a pointer.** In practice, `AGENTS.md` holds the content and `CLAUDE.md` is a 5-line redirect:

```markdown
# Project Notes

This project uses [AGENTS.md](./AGENTS.md) as the canonical agent workflow document.

See AGENTS.md for: stack, build/test commands, conventions, architecture decisions, and known issues.
```

If this project was created before `AGENTS.md` became standard and already has a detailed `CLAUDE.md`, invert the relationship: keep `CLAUDE.md` as the source of truth and make `AGENTS.md` the redirect. Never maintain both.

## AGENTS.md is vendor-neutral

`AGENTS.md` follows the agents.md community spec (https://agents.md). It must be useful to ANY coding agent: Cursor, Aider, Codex, Claude Code with or without this plugin.

❌ No references to `.coding-agent/`, protocols, checks, or skills by name
❌ No `coding-agent:`-prefixed instructions or dispatch sequences
❌ No deploy commands, env-var lists, or runtime state — those live in `.coding-agent/environments.md`
✓ Stack, build/test commands, conventions, architecture, known gotchas

Plugin-specific configuration lives in `.coding-agent/`. The plugin reads its own files; it doesn't need `AGENTS.md` to point at them. A user must be able to remove this plugin and have `AGENTS.md` keep working for whatever agent they switch to.

## When to Apply

- **After** first feature ships (review PASS) — docs describe what was actually built, not what was planned
- When project is missing README or architecture docs
- When significant architectural changes need documenting
- Never before implementation — you can't document what doesn't exist yet

## Replace scaffold READMEs — they are NOT real content

A `create-vite` / `create-react-app` / `create-next-app` scaffold ships a placeholder README describing *the template*, not *your app*. Shipping it is a real failure mode: the repo's front page reads "This template provides a minimal setup…" instead of what the project does. **A scaffold README must be fully replaced, not preserved.** The `docs-current` close-out check (`checks/docs-current.sh`) blocks close-out while any of these fingerprints remain — keep this list in sync with it:

| Scaffold | Fingerprint phrase |
|----------|--------------------|
| Vite | `This template provides a minimal setup` / `Currently, two official plugins are available` |
| Create React App | `Getting Started with Create React App` |
| Next.js | `bootstrapped with [\`create-next-app\`]` |
| SvelteKit | `npm create svelte@latest` |
| Astro | `npm create astro@latest` / `Welcome to your new Astro project` / `Everything you need to know is in the README` |

The check also fails a README that is **byte-identical to its first commit while ≥3 source commits have landed** — i.e. one that was committed at scaffold time and never touched. Either way, the fix is the same: write a real README from the actual codebase (below).

## What It Creates

### 1. README.md

```markdown
# Project Name

[1-sentence description from spec.md or package.json]

## Quick Start

[exact install + run commands — read from package.json scripts, Makefile, etc.]

## Tech Stack

[language, framework, database, key deps — from package.json/go.mod/Package.swift/requirements.txt]

## Project Structure

[tree of key directories with 1-line descriptions — from actual file scan]

## Testing

[exact test commands + what they cover]

## API Reference (if applicable)

[endpoints with methods, paths, request/response shapes — from route files]

## License

[from LICENSE file if exists]
```

### 2. ARCHITECTURE.md

Use ASCII diagrams — they render everywhere with no dependencies. Read the actual code to generate these.

```markdown
# Architecture

## Overview

[2-3 sentences: what the system does, key design decisions]

## System Diagram

[ASCII box diagram showing major components and connections]

## Data Flow

[ASCII flow showing a primary user flow end-to-end]

## Data Model

[ASCII table showing schema — fields, types, relationships]

## Key Components

[for each major module: what it does, what it depends on, key files]

## Technical Decisions

[from spec.md Technical Risks / Architecture Decisions if available, otherwise infer from code]
```

### 3. AGENTS.md

```markdown
# Development Workflow

## Stack
[language, framework, database, key libraries with versions]

## Build & Run
[exact commands]

## Test
[exact commands — unit, integration, e2e]

## Project Structure
[key directories]

## Conventions
[patterns, naming, file organization]

## Architecture Decisions
[key decisions and why]

## Known Issues
[from review.md findings if available]

## Development Notes
[gotchas, ordering requirements, env setup]
```

## How to Generate

### Step 1 — Scan the codebase

Read these files to understand what exists:
- `package.json` / `go.mod` / `Package.swift` / `requirements.txt` → stack + deps
- `spec.md`, `plan.md` (if in `.coding-agent/`) → requirements + architecture decisions
- Route/controller files → API surface
- Schema/migration files → data model
- Test files → test commands + coverage
- Entry points (`src/index.*`, `src/app.*`, `main.*`) → how the app starts

### Step 2 — Generate ASCII diagrams

Use plain ASCII art. Examples:

**System diagram:**
```
┌──────────────┐    HTTP     ┌──────────────┐    SQL     ┌──────────┐
│ React Client │───────────→│ Express API  │──────────→│  SQLite  │
│  :5173       │←───────────│  :3001       │←──────────│          │
└──────────────┘             └──────────────┘           └──────────┘
```

**Data flow:**
```
User → Frontend → POST /api/posts → Validate → INSERT INTO posts → Return 201 → Redirect to /posts/:slug
```

**Data model:**
```
posts
├── id          INTEGER  PK  autoincrement
├── title       TEXT     NOT NULL
├── slug        TEXT     UNIQUE
├── content     TEXT     NOT NULL
├── excerpt     TEXT
├── tags        TEXT
├── createdAt   TEXT
└── updatedAt   TEXT
```

### Step 3 — Write the files

Write each file at the project root. Keep them minimal:
- README.md: under 80 lines
- ARCHITECTURE.md: under 120 lines
- AGENTS.md: under 60 lines

## Rules

- **Read the code, don't guess.** Every command, path, and diagram must come from the actual codebase.
- **Pin versions in docs.** If package.json says `express@4.21.0`, write that — not just "Express".
- **ASCII diagrams are required** in ARCHITECTURE.md. At minimum: system diagram + data flow.
- **Keep it minimal.** If a section has nothing useful, omit it. Empty sections are worse than no section.
- **Don't duplicate README and AGENTS.md.** README is for humans browsing the repo. AGENTS.md is for dev workflow (build/test commands, conventions).
- **Brownfield: preserve a real README, replace a scaffold one.** Read it first. If it's hand-written (custom content, contributing guides, badges), only add missing sections or update outdated ones — preserve it. If it matches a scaffold fingerprint (see *Replace scaffold READMEs* above) or is the untouched generated placeholder, replace it wholesale — there is nothing worth preserving.
- **Brownfield: always create AGENTS.md** if missing — existing projects rarely have agent workflow docs.
- **Brownfield: update ARCHITECTURE.md** only if your feature changed the architecture (new components, new data models, new integrations).
