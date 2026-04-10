# AF-07: LangChain Deep Agents (HIGH)

`deepagents` is LangChain's high-level framework for building "deep" agents — agents that plan, delegate to subagents, write intermediate state to a virtual filesystem, and iterate over many cycles. It is built on top of LangGraph and uses the same model providers as LangChain.

Use this when you need:
- A planning/orchestrator agent that delegates focused work to specialist subagents
- Long-running multi-cycle work (research, analysis, code generation) that needs to persist state between steps
- A built-in todo/task list and virtual filesystem (`write_file`, `read_file`, `write_todos`) without rolling your own
- Multi-provider model support (Anthropic, OpenAI, Ollama, etc.) via the `provider:model-name` string format

If you only need a single-tool ReAct loop, use `create_react_agent` from LangGraph instead — `deepagents` is heavier.

## Install

```bash
npm install deepagents @langchain/core zod
# Plus your model provider, e.g. @langchain/anthropic
```

## Minimal Example

```typescript
import { createDeepAgent } from "deepagents";
import { tool } from "@langchain/core/tools";
import { z } from "zod";

const search = tool(
  async ({ query }) => {
    // Tools must return a STRING (or content blocks). Never throw.
    try {
      const results = await fetch(`https://api.example.com/search?q=${query}`);
      return await results.text();
    } catch (err) {
      return `Search failed: ${(err as Error).message}`;
    }
  },
  {
    name: "web_search",
    description: "Search the web for current information.",
    schema: z.object({ query: z.string() }),
  }
);

const agent = createDeepAgent({
  model: "anthropic:claude-sonnet-4-5",
  tools: [search],
  systemPrompt: "You are a research agent. Plan with write_todos, then delegate.",
});

const result = await agent.invoke({
  messages: [{ role: "user", content: "Research the latest in WebGPU" }],
});
```

## Subagents — Specialist Delegation

The defining feature. The orchestrator dispatches focused work to specialist subagents, each with their own system prompt and tool subset. Each subagent runs in its own context window — context isolation prevents the orchestrator from drowning in tool output.

```typescript
import type { SubAgent } from "deepagents";
import type { StructuredTool } from "@langchain/core/tools";

export function createWebResearcher(tools: StructuredTool[]): SubAgent {
  // Filter the parent tool array down to what THIS subagent needs.
  // Subagents should NOT have access to tools they don't use.
  const selected = tools.filter(
    (t) => t.name === "web_search" || t.name === "scrape_url"
  );

  return {
    name: "web-researcher",
    description:
      "Searches the web and reads pages for current information. " +
      "Use for news, blog posts, and general web content.",
    systemPrompt: `You are a web research specialist...
## Process
1. Use web_search with a focused query
2. For top results, use scrape_url to read full content
3. Return findings as structured markdown with citations`,
    tools: selected,
  };
}

const agent = createDeepAgent({
  model: "anthropic:claude-sonnet-4-5",
  tools, // The full tool array
  systemPrompt: orchestratorPrompt,
  subagents: [
    createWebResearcher(tools),
    createAcademicResearcher(tools),
    createCodeResearcher(tools),
    createSynthesizer(), // Synthesizer needs no custom tools — uses built-in read_file
  ],
});
```

The orchestrator delegates to subagents via the built-in `task` tool:
> "Use the `task` tool to dispatch work to web-researcher with this query..."

## Built-in Tools (Always Available)

`createDeepAgent` automatically provides these — never define your own versions:

| Tool | Purpose |
|------|---------|
| `write_todos` | Plan and track work as a structured todo list |
| `task` | Dispatch a subtask to a named subagent |
| `write_file` | Write to the virtual filesystem (in-memory, not real disk) |
| `read_file` | Read from the virtual filesystem |
| `ls` | List files in the virtual filesystem |

The virtual filesystem is the standard place for subagents to leave intermediate findings (e.g., `/research/cycle-1-web.md`) that the synthesizer reads at the end.

## Model Capacity — Not All Models Handle the Full Stack

**Small local models (8B–14B) will break inside deepagents.** The full deepagents stack loads 12 tools (7 custom + 5 built-in: `write_todos`, `task`, `write_file`, `read_file`, `ls`), 4 subagent definitions, and a 100+ line orchestrator system prompt. Models with <20B parameters cannot reliably hold this in working memory.

Empirical failures observed with gemma4 (8B) and qwen3:14b:
- Hallucinate tool names (invented `google:search` when given `web_search`)
- Skip `write_file` steps, then call the synthesizer with nothing to synthesize
- Produce pure conversational output ignoring tools entirely
- Produce "I apologize for the error" loops with zero tool calls

Frontier models (Claude Sonnet 4, GPT-4o, Gemini 2.0) and 20B+ cloud models (gpt-oss:120b, deepseek-v3.2) handle the full stack fine.

### Three-Bucket Routing

Route by model capacity, using the same tool set but different orchestration:

| Bucket | Condition | Framework | Rationale |
|--------|-----------|-----------|-----------|
| **Frontier** | Not `ollama:*` | `createDeepAgent` (full stack) | Claude/GPT/Gemini handle complex orchestration |
| **Cloud** | `ollama:*-cloud` OR `OLLAMA_API_KEY` set | `createDeepAgent` (full stack) | 20B+ cloud models have capacity |
| **Small local** | `ollama:*` without cloud signals | `createReactAgent` (simplified) | 8B–14B can't handle orchestration |

All three buckets use the **same tool array** (`createAllTools(logger)`). Only the orchestration layer differs. The ReAct path uses a short direct-instruction prompt without `write_todos`/`task`/virtual filesystem choreography.

```typescript
import { createReactAgent } from "@langchain/langgraph/prebuilt";
import { createDeepAgent } from "deepagents";
import { ChatOllama } from "@langchain/ollama";

