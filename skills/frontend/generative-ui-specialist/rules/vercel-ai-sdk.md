# GEN-01: Vercel AI SDK Generative UI (CRITICAL)

The Vercel AI SDK v6 (`ai` package) provides first-class support for streaming React components via agents and tools. Key imports: `ai`, `@ai-sdk/react`, `@ai-sdk/anthropic`.

## Agent-based approach (AI SDK 6)

```typescript
// agents/weather-agent.ts
import { ToolLoopAgent, InferAgentUIMessage, tool, stepCountIs } from "ai";
import { z } from "zod";

export const weatherAgent = new ToolLoopAgent({
  model: "anthropic/claude-sonnet-4.5",
  instructions: "You are a helpful weather assistant.",
  tools: {
    weather: tool({
      description: "Get the weather in a location",
      inputSchema: z.object({
        location: z.string().describe("The location to get the weather for"),
      }),
      execute: async ({ location }) => ({
        location,
        temperature: 72 + Math.floor(Math.random() * 21) - 10,
      }),
    }),
  },
  stopWhen: stepCountIs(10),
});

export type WeatherAgentUIMessage = InferAgentUIMessage<typeof weatherAgent>;
```

## API route

```typescript
// app/api/chat/route.ts
import { createAgentUIStreamResponse } from "ai";
import { weatherAgent } from "@/agents/weather-agent";

export async function POST(request: Request) {
  const { messages } = await request.json();
  return createAgentUIStreamResponse({
    agent: weatherAgent,
    uiMessages: messages,
  });
}
```

## Client-side (typed tool parts)

```tsx
"use client";
import { useChat } from "@ai-sdk/react";
import type { WeatherAgentUIMessage } from "@/agents/weather-agent";

export default function Chat() {
  const { messages, sendMessage } = useChat<WeatherAgentUIMessage>();

  return (
    <div>
      {messages.map((message) =>
        message.parts.map((part) => {
          switch (part.type) {
            case "text": return <span key={part.text}>{part.text}</span>;
            case "tool-weather":
              return <WeatherCard invocation={part} />;
          }
        })
      )}
    </div>
  );
}
```

## Key AI SDK 6 changes

- `ToolLoopAgent` -- reusable agent with model, instructions, tools
- `InferAgentUIMessage` -- infers typed UI message from agent definition
- `createAgentUIStreamResponse` -- server-side agent-to-UI stream
- `tool()` helper with `inputSchema` (replaces `parameters`)
- `stopWhen: stepCountIs(n)` -- replaces `maxSteps`
- `needsApproval: true` on tools -- human-in-the-loop approval
- `toUIMessageStreamResponse()` -- replaces `toDataStreamResponse()`
- Client: `message.parts` array with typed `tool-<name>` parts
- Client: `sendMessage`, `addToolOutput` on `useChat`

## Streaming with streamText (functional approach)

```typescript
import { convertToModelMessages, streamText, UIMessage } from "ai";
import { anthropic } from "@ai-sdk/anthropic";
import { z } from "zod";

export async function POST(req: Request) {
  const { messages }: { messages: UIMessage[] } = await req.json();

  const result = streamText({
    model: anthropic("claude-sonnet-4-20250514"),
    messages: await convertToModelMessages(messages),
    tools: {
      getWeather: {
        description: "Show the weather in a given city",
        inputSchema: z.object({ city: z.string() }),
        execute: async ({ city }) => {
          const options = ["sunny", "cloudy", "rainy", "snowy"];
          return options[Math.floor(Math.random() * options.length)];
        },
      },
    },
  });

  return result.toUIMessageStreamResponse();
}
```

## GEN-04: Structured Output for UI

Use `generateObject` / `streamObject` for guaranteed schema-compliant UI data:

```typescript
import { generateObject, streamObject } from "ai";
import { anthropic } from "@ai-sdk/anthropic";
import { z } from "zod";

const DashboardSchema = z.object({
  title: z.string(),
  sections: z.array(z.object({
    heading: z.string(),
    type: z.enum(["stats", "chart", "table", "list"]),
    data: z.any(),
  })),
});

// One-shot generation
const { object: dashboard } = await generateObject({
  model: anthropic("claude-sonnet-4-20250514"),
  schema: DashboardSchema,
  prompt: "Generate a project management dashboard.",
});

// Streaming (progressive rendering)
const { partialObjectStream } = streamObject({
  model: anthropic("claude-sonnet-4-20250514"),
  schema: DashboardSchema,
  prompt: "Generate a project dashboard...",
});
for await (const partial of partialObjectStream) {
  renderDashboard(partial); // render as fields arrive
}
```
