# Thread Management, Attachments & Structured Output

## CHAT-03: Thread Management (HIGH)

Multiple conversations with TanStack Query for server state.

```tsx
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";

export const threadKeys = {
  all: ["threads"] as const,
  detail: (id: string) => ["threads", id] as const,
};

export function useThreads() {
  return useQuery({
    queryKey: threadKeys.all,
    queryFn: () => fetch("/api/threads").then(r => r.json()),
  });
}

export function useCreateThread() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => fetch("/api/threads", { method: "POST" }).then(r => r.json()),
    onSuccess: () => qc.invalidateQueries({ queryKey: threadKeys.all }),
  });
}

function ThreadSidebar({ activeId, onSelect }) {
  const { data: threads } = useThreads();
  return (
    <div className="w-64 border-r overflow-y-auto">
      {threads?.map(t => (
        <button
          key={t.id}
          onClick={() => onSelect(t.id)}
          className={cn("w-full text-left p-3", activeId === t.id && "bg-accent")}
        >
          <p className="text-sm font-medium truncate">{t.title || "New chat"}</p>
          <p className="text-xs text-muted-foreground">{timeAgo(t.updatedAt)}</p>
        </button>
      ))}
    </div>
  );
}
```

**Refresh after streaming completes:**
```tsx
useEffect(() => {
  if (chatHelpers.status === "ready" && prevStatus === "streaming") {
    setTimeout(() => {
      queryClient.invalidateQueries({ queryKey: threadKeys.all });
    }, 500);
  }
}, [chatHelpers.status]);
```

## CHAT-04: File Attachments (HIGH)

Support document and image uploads in the chat composer.

```tsx
import {
  CompositeAttachmentAdapter,
  SimpleImageAttachmentAdapter,
  SimpleTextAttachmentAdapter,
} from "@assistant-ui/react";

class BinaryDocumentAdapter {
  accept = "application/pdf,.pdf,.xlsx,.xls,image/*";

  async add(state) {
    return {
      id: state.file.name,
      type: "document",
      name: state.file.name,
      file: state.file,
      status: { type: "requires-action", reason: "composer-send" },
    };
  }

  async send(attachment) {
    const dataUrl = await readFileAsDataURL(attachment.file);
    return {
      ...attachment,
      status: { type: "complete" },
      content: [{
        type: "file",
        data: dataUrl,
        mimeType: attachment.file.type,
        filename: attachment.name,
      }],
    };
  }

  async remove() {}
}

const adapter = new CompositeAttachmentAdapter([
  new SimpleImageAttachmentAdapter(),
  new SimpleTextAttachmentAdapter(),
  new BinaryDocumentAdapter(),
]);

const runtime = useAISDKRuntime(chatHelpers, {
  adapters: { attachments: adapter },
});
```

## CHAT-05: JSON Render for Structured Output (HIGH)

When the LLM returns structured data, render it as rich UI using json-render.

```tsx
import { defineRegistry, Renderer } from "@json-render/react";
import { shadcnCatalog } from "@json-render/shadcn";

const { registry } = defineRegistry(shadcnCatalog, {
  components: {
    CustomMetric: ({ props }) => (
      <div className="p-4 rounded-lg bg-card">
        <p className="text-2xl font-bold">{props.value}</p>
        <p className="text-sm text-muted-foreground">{props.label}</p>
      </div>
    ),
  },
});

function StructuredResult({ spec }) {
  if (!spec) return null;
  return <Renderer spec={spec} registry={registry} />;
}
```

## CHAT-06: App Layout (MEDIUM)

```tsx
function AssistantApp() {
  const [activeThreadId, setActiveThreadId] = useState(null);

  return (
    <QueryClientProvider client={queryClient}>
      <div className="flex h-screen">
        <ThreadSidebar activeId={activeThreadId} onSelect={setActiveThreadId} />
        <ChatRuntimeProvider activeThreadId={activeThreadId}>
          <AllToolUIs />
          <div className="flex-1 flex flex-col">
            <Thread />
          </div>
        </ChatRuntimeProvider>
      </div>
    </QueryClientProvider>
  );
}
```
