# Diagram IR Schema

The renderer consumes a single JSON object — the **intermediate representation (IR)**.
You author and edit the IR; you never hand-edit the generated HTML/SVG.

## Top-level fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `type` | string | ✔ | One of `architecture`, `workflow`, `dataflow`, `lifecycle`, `sequence`. |
| `title` | string | — | Shown in the header and used for the PNG filename. Default `"Diagram"`. |
| `direction` | string | — | `LR` (left→right) or `TB` (top→bottom). Ignored for `sequence`. Default: `LR` for `architecture`, `TB` for the other layered types. |
| `nodes` | array | ✔ | Non-empty. See below. |
| `edges` | array | — | May be empty. Order matters for `sequence` (messages render top→bottom in array order). |
| `groups` | array | — | Boundary boxes for `architecture` (and any layered type). |

## Node

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | string | ✔ | Unique. Referenced by edges and `node.group`. |
| `label` | string | — | Display text (wraps to ≤3 lines). Falls back to `id`. |
| `group` | string | — | Must match a declared `groups[].id`. Colors the node and draws the boundary. |
| `tech` | string | — | Small monospace tag under the label, e.g. `postgres`, `aws.lambda`, `react`, `redis`. Use semantic slugs. |

## Edge

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `from` | string | ✔ | Source node `id`. |
| `to` | string | ✔ | Target node `id`. |
| `label` | string | — | Text along the connector. |
| `style` | string | — | `dashed` for optional/async/cache paths; omit for a solid line. |

## Group

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | string | ✔ | Referenced by `node.group`. |
| `label` | string | — | Boundary caption (e.g. "Edge", "Data", "VPC"). |

Groups cycle through six accent colors in declaration order (both themes).

## Layout model

- **Layered types** (`architecture`, `workflow`, `dataflow`, `lifecycle`): nodes are
  ranked by longest path along the edges, then placed in columns (`LR`) or rows (`TB`).
  Declare nodes roughly in flow order for the cleanest result. Cycles are tolerated
  (back-edges just route from a later rank to an earlier one).
- **`sequence`**: each node is a lifeline placed left→right in declaration order;
  each edge is a message drawn top→bottom in array order. `from == to` renders a
  self-message loop.

## Validation & artifact check

`render.py` validates before rendering and refuses on:
- unknown `type`, empty `nodes`, missing/duplicate node `id`
- an edge `from`/`to` that names no node
- a `node.group` not declared in `groups`

After layout it warns (does not fail) on degenerate or oversized canvases — split a
diagram that grows past ~20000px instead of cramming everything into one.

## Minimal example

```json
{
  "type": "dataflow",
  "title": "ETL",
  "direction": "TB",
  "nodes": [
    { "id": "src", "label": "Source API", "tech": "rest" },
    { "id": "etl", "label": "ETL Job", "tech": "python" },
    { "id": "wh", "label": "Warehouse", "tech": "snowflake" }
  ],
  "edges": [
    { "from": "src", "to": "etl", "label": "poll" },
    { "from": "etl", "to": "wh", "label": "load" }
  ]
}
```
