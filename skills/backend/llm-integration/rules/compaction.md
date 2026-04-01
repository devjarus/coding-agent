# LLM-04: Context Window and Compaction (HIGH)

Every model has a context limit. Manage it or the call fails.

## Token Counting

```typescript
// Anthropic -- use the count_tokens API
const count = await client.messages.count_tokens({
  model: "claude-sonnet-4-20250514",
  messages,
});
console.log(`Input tokens: ${count.input_tokens}`);

// OpenAI -- use tiktoken
import { encoding_for_model } from "tiktoken";
const enc = encoding_for_model("gpt-4o");
const tokens = enc.encode(text).length;
```

## Hybrid Compaction (Recommended)

Combine sliding window, summarization, caching, and structured memory:

```typescript
async function compactHistory(messages: Message[], opts: {
  windowSize?: number;  // keep last N turns verbatim (default: 15)
  tokenThreshold: number;
}): Promise<Message[]> {
  const { windowSize = 15, tokenThreshold } = opts;
  const tokenCount = await countTokens(messages);
  if (tokenCount < tokenThreshold) return messages;

  // 1. Sliding window: keep last N turns verbatim
  const system = messages.filter(m => m.role === "system");
  const recent = messages.slice(-windowSize);
  const old = messages.slice(0, -windowSize);

  // 2. Summarize everything before the window with a cheap model
  const summary = await client.messages.create({
    model: "claude-haiku-4-5-20251001",
    max_tokens: 500,
    messages: [{ role: "user", content: `Summarize this conversation concisely, preserving key facts, decisions, and open questions:\n${formatMessages(old)}` }],
  });

  // 3. Use prompt caching on the summary block (it rarely changes)
  return [
    ...system,
    { role: "user", content: [{ type: "text", text: `Previous conversation summary: ${summary.content[0].text}`, cache_control: { type: "ephemeral" } }] },
    { role: "assistant", content: "Understood, I have the conversation context." },
    ...recent,
  ];
}
```

## Compaction Principles

- **Prevention over compression** -- write concise prompts and fetch context on-demand via tools rather than stuffing everything into the conversation.
- Keep last 10-20 turns verbatim (sliding window) so the model has full fidelity on recent work.
- Summarize everything before the window with Haiku (cheap, fast).
- Use prompt caching on the summary block -- it changes infrequently.
- Track key facts (user preferences, decisions, constraints) in structured memory outside the conversation (database, file) so they survive compaction.

## Chunked Processing

For large documents, split into chunks by paragraph boundary, keeping each chunk under the token limit. Process chunks independently and merge results.
