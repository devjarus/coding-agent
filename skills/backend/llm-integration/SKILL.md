---
name: llm-integration
description: Best practices for integrating LLM providers (Anthropic, OpenAI, Google, AWS Bedrock, Ollama) into backend applications. Covers client setup, streaming, error handling, token management, context compaction, caching, observability, cost control, and provider abstraction. Use when connecting any backend to an LLM API.
---

# LLM Integration

## When to Apply

- Connecting a backend to any LLM provider API
- Implementing streaming chat or completion endpoints
- Managing token limits, context windows, or caching
- Adding LLM observability or cost tracking

## Rules

**CRITICAL:**
- **LLM-01 Provider setup** -- env vars for keys, pin model versions, configurable model ID. See [rules/providers.md](rules/providers.md)
- **LLM-02 Streaming** -- always stream user-facing responses. See [rules/streaming.md](rules/streaming.md)
- **LLM-03 Errors and retries** -- exponential backoff on 429/529, never retry 401/400, always set timeouts. See [rules/errors-retries.md](rules/errors-retries.md)

**HIGH:**
- **LLM-04 Context compaction** -- count tokens, sliding window + summarization, chunk large docs. See [rules/compaction.md](rules/compaction.md)
- **LLM-05 Caching** -- Anthropic prompt caching (90% cheaper), app-level cache with short TTLs. See [rules/caching.md](rules/caching.md)
- **LLM-06 Observability** -- log every call (model, tokens, latency, cost); use Langfuse or Helicone. See [rules/observability.md](rules/observability.md)
- **LLM-07 Cost control** -- cheapest model that works, cache system prompts, batch API. See [rules/cost.md](rules/cost.md)

**MEDIUM:**
- **LLM-08 Provider abstraction** -- use Vercel AI SDK or thin wrapper for multi-provider. See [rules/cost.md](rules/cost.md)

## Anti-Patterns

- Hardcoded API keys -- always use environment variables
- No timeout -- LLM calls can hang for minutes
- Retrying auth errors -- 401/403 won't succeed on retry
- Ignoring token counts -- leads to context window overflows
- No cost tracking -- runaway loops can burn hundreds of dollars
- Synchronous calls in request handlers -- blocks the event loop
- Storing raw API responses in DB -- extract what you need, discard the rest
