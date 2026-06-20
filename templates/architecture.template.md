<!-- Single source of truth: system topology, data model (schema), key components, and stack rationale. The ONLY architecture surface — replaces a root ARCHITECTURE.md for this project. Owns the Data MODEL (schema); the data FLOW lives in dataflow.md. ASCII diagrams only (render everywhere, no deps). Keep under 120 lines. -->

# Architecture

> System design for humans and agents. How data *moves* is in [dataflow.md](dataflow.md); how to run it is in [../README.md](../README.md); product intent is in [../PRODUCT.md](../PRODUCT.md).

## Overview

<2-3 sentences: what the system does and its key design decisions.>

## System Diagram

```
<ASCII box diagram: major components + connections + ports/protocols>
```

## Data Model

```
<ASCII schema: tables/entities → fields, types, keys, relationships>
```

## Key Components

| Module | Responsibility | Depends on | Key files |
|--------|----------------|------------|-----------|
| <name> | <what it does> | <deps> | <paths> |

(UI modules: appearance lives in [../DESIGN.md](../DESIGN.md), not here.)

## Technical Decisions / Stack Rationale

| Decision | Chosen | Alternatives | Why |
|----------|--------|--------------|-----|
| <area> | <choice> | <considered> | <tradeoff> |

## See also

- [dataflow.md](dataflow.md) — end-to-end data movement
- [deployment.md](../deployment.md) — how it ships
- [index.md](index.md) — docs bundle
