---
name: agent-ui-rendering
description: LLM-driven UI via typed JSON spec. For AI agents that produce rich output (reports, dashboards, tool results) beyond markdown. Uses @json-render with a Zod-validated catalog. Not for general product UI.
---

# Agent UI Rendering

When an AI agent produces output that's richer than markdown — research reports, stock/flight tool results, dashboards, multi-step summaries with charts — you have two bad options and one good one:

1. **Return markdown** → lossy for tables, charts, interactive elements
2. **Let the LLM emit arbitrary JSX/HTML** → injection risk, unbounded surface, hallucinated components
3. **Typed JSON spec rendered against a constrained catalog** ← this skill

The LLM emits a JSON spec using only components from a catalog you define. A renderer maps spec → React. Zod validates the spec before rendering. Components you didn't register can't be rendered. State and actions flow through providers, not arbitrary code.

## When to Use

- ✅ AI agent where the LLM decides what to show (research agent, assistant with tools, swarm summarizer)
- ✅ Output structure varies per query — one report is a timeline, another is a comparison table
- ✅ You want consistent look-and-feel across LLM-generated outputs
- ✅ You want to constrain what the LLM can produce (safety, brand, a11y)

## When NOT to Use

- ❌ Static product UI where a designer owns the layout — just build normal React
- ❌ Dashboards where the shape is known at build time — schema-first is simpler
- ❌ Markdown-only chat responses — don't reach for this for a paragraph answer
- ❌ Forms the user fills in — use a form library, not a JSON renderer

This skill is for the specific case of **LLM-as-UI-author**. Most UI is not that.

## Stack

```json
{
  "dependencies": {
    "@json-render/core": "^0.11.0",
    "@json-render/react": "^0.11.0",
    "@json-render/shadcn": "^0.11.0",
    "zod": "^3"
  }
}
```

`@json-render/shadcn` is optional — a preset catalog wired to shadcn/ui components. Use it as a starting point, then extend.

## The Three Pieces

### 1. Catalog — what components the LLM may use

```ts
// render-catalog.ts
import { defineCatalog } from "@json-render/core";
import { schema } from "@json-render/react/schema";
import { z } from "zod";

export const resultCatalog = defineCatalog(schema, {
  components: {
    Section: {
      props: z.object({
        title: z.string(),
        subtitle: z.string().nullable(),
        collapsible: z.boolean().nullable(),
        defaultOpen: z.boolean().nullable(),
      }),
      slots: ["default"],
      description: "A titled section that groups related content.",
    },
    MetricCard: {
      props: z.object({
        label: z.string(),
        value: z.string(),
        unit: z.string().nullable(),
        trend: z.enum(["up", "down", "neutral"]).nullable(),
      }),
      description: "Single metric display. Use for prices, counts, KPIs.",
    },
    DataTable: {
      props: z.object({
        columns: z.array(z.object({ key: z.string(), label: z.string() })),
        rows: z.array(z.record(z.unknown())),
      }),
      description: "Tabular data.",
    },
    // ... Chart, Timeline, Grid, Stack, etc.
  },
});
```

The `description` strings are the LLM's user manual — they appear in the system prompt. Write them as instructions to the model, not as doc comments.

### 2. Registry — how each component actually renders

```tsx
// render-registry.tsx
import { defineRegistry } from "@json-render/react";
import { resultCatalog } from "./render-catalog";

export const { registry, handlers, executeAction } = defineRegistry(resultCatalog, {
  components: {
    Section: ({ props, children }) => (
      <section className="rounded-lg border p-4">
        <h3 className="font-semibold">{props.title}</h3>
        {props.subtitle && <p className="text-sm text-muted">{props.subtitle}</p>}
        <div className="mt-2">{children}</div>
      </section>
    ),
    MetricCard: ({ props }) => <div>{/* ... */}</div>,
    DataTable: ({ props }) => <table>{/* ... */}</table>,
  },
});
```

Registry separates *what the LLM can request* (catalog) from *how it looks* (registry). Ship a new theme without touching prompts.

### 3. Renderer — the fallback chain

```tsx
// ResultRenderer.tsx
import { Renderer, StateProvider, ActionProvider } from "@json-render/react";
import { registry, handlers } from "./render-registry";

export function ResultRenderer({ spec, markdown }: Props) {
  const parsed = parseSpec(spec); // returns null on invalid JSON or shape

  if (parsed) {
    return (
      <StateProvider initialState={{}}>
        <ActionProvider handlers={handlers(...)}>
          <Renderer spec={parsed} registry={registry} />
        </ActionProvider>
      </StateProvider>
    );
  }
  if (markdown) return <MarkdownContent content={markdown} />;
  return <EmptyState />;
}
```

