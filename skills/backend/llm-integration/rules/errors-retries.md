# LLM-03: Error Handling and Retries (CRITICAL)

LLM APIs fail. Handle every error class.

## Retry Pattern

```typescript
import Anthropic from "@anthropic-ai/sdk";

async function callWithRetry(fn: () => Promise<any>, maxRetries = 3) {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      if (error instanceof Anthropic.RateLimitError) {
        // 429 -- back off exponentially
        const delay = Math.min(1000 * 2 ** attempt, 30000);
        await new Promise(r => setTimeout(r, delay));
        continue;
      }
      if (error instanceof Anthropic.APIConnectionError) {
        // Network failure -- retry
        if (attempt < maxRetries) continue;
      }
      if (error instanceof Anthropic.AuthenticationError) {
        // 401 -- bad API key, don't retry
        throw error;
      }
      if (error instanceof Anthropic.BadRequestError) {
        // 400 -- bad input (too many tokens, invalid model), don't retry
        throw error;
      }
      throw error; // Unknown error
    }
  }
}
```

## Error Classes by Provider

| Error | Anthropic | OpenAI | Action |
|-------|-----------|--------|--------|
| Rate limit | `RateLimitError` (429) | `RateLimitError` (429) | Exponential backoff, retry |
| Overloaded | `OverloadedError` (529) | `InternalServerError` (500) | Backoff, retry |
| Token limit | `BadRequestError` (400) | `BadRequestError` (400) | Reduce input, don't retry |
| Auth failure | `AuthenticationError` (401) | `AuthenticationError` (401) | Check key, don't retry |
| Network | `APIConnectionError` | `APIConnectionError` | Retry with backoff |

## Rules

- Always set timeouts. LLM calls can hang. Use AbortController or provider timeout options.
- Never retry auth errors or bad request errors -- they won't succeed.
- Log every error with: model, token count, error type, attempt number.
