# GEN-02: JSON-Based Component Rendering (CRITICAL)

**json-render framework** (`@json-render/core` + `@json-render/react`): guardrailed, cross-platform JSON-to-UI rendering. Ships 36 pre-built shadcn/ui components.

## json-render catalog + registry

```typescript
import { defineCatalog } from "@json-render/core";
import { schema } from "@json-render/react/schema";
import { defineRegistry, Renderer } from "@json-render/react";
import { z } from "zod";

// 1. Define catalog (what AI can use)
const catalog = defineCatalog(schema, {
  components: {
    Card: {
      props: z.object({ title: z.string() }),
      description: "A card container",
    },
    Metric: {
      props: z.object({
        label: z.string(),
        value: z.string(),
        format: z.enum(["currency", "percent", "number"]).nullable(),
      }),
      description: "Display a metric value",
    },
  },
  actions: {
    export_report: { description: "Export dashboard to PDF" },
  },
});

// 2. Define registry (how to render)
const { registry } = defineRegistry(catalog, {
  components: {
    Card: ({ props, children }) => (
      <div className="card"><h3>{props.title}</h3>{children}</div>
    ),
    Metric: ({ props }) => (
      <div className="metric"><span>{props.label}</span>: {props.value}</div>
    ),
  },
});

// 3. Render AI-generated spec
function Dashboard({ spec }) {
  return <Renderer spec={spec} registry={registry} />;
}
```

## Spec format (flat, element-referenced)

```typescript
const spec = {
  root: "card-1",
  elements: {
    "card-1": { type: "Card", props: { title: "Hello" }, children: ["metric-1"] },
    "metric-1": { type: "Metric", props: { label: "Revenue", value: "$1.2M", format: "currency" }, children: [] },
  },
};
```

## Custom registry approach (no framework dependency)

```typescript
const componentRegistry: Record<string, React.ComponentType<any>> = {
  "weather-card": WeatherCard,
  "stock-chart": StockChart,
  "data-table": DataTable,
};

interface UIBlock {
  component: string;
  props: Record<string, any>;
  children?: UIBlock[];
}

function RenderBlock({ block }: { block: UIBlock }) {
  const Component = componentRegistry[block.component];
  if (!Component) return <FallbackCard type={block.component} />;
  return (
    <Component {...block.props}>
      {block.children?.map((child, i) => <RenderBlock key={i} block={child} />)}
    </Component>
  );
}
```
