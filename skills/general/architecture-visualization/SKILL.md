---
name: architecture-visualization
description: Render a system description or real codebase as a self-contained HTML/SVG diagram (architecture, workflow, sequence, data-flow, lifecycle) from a validated JSON IR. Use when asked to visualize or diagram a system.
scope: any
trigger: on-invoke
category: general
---

# Architecture Visualization

Generate beautiful architecture, workflow, sequence, data-flow, and lifecycle
diagrams from plain-English descriptions or from a real codebase. Inspired by
[archify](https://github.com/tt-a1i/archify): instead of hand-editing final SVG
or fragile Mermaid markup, you author a **typed JSON intermediate representation
(IR)**, a validator checks it, and a renderer emits a **zero-dependency HTML
file** with a light/dark theme toggle and PNG export.

## When to use

- "Visualize / diagram / draw the architecture of this system."
- "Show me the request flow / auth sequence / data pipeline."
- Producing the diagram that backs a `docs/architecture.md` or `docs/dataflow.md`
  (the committed doc set keeps its ASCII diagram; this skill adds a richer,
  exportable visual alongside it — see `${CLAUDE_PLUGIN_ROOT}/skills/practices/project-docs/SKILL.md`).
- Any time a picture communicates a topology or flow better than prose.

## The pipeline (do not skip steps)

```
describe/read → author IR (JSON) → validate → render → verify → iterate on the IR
```

1. **Author the IR.** Write a `.json` file matching `rules/ir-schema.md`. Pick the
   `type` that fits:

   | type | Use for |
   |------|---------|
   | `architecture` | System components, cloud resources, DBs, boundaries |
   | `workflow` | Request lifecycles, approval flows, CI/CD pipelines |
   | `sequence` | API call chains, cache fallback, auth flows (ordered messages) |
   | `dataflow` | ETL pipelines, PII isolation, warehouse sync |
   | `lifecycle` | State machines, task progression, retry paths |

2. **Validate + render** with the bundled script (stdlib Python, no installs):

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/skills/general/architecture-visualization/scripts/render.py" \
     diagram.json -o diagram.html
   ```

   Validate without rendering while drafting: add `--check`.

3. **Verify.** The renderer prints the canvas size and warns on degenerate or
   oversized layouts. Open the HTML (or `SendUserFile` it) to confirm it reads
   cleanly. If nodes overlap or the graph is too wide, adjust the IR — don't edit
   the HTML.

4. **Iterate on the IR**, never the output. Re-run the renderer after each change.

## Grounding the IR in a real codebase

When visualizing an existing project rather than a description:

- Derive **nodes** from real modules/services — read `package.json`, `go.mod`,
  `docker-compose.yml`, route files, the project's `docs/architecture.md`, and the
  live ADRs in `.coding-agent/product.md ## decisions` if present. Don't invent
  components.
- Derive **edges** from actual calls: imports, HTTP clients, DB connections,
  queue producers/consumers.
- Use **groups** for real boundaries (VPC, service, package, tier).
- Set **`tech`** to the real stack slug (`postgres`, `redis`, `aws.lambda`,
  `react`, `go`) so the diagram carries information, not decoration.

## Authoring guidance

- **Declare nodes in flow order.** Layered layout ranks nodes by longest path;
  ordering them source→sink yields the cleanest columns/rows.
- **One diagram, one story.** If a diagram exceeds ~15 nodes or the renderer warns
  about size, split it (e.g. one high-level architecture + one detailed sequence).
- **`dashed` edges** for optional/async/cache/fallback paths.
- **`sequence` edges are ordered** — they render top-to-bottom in array order.
- **Set a real `title`** — it names the header and the exported PNG file.

## Output

A single self-contained `.html` file:
- Inline SVG, no external requests (safe to open offline or attach).
- Theme toggle (button or `T`); follows `prefers-color-scheme`, persists choice.
- PNG export at 2× / 4× (button or `E`) — no upsampling blur.

Deliver it with `SendUserFile` (`display: "render"`) so the user sees it inline.

## Reference

- IR schema + field tables: `rules/ir-schema.md`
- Worked examples: `examples/architecture.json`, `examples/sequence.json`
- Renderer: `scripts/render.py` (`--check` to validate only)
