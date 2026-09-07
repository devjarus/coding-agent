<!-- Optional component contract. Create only for a substantial boundary: a public API/event contract, independent data ownership, security boundary, complex failure behavior, or a module whose invariants are not obvious from code and tests. One component per file under docs/components/. Do not duplicate system topology, schema, flows, or visual tokens; link to their owning docs. -->

# <Component name>

> Detailed contract for this component. System placement and shared schema live in [../architecture.md](../architecture.md); end-to-end movement lives in [../dataflow.md](../dataflow.md).

## Responsibility

<What this component owns and explicitly does not own.>

## Public interface

| Interface | Input | Output | Compatibility promise |
|-----------|-------|--------|-----------------------|
| <API, event, function, protocol> | <shape/link> | <shape/link> | <stability/versioning rule> |

## Internal structure

```text
<small ASCII module/dependency diagram>
```

## Dependencies

| Dependency | Why it is needed | Failure behavior |
|------------|------------------|------------------|
| <component/service> | <reason> | <timeout/retry/degradation> |

## Invariants

- <A property that must remain true across implementations.>

## Failure and recovery

<Error propagation, retry/idempotency policy, degraded behavior, and recovery path.>

## Security boundary

<Authentication/authorization responsibility and sensitive-data handling, or "No independent security boundary.">

## Observability

<Logs, metrics, traces, and alerts that establish component health.>

## Test strategy

<Unit seam, real integration boundary, and any end-to-end flow that proves reachability.>

## Decisions

- <Link to the ADR or architecture decision that shaped this component.>

## See also

- [Architecture](../architecture.md)
- [Data flow](../dataflow.md)
- [Documentation index](../index.md)
