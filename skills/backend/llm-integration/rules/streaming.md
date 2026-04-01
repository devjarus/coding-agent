# LLM-02: Streaming (CRITICAL)

Always stream responses for user-facing features. Never block the UI waiting for a full response.

## Anthropic Streaming

```typescript
const stream = client.messages.stream({
  model: "claude-sonnet-4-20250514",
  max_tokens: 4096,
  messages,
});

for await (const event of stream) {
  if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
    process.stdout.write(event.delta.text);
  }
}
```

## OpenAI Streaming

```typescript
const stream = await client.chat.completions.create({
  model: "gpt-4o",
  messages,
  stream: true,
});

for await (const chunk of stream) {
  const text = chunk.choices[0]?.delta?.content;
  if (text) process.stdout.write(text);
}
```

## Vercel AI SDK Streaming (Server Action -- v6)

```typescript
// Server Action (v6 pattern -- replaces API routes)
"use server";
import { streamText } from "ai";
import { anthropic } from "@ai-sdk/anthropic";

export async function chat(messages: Message[]) {
  const result = streamText({
    model: anthropic("claude-sonnet-4-20250514"),
    messages,
  });
  return result.toUIMessageStreamResponse();
}
```

## Server-Sent Events (SSE) Pattern

```typescript
// Express SSE endpoint
app.post("/api/chat", async (req, res) => {
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");

  const stream = client.messages.stream({ model, max_tokens, messages });

  for await (const event of stream) {
    if (event.type === "content_block_delta") {
      res.write(`data: ${JSON.stringify({ text: event.delta.text })}\n\n`);
    }
  }
  res.write("data: [DONE]\n\n");
  res.end();
});
```
