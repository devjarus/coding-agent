# LLM-06: Observability (HIGH)

Track every LLM call. Debugging without traces is nearly impossible.

## What to Log

```typescript
interface LLMCallLog {
  timestamp: string;
  requestId: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
  totalTokens: number;
  latencyMs: number;
  costUsd: number;       // calculated from token counts
  status: "success" | "error";
  error?: string;
  cached: boolean;
  toolCalls?: string[];  // tool names invoked
}
```

## Wrapper Pattern

Wrap every LLM call to capture the `LLMCallLog` fields above. On success, compute cost from `result.usage`, check `cache_read_input_tokens > 0` for cache hits, and extract tool call names. On error, log `requestId`, model, error message, and latency. Always re-throw after logging.

## Platforms

| Platform | Integration | Best For | Notes |
|----------|-------------|----------|-------|
| **Langfuse** (RECOMMENDED) | Decorator/SDK | Default choice | Open-source (MIT), self-hostable, framework-agnostic |
| **Helicone** | Proxy (`baseURL`) | Cost tracking | Zero-code change -- just change base_url |
| **LangSmith** | `LANGCHAIN_TRACING_V2=true` | LangChain ecosystem | Only if deep in LangChain/LangGraph |
| **Braintrust** | SDK wrapper | Evals + datasets | Best for evaluation and dataset management |
| **OpenTelemetry** | Custom spans | Standard infra | When you already have OTel tracing |

## Langfuse Decorator Pattern (Python)

```python
from langfuse.decorators import observe

@observe()
def chat(messages):
    response = client.messages.create(model="claude-opus-4-6", max_tokens=1024, messages=messages)
    return response.content[0].text
```

## Helicone Proxy Pattern (Zero-Code Change)

```typescript
const client = new Anthropic({
  baseURL: "https://anthropic.helicone.ai",
  defaultHeaders: { "Helicone-Auth": `Bearer ${process.env.HELICONE_API_KEY}` },
});
// All calls are now logged in Helicone -- no other code changes needed
```
