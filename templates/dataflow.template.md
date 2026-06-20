<!-- Single source of truth: how data MOVES end-to-end (flow traces, state transitions, external boundaries, persistence touchpoints). Owns the flow narrative — extracted out of architecture so neither duplicates the other. Never lists schema columns (that's architecture.md's Data Model) or component topology. -->

# Data Flow

> How data moves through the system. The component topology and schema live in [architecture.md](architecture.md); this file owns the *movement*.

## Primary Flow(s)

```
<ASCII end-to-end trace: User → entry → validation → processing → persistence → response>
```

## State Transitions

<the key state machine(s): states, the events that move between them, terminal states.>

## External Boundaries / Integrations

<every external system data crosses into/out of: which service, direction, what crosses, failure behavior.>

## Persistence Touchpoints

<where data is written/read and when — caches, queues, the database. Schema itself: [architecture.md](architecture.md#data-model).>

## See also

- [architecture.md](architecture.md) — topology + data model
- [index.md](index.md) — docs bundle
