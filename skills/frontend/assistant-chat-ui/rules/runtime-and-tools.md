# Runtime Provider & Tool UI Registration

## CHAT-01: Runtime Provider Setup (CRITICAL)

The foundation -- bridges Vercel AI SDK's `useChat` with assistant-ui's runtime system.

```tsx
import { useChat } from "@ai-sdk/react";
import { DefaultChatTransport } from "ai";
import { useAISDKRuntime } from "@assistant-ui/react-ai-sdk";
import { AssistantRuntimeProvider } from "@assistant-ui/react";

export function ChatRuntimeProvider({ activeThreadId, children }) {
  // Transport -- configures how messages reach the server
  const chatTransport = useMemo(
    () => new DefaultChatTransport({
      api: "/api/chat",
      body: () => ({ sessionId: activeThreadId }),
      // Send only the last message -- server loads history from DB
      prepareSendMessagesRequest: (opts) => ({
        body: { ...opts.body, messages: opts.messages.slice(-1) },
      }),
    }),
    []
  );

  // useChat -- manages message state and streaming
  const chatHelpers = useChat({
    transport: chatTransport,
    onError: (error) => {
      const msg = error instanceof Error ? error.message : String(error);
      if (msg.includes("Failed to fetch")) toast.error("Cannot reach AI provider");
      else if (msg.includes("401")) toast.error("Invalid API key");
      else toast.error(msg.slice(0, 200));
    },
  });

  // Bridge to assistant-ui runtime
  const runtime = useAISDKRuntime(chatHelpers);

  return (
    <AssistantRuntimeProvider runtime={runtime}>
      {children}
    </AssistantRuntimeProvider>
  );
}
```

**Key patterns:**
- `DefaultChatTransport` customizes the fetch (auth, headers, body)
- `prepareSendMessagesRequest` sends only the last message if server has history
- `useAISDKRuntime` bridges useChat state -> assistant-ui components
- `AssistantRuntimeProvider` wraps the entire chat UI tree

## CHAT-02: Tool UI Registration (CRITICAL)

Every tool the LLM can call gets a corresponding UI component.

```tsx
import { makeAssistantToolUI } from "@assistant-ui/react";

function mapStatus(status) {
  if (!status) return "complete";
  switch (status.type) {
    case "running": return "loading";
    case "complete": return "complete";
    case "incomplete": return "error";
    default: return "complete";
  }
}

export const SearchToolUI = makeAssistantToolUI({
  toolName: "web_search",
  render: ({ args, result, status }) => (
    <SearchResults
      state={mapStatus(status)}
      query={args.query}
      results={result?.results}
    />
  ),
});

// Collect all tool UIs -- render inside AssistantRuntimeProvider
export const AllToolUIs = () => (
  <>
    <SearchToolUI />
    <TaskListToolUI />
  </>
);
```

**Pattern for each tool UI:**
1. `makeAssistantToolUI({ toolName, render })` -- toolName matches backend tool name exactly
2. `render` receives `args` (tool input), `result` (tool output), `status` (running/complete/error)
3. Map status -> your component's loading/complete/error states
4. Render inside `<AssistantRuntimeProvider>` to register