function isOllamaCloud(model: string): boolean {
  return model.includes("-cloud") || !!process.env.OLLAMA_API_KEY;
}

function isSmallLocalOllama(model: string): boolean {
  return model.startsWith("ollama:") && !isOllamaCloud(model);
}

function buildAgent(model: string, tools: StructuredTool[], logger: Logger) {
  if (isSmallLocalOllama(model)) {
    // Simpler ReAct loop — no subagents, no virtual filesystem
    const llm = buildOllamaChat(model); // see Ollama Gotchas below
    return createReactAgent({
      llm,
      tools,
      messageModifier: SHORT_REACT_PROMPT,
    });
  }

  // Full deepagents stack for frontier + cloud
  return createDeepAgent({
    model: isOllamaCloud(model) ? buildOllamaChat(model) : model,
    tools,
    systemPrompt: FULL_ORCHESTRATOR_PROMPT,
    subagents: [/* ... */],
  });
}
```

### Check Tool-Calling Capability

Not all local models support tool calling at all:

```bash
ollama show <model> | grep -i capabilit
# capabilities: completion tools        ← need "tools"
```

Models WITHOUT `tools` capability (gemma2, gemma3, phi3, phi4, codellama, tinyllama) will silently ignore your tool definitions. Verified working with the `tools` capability: `gemma4` (needs ReAct), `qwen3:14b` (needs ReAct), `qwen3:32b`, `llama3.1:70b`, `llama3.3:70b`, `gpt-oss:120b-cloud`.

## Ollama Gotchas

Two gotchas in `@langchain/ollama` that silently break everything. Both must be fixed or Ollama models appear "broken" in your agent.

### 1. `initChatModel("ollama:...")` uses broken defaults

`createDeepAgent({ model: "ollama:gemma4" })` → LangChain's `initChatModel` → constructs `ChatOllama` with the model's **modelfile defaults**, which for most Ollama models means:
- `temperature: 1.0` — catastrophic for tool calling. Causes hallucinated tool names.
- `think: undefined` — see gotcha #2.

**Fix:** branch on `model.startsWith("ollama:")` and construct `ChatOllama` directly. Pass the instance to `createDeepAgent`/`createReactAgent` instead of the string.

```typescript
import { ChatOllama } from "@langchain/ollama";

function buildOllamaChat(model: string): ChatOllama {
  const modelName = model.replace(/^ollama:/, "");
  const isCloud = model.includes("-cloud") || !!process.env.OLLAMA_API_KEY;

  return new ChatOllama({
    model: modelName,
    temperature: 0,  // FORCE — modelfile default is often 1.0
    think: true,     // FORCE — see gotcha #2
    baseUrl: isCloud && process.env.OLLAMA_API_KEY
      ? "https://ollama.com"
      : "http://localhost:11434",
    ...(process.env.OLLAMA_API_KEY && {
      headers: { Authorization: `Bearer ${process.env.OLLAMA_API_KEY}` },
    }),
  });
}
```

### 2. Reasoning models require `think: true`

`@langchain/ollama` source (`dist/chat_models.js:547`):

```js
const token = this.think
  ? responseMessage.thinking ?? responseMessage.content ?? ""
  : responseMessage.content ?? "";
```

Reasoning models (gemma4, qwen3, deepseek-r1) return `content: ""` and put their actual output in `message.thinking`. Without `think: true`, the adapter reads `content` (empty) and **discards** `thinking`. The model appears to produce nothing.

**Fix:** always set `think: true` on `ChatOllama`. Safe default for all Ollama models — non-reasoning models ignore it.

### 3. Ollama Cloud has two auth modes

From [docs.ollama.com/cloud](https://docs.ollama.com/cloud):

**Mode A — Proxied through local Ollama daemon:**
```bash
ollama signin                          # one-time browser auth
ollama pull gpt-oss:120b-cloud         # register locally
```
Model names have `-cloud` suffix. `baseUrl` stays `http://localhost:11434`. Local daemon proxies to ollama.com.

**Mode B — Direct HTTPS to ollama.com:**
```bash
export OLLAMA_API_KEY=<key>            # from ollama.com/settings/keys
```
Construct `ChatOllama` with `baseUrl: "https://ollama.com"` and `headers: { Authorization: "Bearer ..." }`. No `-cloud` suffix needed.