**Always provide a fallback chain.** LLMs produce invalid specs sometimes. Your options:
1. Valid spec → render it
2. Markdown fallback → render as prose
3. Nothing → show an empty state

Never show raw JSON to users. If the spec is malformed, degrade gracefully.

## Prompting the LLM

The LLM needs to know (a) the catalog and (b) that it must output valid JSON. Two approaches:

### A. System-prompt injection (simple)

Generate the catalog description at build time, paste into the system prompt:

```ts
const catalogDocs = Object.entries(resultCatalog.components)
  .map(([name, def]) => `- ${name}: ${def.description}`)
  .join("\n");

const systemPrompt = `Output a JSON object matching this shape: { root: string, elements: Record<string, Element> }
Available components:
${catalogDocs}
Example: { root: "r1", elements: { r1: { type: "Section", props: { title: "..." }, children: [...] } } }`;
```

### B. Structured output (better when supported)

Use the model's JSON mode / structured output feature with the catalog's Zod schemas converted to JSON Schema. The model is then forced to emit valid shapes. Prefer this when your model supports it — it eliminates parse failures.

## Interactivity: State + Actions

Static rendering is most of the value. But when the LLM wants a "Show more" button, filter dropdown, or tab switcher, use providers — not arbitrary code:

- **StateProvider** — holds spec-scoped state. Elements read via `{{stateKey}}` bindings.
- **ActionProvider** — maps action names (`toggleSection`, `filterTable`) to handlers *you* implement. The LLM references action names; it can't define handlers.
- **VisibilityProvider** — declarative show/hide based on state.

This is the safety boundary: the LLM can *request* interactivity from a fixed menu of actions. It cannot *author* interactivity.

## Artifacts and Media

If your agent produces images, charts, or files, pass them alongside the spec. In the personal-ai pattern, artifact IDs are passed in spec props (`<Image src="/api/artifacts/abc123" />`), and the renderer extracts referenced IDs to deduplicate with a separate gallery fallback.

## Rules

1. **Typed catalog is the contract.** Every component's props must be a Zod schema. No free-form props. The model learns the catalog from Zod → schema → prompt.
2. **Registry is separate from catalog.** You can re-theme without changing what the LLM knows about. This also lets you A/B test UI without re-prompting.
3. **Always have a markdown fallback.** Invalid spec → render markdown. Never show raw JSON.
4. **Sanitize before fallback.** If the LLM accidentally returned JSON as text (no code fences, no spec shape), detect it and convert to markdown instead of dumping JSON to the user. See `sanitizeMarkdown` pattern in personal-ai.
5. **State and actions go through providers.** Never `eval` or `new Function` anything from the spec. Actions are named references to handlers you register.
6. **Keep the catalog small.** 10-20 components covers most agent output. A 100-component catalog makes prompts huge and gives the LLM too many foot-guns.
7. **Reference images by artifact ID, not base64.** Keeps the spec small and cacheable.
8. **This is not a general UI framework.** Don't port the whole app to json-render. Use it only for the LLM-generated surface.

## Reference Implementation

Personal-ai (`packages/ui/src/`):
- `lib/render-catalog.ts` — ~15-component catalog with Zod schemas
- `lib/render-registry.tsx` — React implementations with shadcn + lucide
- `components/results/ResultRenderer.tsx` — fallback chain + debug toggle
- `components/tools/Tool*.tsx` — per-tool wrappers that produce specs

The `Tool*` files are worth reading: each tool has its own wrapper that decides when to render via spec vs. fall back to a custom React component. Specs are for LLM-authored output; custom components are for tool-authored output with known shape.

## Why This Beats Alternatives

| Alternative | Problem |
|-------------|--------|
| LLM returns JSX string, eval at runtime | Injection, hallucinated components, no types |
| LLM returns markdown + frontmatter | Lossy, no interactivity, hard to theme |
| Custom renderer per tool | Works but doesn't compose; LLM can't mix components across tools |
| Vercel AI SDK `streamUI` / generative UI | Good for streaming, but ties you to specific models and runtime; `json-render` works with any model that can produce JSON |

json-render is the lightweight, model-agnostic choice when you want a constrained, typed, themeable surface for LLM-authored UI.
