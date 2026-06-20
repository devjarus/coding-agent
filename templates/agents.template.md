<!-- Single source of truth: executable build/test/lint commands + contribution mechanics + conventions. Follows the agents.md spec (https://agents.md) — vendor-neutral, usable by ANY coding agent. Names tech without versions (README pins them) and never restates architecture, product, or deploy detail. Keep under 60 lines. -->

# AGENTS.md

How to operate on this repository. Written for any coding agent (Cursor, Aider, Codex, Claude Code, …). Each fact below lives in exactly one doc — follow the links rather than expecting copies.

## Setup

```bash
<dev environment / install commands>
```

## Build & Run

```bash
<exact build + run commands>
```

## Testing

```bash
<exact unit / integration / e2e commands>
```

Fix until green before marking work done. CI runs the same suite (see `.github/workflows/`).

## Conventions

- <code style, naming, file organization>
- <error handling / logging patterns>
- <commit / PR rules>

## Project Structure

See the directory tree in [README.md](README.md#project-structure). Module responsibilities + dependencies: [docs/architecture.md](docs/architecture.md).

## Known Gotchas

- <ordering requirements, env quirks, sharp edges>

## Where to look next

- **What & why** → [PRODUCT.md](PRODUCT.md)
- **System design & stack rationale** → [docs/architecture.md](docs/architecture.md)
- **How data flows** → [docs/dataflow.md](docs/dataflow.md)
- **UI / design system** → [DESIGN.md](DESIGN.md)
- **Deploy & CI/CD** → [deployment.md](deployment.md)