### 4. Cloud auth errors are unhelpful

The raw error from Ollama Cloud when unauthenticated is `"unauthorized"` buried inside a 50-line langgraph stack trace. Users can't tell if they need `ollama signin`, `OLLAMA_API_KEY`, or a different model name.

**Fix:** catch errors in the top-level runner and, when the message contains "unauthorized" AND the model starts with `ollama:`, print an actionable hint with both auth mode commands.

## Multi-Provider Model Strings

The `model` field uses the `provider:model-name` convention from LangChain's `initChatModel`:

```typescript
"anthropic:claude-sonnet-4-5"
"openai:gpt-4o"
"ollama:llama3.1"
"google-genai:gemini-2.0-flash"
```

**Validate the model string early.** Reject empty strings and missing `:` before the agent runs — otherwise the failure surfaces deep inside LangChain with a confusing error.

```typescript
if (!model || !model.includes(":")) {
  throw new Error(
    `Invalid model string: "${model}". ` +
    `Expected "provider:model-name" (e.g. "anthropic:claude-sonnet-4-5")`
  );
}
```

## Tool Design — Critical Rules

Tools that misbehave will crash the entire agent loop. Follow these rules religiously.

1. **Return strings, never throw.** Catch every error and return it as a string the LLM can read.
   ```typescript
   try { /* work */ } catch (err) {
     return `Failed: ${err instanceof Error ? err.message : String(err)}`;
   }
   ```

2. **Use Zod schemas with descriptions.** The schema doubles as documentation for the LLM.
   ```typescript
   schema: z.object({
     query: z.string().describe("The search query"),
     limit: z.number().optional().describe("Max results (default 10)"),
   })
   ```

3. **Cap output size.** LLMs choke on multi-megabyte responses. Truncate to a few thousand characters and add a `[... truncated]` marker.

4. **Use timeouts.** Wrap external calls in `AbortSignal.timeout(15_000)` so a hung HTTP call doesn't freeze the agent.

5. **Factory pattern for testability and logging.** Export a `createXxx(logger?)` factory plus a backward-compatible default instance:
   ```typescript
   export function createWebSearch(parentLogger?: Logger) {
     const log = parentLogger?.child({ tool: "web_search" }) ?? silentLogger;
     return tool(
       async ({ query }) => { /* uses log.info / log.error */ },
       { name: "web_search", description: "...", schema }
     );
   }
   // Default export keeps existing imports working
   export const web_search = createWebSearch();
   ```

## System Prompt Patterns

The orchestrator system prompt should:
1. Tell the agent **when to plan** — "use `write_todos` BEFORE doing any work"
2. Tell it **which subagent does what** — explicit name + capability mapping
3. Tell it **where to save intermediate state** — file path conventions
4. Provide a **final output template** — markdown skeleton with sections
5. Set **iteration expectations** — "perform 2-3 cycles before synthesizing"

```typescript
const systemPrompt = `You are an orchestrator. Your goal is X.

## Workflow
### Step 1 — Plan
Use \`write_todos\` to break the work into phases.

### Step 2 — Delegate
Use \`task\` to dispatch to the right subagent:
- **researcher** — for finding new information
- **synthesizer** — for combining findings into a final report

### Step 3 — Save State
After each cycle, use \`write_file\` to save findings to /work/cycle-N.md

### Step 4 — Synthesize
Once all cycles are done, dispatch synthesizer to read /work/* and write the final report.
`;
```

Subagent system prompts should specify a strict **output format** — markdown with named sections — so the orchestrator can reliably parse what comes back.

## Anti-Patterns

- **Tools that throw.** One unhandled exception kills the loop. Always catch and return a string.
- **Giving every subagent every tool.** Subagents should get the minimum tool set they need. Filter the array.
- **No `write_todos` step.** Without planning, the agent meanders. Force it in the system prompt.
- **Skipping the virtual filesystem.** When findings only live in messages, the context window blows up. Save to files, read at the end.
- **Hand-rolled subagent definitions inline.** Put each subagent in its own file as a `createXxx(tools)` factory — easier to test, easier to swap.
- **No logging in tools.** You will be debugging tool failures. Log start/finish/elapsed/result-size for every tool. See the `observability` skill.
- **Hardcoded model.** Always make `model` a configurable option and validate the string format.
- **Passing small local Ollama models to `createDeepAgent`.** 8B–14B models can't handle the full orchestration stack. Route them to `createReactAgent` instead (see Model Capacity above).
- **Using `initChatModel("ollama:...")` as a string.** Always construct `ChatOllama` directly for Ollama models so you can force `temperature: 0` and `think: true` (see Ollama Gotchas).

## Reference

- Repo: `langchain-ai/deepagents` on GitHub (npm: `deepagents`)
- Built on LangGraph — every deepagent is a compiled LangGraph under the hood, so all LangGraph debugging tools (LangSmith tracing) work.
- For framework comparison and when to pick deepagents vs raw LangGraph, see `patterns.md`.
