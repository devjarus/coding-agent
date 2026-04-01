# LLM-05: Caching (HIGH)

Cache identical requests to reduce cost and latency.

## Anthropic Prompt Caching

**Block-level caching** (mark specific content blocks):

```typescript
const response = await client.messages.create({
  model: "claude-sonnet-4-20250514",
  max_tokens: 1024,
  system: [
    {
      type: "text",
      text: longSystemPrompt,
      cache_control: { type: "ephemeral" }, // cache this block
    },
  ],
  messages,
});
// Subsequent calls with same system prompt use cached tokens (90% cheaper)
```

**Automatic caching mode** (simpler -- caches up to last cacheable block):

```python
response = client.messages.create(
    model="claude-opus-4-6",
    max_tokens=1024,
    cache_control={"type": "ephemeral"},  # automatic mode
    system="Long system prompt here...",
    messages=[...],
)
```

Default cache lifetime is 5 minutes. Extended 1-hour cache is available at extra cost. Cache reads are 90% cheaper than uncached input tokens.

## Application-Level Caching

```typescript
import { createHash } from "crypto";

function cacheKey(model: string, messages: Message[]): string {
  return createHash("sha256")
    .update(JSON.stringify({ model, messages }))
    .digest("hex");
}

async function cachedCompletion(model: string, messages: Message[]) {
  const key = cacheKey(model, messages);
  const cached = await redis.get(`llm:${key}`);
  if (cached) return JSON.parse(cached);

  const result = await client.messages.create({ model, max_tokens: 4096, messages });
  await redis.set(`llm:${key}`, JSON.stringify(result), "EX", 3600); // 1hr TTL
  return result;
}
```

## Rules

- Only cache deterministic calls (temperature=0 or identical prompts).
- Use short TTLs -- stale LLM responses degrade quickly.
- Never cache streaming responses -- cache the final result.
