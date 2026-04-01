# GEN-05: Agent UI Ecosystems (HIGH)

## CopilotKit

`@copilotkit/react-core`, `@copilotkit/react-ui` -- framework for AI copilots with three generative UI patterns:

### 1. Static GenUI (AG-UI protocol)

Pre-built components, agent selects + fills data:

```tsx
import { useFrontendTool } from "@copilotkit/react-core";

useFrontendTool({
  name: "get_weather",
  description: "Get current weather information",
  parameters: z.object({ location: z.string() }),
  handler: async ({ location }) => {
    return getMockWeather(location);
  },
  render: ({ status, args, result }) => {
    if (status === "inProgress" || status === "executing") {
      return <WeatherLoadingState location={args?.location} />;
    }
    if (status === "complete" && result) {
      return <WeatherCard data={JSON.parse(result)} />;
    }
    return null;
  },
});
```

### 2. Declarative GenUI (A2UI / Open-JSON-UI)

Agent returns structured UI spec, frontend renders with constraints.

### 3. Open-ended GenUI (MCP Apps)

Agent returns full UI surface, maximum flexibility.

## assistant-ui

`@assistant-ui/react` -- open-source ChatGPT-like UI. 350K+ weekly downloads. Built on shadcn/ui + Vercel AI SDK. Provides streaming, markdown, code highlighting, file attachments, and generative UI out of the box.

```bash
npm install @assistant-ui/react
```

## A2UI (Google)

JSONL-based protocol for agent-driven interfaces. Agents describe UI as structured widgets (forms, lists, cards). Platform-agnostic.

## Tambo AI

`@tambo-ai/react` -- full-stack React SDK that lets AI agents render interactive components instead of text.
