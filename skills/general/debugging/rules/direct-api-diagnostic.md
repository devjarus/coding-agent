# Direct-API Diagnostic Test

When a framework layer is opaque and you're getting nowhere, bypass the framework and hit the provider's native API directly. Ground truth from 5 minutes of curl beats hours of framework-layer speculation.

## When to Use

- An agent framework (LangChain, deepagents, llamaindex, etc.) appears to ignore tools, drop fields, or misbehave
- The logs show the framework running but the model produces wrong/empty output
- You suspect the framework is swallowing a provider capability
- The docs say X should work but X isn't working

## The Pattern

Identify the layer just below the framework. For LLM agent bugs this is almost always the provider's REST API. Send the same request the framework claims to send, but via `curl`, and compare outputs.

### Example — "my model isn't calling tools in langchain"

**Framework output (unhelpful):** Agent ran for 14s, produced conversational text, zero `tool_calls`.

**Direct-API test:**

```bash
curl http://localhost:11434/api/chat -d '{
  "model": "gemma4",
  "messages": [{"role": "user", "content": "What is WebGPU?"}],
  "tools": [{
    "type": "function",
    "function": {
      "name": "web_search",
      "description": "Search the web for information",
      "parameters": {
        "type": "object",
        "properties": {"query": {"type": "string"}},
        "required": ["query"]
      }
    }
  }],
  "stream": false
}'
```

**Result:** Model returns `{"message": {"tool_calls": [{"function": {"name": "web_search", "arguments": {"query": "WebGPU"}}}]}}` in under 1 second.

**Diagnosis:** The model is fine. The framework layer above (langchain/deepagents orchestrator prompt + tool surface) is the problem, not the model. Now you know where to look.

## Other Provider Endpoints

| Provider | Direct-API Endpoint |
|----------|--------------------|
| Ollama | `POST http://localhost:11434/api/chat` |
| Anthropic | `POST https://api.anthropic.com/v1/messages` |
| OpenAI | `POST https://api.openai.com/v1/chat/completions` |
| Any OpenAI-compatible | `POST {baseUrl}/chat/completions` |

For non-LLM systems, the same principle applies: curl the backing HTTP API, hit the DB directly with `psql`, open a redis-cli, etc. Go one layer below the framework you're debugging.

## Why This Works

Frameworks introduce layers: adapters, serialization, system prompts, tool reformatting, response parsing. Any one of those layers can silently drop fields or mangle inputs. When you hit the raw provider API, you eliminate all of those layers at once. If the raw API works, the bug is in the framework. If it doesn't, the bug is in your request or the provider.

This is much faster than instrumenting the framework, reading framework source, or asking the framework's maintainers.

## Rules

1. **Always run a direct-API test** before reading framework internals. It's faster and more definitive.
2. **Match the exact request the framework sends** — same model name, same tools array, same messages. If the direct call works and the framework call doesn't, the delta is in the framework.
3. **Save the curl command** in the bug report or learnings file. It's reusable.
4. **Don't skip this for "well-known" frameworks.** The well-known ones have the most layers and the most surprising behavior.
