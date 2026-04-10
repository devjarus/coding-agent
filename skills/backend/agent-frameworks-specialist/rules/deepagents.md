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

## Reference

- Repo: `langchain-ai/deepagents` on GitHub (npm: `deepagents`)
- Built on LangGraph — every deepagent is a compiled LangGraph under the hood, so all LangGraph debugging tools (LangSmith tracing) work.
- For framework comparison and when to pick deepagents vs raw LangGraph, see `patterns.md`.
