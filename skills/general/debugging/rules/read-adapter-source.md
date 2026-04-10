# Read the Adapter Source Code

When a library adapter appears to silently drop fields or behave differently than documented, read the adapter's source directly. Docs always lag code. This is especially true for LangChain adapters, provider SDKs, and any library that wraps a fast-moving external API.

## When to Use

- A feature documented to work isn't working
- An adapter silently drops a field that the underlying provider supports
- The library docs are sparse, outdated, or contradict observed behavior
- You've already done a direct-API diagnostic (see `direct-api-diagnostic.md`) and confirmed the bug is in the framework layer

## The Pattern

1. **Find the adapter file.** For `@langchain/*` packages, look in `node_modules/@langchain/<provider>/dist/`. For Python, it's usually in site-packages.
2. **Search for the field or method you suspect.** Grep for the field name, the method you're calling, or the response key.
3. **Read the stream/response handler.** This is where fields get extracted and propagated. It's where silent drops happen.
4. **Trace the data flow** from the raw provider response to what your code receives.

## Example — Reasoning Model Output Dropped

**Symptom:** Calling `ChatOllama` with a reasoning model (gemma4, qwen3, deepseek-r1) returns empty content. The model runs, but your code receives `""`.

**Docs say:** Not much about reasoning models specifically. Just "supports Ollama models."

**Direct-API test:** Shows the model returns `{"message": {"content": "", "thinking": "...the actual output..."}}`. The field is `thinking`, not `content`.

**Adapter source:** `node_modules/@langchain/ollama/dist/chat_models.js:547`

```js
const token = this.think
  ? responseMessage.thinking ?? responseMessage.content ?? ""
  : responseMessage.content ?? "";
```

**Diagnosis in one line of source:** If `this.think` is falsy (the default), the adapter reads `content` (empty) and discards `thinking`. You need to construct `ChatOllama` with `think: true`.

**Fix discovered in 5 minutes** from reading one file. Would not have been findable from docs.

## Other Common Adapter-Source Finds

- **Default temperature** often comes from the provider's modelfile or SDK default, not the adapter. For Ollama, modelfile defaults can be 1.0 (bad for tool calling). The adapter won't tell you this — you have to force it.
- **Field name mismatches** between provider versions. Adapters sometimes lag when providers add new response fields.
- **Silent error swallowing** in stream handlers — errors that bubble up in docs may get caught and logged as warnings in code.
- **Retry logic** — docs may say "retries on 429" but the code only retries on thrown errors, not response-level rate-limit flags.

## Where to Look

| Ecosystem | Adapter Location |
|-----------|-----------------|
| LangChain JS | `node_modules/@langchain/<provider>/dist/chat_models.js` (or `.mjs`) |
| LangChain Python | `site-packages/langchain_<provider>/chat_models.py` |
| Provider SDKs (OpenAI, Anthropic) | `node_modules/openai/src/...` — source maps often help |
| Generic HTTP wrappers | Look for the stream handler — that's where fields propagate |

## Rules

1. **When the docs and the behavior disagree, the code is right.** Read the code.
2. **Grep for the field name you expected to see.** If it's not in the adapter, the adapter isn't propagating it.
3. **Check the stream handler specifically** for LLM adapters — that's where most silent drops happen.
4. **Save the file:line reference** in your learnings file. The next person hitting the same bug (including future you) will need it.
5. **Consider filing an upstream issue** once you've found the bug. The adapter maintainers usually want to know.
