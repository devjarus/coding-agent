# LLM-07: Cost Control (HIGH)

## Pricing Reference

```typescript
// Model pricing per 1M tokens (March 2026)
const COST_PER_1M = {
  "claude-opus-4-6":             { input: 5.00,  output: 25.00 },
  "claude-sonnet-4-20250514":    { input: 3.00,  output: 15.00 },
  "claude-haiku-4-5-20251001":   { input: 1.00,  output: 5.00  },
  "gpt-4o":                      { input: 2.50,  output: 10.00 },
  "gpt-4o-mini":                 { input: 0.15,  output: 0.60  },
};

function calculateCost(model: string, usage: { input_tokens: number; output_tokens: number }): number {
  const rates = COST_PER_1M[model];
  if (!rates) return 0;
  return (usage.input_tokens / 1_000_000) * rates.input + (usage.output_tokens / 1_000_000) * rates.output;
}
```

## Cost Reduction Strategies

- Use the cheapest model that works. Haiku for classification/routing, Sonnet for generation, Opus for complex reasoning.
- Cache system prompts with `cache_control` (Anthropic) -- 90% cheaper on cache hits.
- Batch non-urgent requests with Anthropic's Batch API (50% discount).
- Set `max_tokens` to a reasonable limit -- don't default to max.
- Trim conversation history before it fills the context window.

## LLM-08: Provider Abstraction (MEDIUM)

If your app might switch providers, abstract early:

```typescript
interface LLMClient {
  complete(params: {
    model: string;
    messages: { role: string; content: string }[];
    maxTokens: number;
    temperature?: number;
    stream?: boolean;
  }): Promise<{ text: string; usage: { inputTokens: number; outputTokens: number } }>;
}

// Or just use Vercel AI SDK -- it already abstracts this:
import { generateText, tool } from "ai";
import { anthropic } from "@ai-sdk/anthropic";

// Switch provider by changing one import + one line
const result = await generateText({
  model: anthropic("claude-sonnet-4-20250514"),
  prompt: "Hello",
});
```

**When to abstract:** If you're already using Vercel AI SDK, don't build your own abstraction. If you're using raw provider SDKs and might switch, create a thin wrapper.
