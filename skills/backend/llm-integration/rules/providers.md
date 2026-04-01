# LLM-01: Provider Client Setup (CRITICAL)

## Anthropic (Claude)

```typescript
import Anthropic from "@anthropic-ai/sdk";

// Always use environment variables for keys
const client = new Anthropic(); // reads ANTHROPIC_API_KEY from env

const response = await client.messages.create({
  model: "claude-sonnet-4-20250514",
  max_tokens: 4096,
  messages: [{ role: "user", content: "Hello" }],
});
```

## OpenAI

```typescript
import OpenAI from "openai";

const client = new OpenAI(); // reads OPENAI_API_KEY from env

const response = await client.chat.completions.create({
  model: "gpt-4o",
  messages: [{ role: "user", content: "Hello" }],
});
```

## Vercel AI SDK (Provider-Agnostic)

```typescript
import { generateText, streamText, tool } from "ai";
import { anthropic } from "@ai-sdk/anthropic";
import { openai } from "@ai-sdk/openai";
import { google } from "@ai-sdk/google";

// Same interface, swap provider
const result = await generateText({
  model: anthropic("claude-sonnet-4-20250514"),
  // model: openai("gpt-4o"),
  // model: google("gemini-2.5-pro"),
  prompt: "Hello",
});
```

Note: Vercel AI SDK v6 uses Server Actions instead of API routes for streaming.

## AWS Bedrock (Converse API)

```python
import boto3
client = boto3.client("bedrock-runtime", region_name="us-east-1")

response = client.converse(
    modelId="anthropic.claude-sonnet-4-6-20250514",
    messages=[{"role": "user", "content": [{"text": "Hello"}]}],
    inferenceConfig={"maxTokens": 1024, "temperature": 0.7},
)
# Streaming: client.converse_stream(...) — yields contentBlockDelta events
```

## Ollama (Local)

```typescript
import OpenAI from "openai";

// Ollama exposes an OpenAI-compatible API
const client = new OpenAI({
  baseURL: "http://localhost:11434/v1",
  apiKey: "ollama", // required but unused
});

const response = await client.chat.completions.create({
  model: "llama3",
  messages: [{ role: "user", content: "Hello" }],
});
```

## Rules

- Never hardcode API keys. Always use environment variables.
- Pin model versions in production (`claude-sonnet-4-20250514` not `claude-sonnet`). Both old and new model ID formats work (e.g., `claude-sonnet-4-20250514` and `claude-opus-4-6` are both valid).
- Make the model ID configurable -- don't bury it in application code.
