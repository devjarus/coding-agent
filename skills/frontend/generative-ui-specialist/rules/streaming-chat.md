# GEN-03: Streaming Chat with Tool Visualization (HIGH)

Show tool execution in real-time with typed tool parts (AI SDK 6 pattern).

```tsx
"use client";
import { useChat } from "@ai-sdk/react";
import {
  DefaultChatTransport,
  lastAssistantMessageIsCompleteWithToolCalls,
} from "ai";

export default function AgentChat() {
  const { messages, sendMessage, addToolOutput } = useChat({
    transport: new DefaultChatTransport({ api: "/api/chat" }),
    sendAutomaticallyWhen: lastAssistantMessageIsCompleteWithToolCalls,

    async onToolCall({ toolCall }) {
      if (toolCall.dynamic) return; // check dynamic tools first
      if (toolCall.toolName === "getLocation") {
        const cities = ["New York", "Los Angeles", "Chicago"];
        addToolOutput({
          tool: "getLocation",
          toolCallId: toolCall.toolCallId,
          output: cities[Math.floor(Math.random() * cities.length)],
        });
      }
    },
  });

  return (
    <div className="flex flex-col gap-4">
      {messages.map((m) => (
        <div key={m.id}>
          {m.parts.map((part) => {
            switch (part.type) {
              case "text": return <Markdown key="text">{part.text}</Markdown>;
              case "tool-askForConfirmation":
                return <ConfirmationCard key={part.toolCallId} part={part}
                  onConfirm={() => addToolOutput({
                    tool: "askForConfirmation",
                    toolCallId: part.toolCallId,
                    output: "Yes, confirmed.",
                  })} />;
              default:
                if (part.type.startsWith("tool-")) {
                  return <ToolCard key={part.toolCallId} part={part} />;
                }
            }
          })}
        </div>
      ))}
    </div>
  );
}
```

## Component library for agent UIs

Every agent UI needs these components. Use shadcn/ui as the base:

| Component | Purpose | shadcn base |
|-----------|---------|-------------|
| `ChatMessage` | Render user/assistant messages with markdown | Card |
| `ToolCard` | Show tool invocations with typed status | Card + Badge |
| `StreamingText` | Progressively render streamed text | -- (custom) |
| `ApprovalCard` | Human-in-the-loop approval (needsApproval) | Alert + Button |
| `AgentStatus` | Show agent state (thinking/acting/done) | Badge |
| `StepProgress` | Multi-step agent progress | -- (custom) |
| `CodeBlock` | Syntax-highlighted code in responses | -- (use shiki/prism) |
| `DataTable` | Structured data from tool results | Table |
| `ErrorCard` | Agent error display with retry | Alert |
| `SkeletonLoader` | Loading states matching content shape | Skeleton |
