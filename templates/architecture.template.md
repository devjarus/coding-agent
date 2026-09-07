<!-- Single source of truth: system topology, data model (schema), component inventory, and stack rationale. The ONLY high-level architecture surface — replaces a root ARCHITECTURE.md for this project. Owns the Data MODEL (schema); the data FLOW lives in dataflow.md. Complex component contracts may live under docs/components/ and are linked, never copied, from the inventory. ASCII diagrams only (render everywhere, no deps). Keep under 120 lines. -->

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

| Module | Responsibility | Depends on | Key files | Detailed contract |
|--------|----------------|------------|-----------|-------------------|
| <name> | <what it does> | <deps> | <paths> | [components/name.md](components/name.md) or — |

(UI modules: appearance lives in [../DESIGN.md](../DESIGN.md), not here.)
(Create a component contract only for a substantial boundary; ordinary modules
remain documented by this inventory, source, and tests.)

## Technical Decisions / Stack Rationale

| Decision | Chosen | Alternatives | Why |
|----------|--------|--------------|-----|
| <area> | <choice> | <considered> | <tradeoff> |

## See also

- [dataflow.md](dataflow.md) — end-to-end data movement
- [deployment.md](../deployment.md) — how it ships
- [index.md](index.md) — docs bundle
