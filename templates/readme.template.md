<!-- Single source of truth: install/run quick-start + pinned versions + structure tree. Everything else links out. Keep under 80 lines. -->

# <Project Name>

<One-sentence description. The "what" in a line. The deeper "why/for-whom" lives in [PRODUCT.md](PRODUCT.md).>

## Quick Start

```bash
<exact install command — from package.json / Makefile / etc.>
<exact run command>
```

## Tech Stack

<Language · framework · datastore · key deps, with PINNED versions (e.g. `react@19.0.0`). This is the only doc that pins versions; rationale lives in [docs/architecture.md](docs/architecture.md).>

## Project Structure

```
<tree of key directories, one-line each — the only authoritative tree>
```

## Testing

```bash
<the single entry test command>
```

Full build/test/lint commands and conventions: [AGENTS.md](AGENTS.md).

## Documentation Map

| Doc | What it owns |
|-----|--------------|
| [AGENTS.md](AGENTS.md) | How to build, test, and contribute (any agent) |
| [PRODUCT.md](PRODUCT.md) | What the product is, who it's for, the problem it solves |
| [docs/architecture.md](docs/architecture.md) | System topology, data model, stack rationale |
| [docs/dataflow.md](docs/dataflow.md) | How data moves end-to-end |
| [DESIGN.md](DESIGN.md) | Design system — tokens, components, look & feel |
| [deployment.md](deployment.md) | How to deploy + CI/CD |

## License

<from LICENSE file, if present>
