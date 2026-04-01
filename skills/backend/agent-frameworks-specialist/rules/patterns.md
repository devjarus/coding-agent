# Agent Architecture Patterns

## ARCH-01: Building Blocks (CRITICAL)

| Block | Purpose | Implementation |
|-------|---------|---------------|
| **Model** | LLM that reasons and decides | Anthropic, OpenAI, Bedrock API |
| **Tools** | Actions the agent can take | Function definitions with schemas |
| **Memory** | Conversation and long-term state | Message history, vector stores, databases |
| **Orchestration** | Multi-agent routing and control flow | Handoffs, graphs, sequential/parallel |
| **Guardrails** | Safety and validation | Input/output checks, content filtering |
| **Observability** | Tracing, logging, evaluation | LangSmith, Langfuse, OpenTelemetry, custom |

## ARCH-02: Agent Patterns (CRITICAL)

**ReAct (Reasoning + Acting):** Agent reasons, takes action (tool call), observes result, repeats. Default for most frameworks.

**Router:** Triage agent classifies request and hands off to a specialist. Use for multi-domain systems.

**Orchestrator-Worker:** Coordinator breaks work into subtasks and dispatches workers. Use for complex multi-step tasks.

**Evaluator-Optimizer:** One agent generates, another evaluates, feedback loop until quality threshold.

**Parallel Fan-Out:** Multiple agents simultaneously for independent subtasks, aggregate results.

## ARCH-03: Tool Design (CRITICAL)

- **Clear names and descriptions** — the model chooses tools based on the description
- **Typed schemas** — use JSON Schema with `required` fields; Zod for TypeScript frameworks
- **Idempotent where possible** — tools that can be safely retried reduce failure cascading
- **Error returns, not exceptions** — return errors as tool results so the model can reason
- **Scoped permissions** — each agent gets only the tools it needs
- **Tool search for large surfaces** — use `defer_loading` / `ToolSearchTool` when 50+ tools to avoid context bloat

## ARCH-04: Memory Patterns (HIGH)

| Pattern | Use Case | Implementation |
|---------|----------|---------------|
| **Message history** | Short-term conversation | Array of messages, sliding window |
| **Summary memory** | Long conversations | Periodically summarize old messages |
| **Observational memory** | Learning from interactions | Mastra's human-inspired system, scores 95% on LongMemEval |
| **Vector store** | Semantic retrieval | Embed + store in Pinecone/Chroma/pgvector |
| **Structured store** | User profiles, preferences | Database rows, key-value stores |

## ARCH-05: Observability (HIGH)

**Tracing:** Every agent call should produce a trace with input messages, tool calls, model responses, token usage, latency, and cost.

**Framework-native tracing:**
- **Claude Agent SDK** — structured message events from `query()` iteration
- **OpenAI Agents SDK** — built-in `trace()`, `agent_span()`, `generation_span()`, `function_span()`
- **LangGraph** — LangSmith integration, `LANGCHAIN_TRACING_V2=true`
- **Strands** — built-in OpenTelemetry via env vars
- **Mastra** — tracing with spanId, working memory and token tracking

**Evaluation:** Test against golden datasets, use LLM-as-judge, track completion rate, tool call efficiency, cost per task.

## Wiring Patterns

### WIRE-01: Agent-as-Tool (CRITICAL)

The most common multi-agent pattern. Wrap one agent as a tool callable by another:

```python
# Claude Agent SDK — subagents via AgentDefinition
options = ClaudeAgentOptions(agents={"specialist": AgentDefinition(...)})

# OpenAI — agent.as_tool() or handoff()
coordinator = Agent(tools=[specialist.as_tool()])
triage = Agent(handoffs=[handoff(specialist, tool_description_override="...")])

# Strands — @tool wrapping a sub-agent
@tool
def research(query: str) -> str:
    return str(research_agent(query))

# LangGraph — nodes calling other compiled graphs
graph.add_node("specialist", specialist_graph)
```

### WIRE-02: Graph-Based Orchestration (HIGH)

For complex workflows with conditional routing:

```python
# LangGraph StateGraph
graph = StateGraph(State)
graph.add_node("classify", classify_fn)
graph.add_node("agent_a", agent_a_fn)
graph.add_node("agent_b", agent_b_fn)
graph.add_conditional_edges("classify", router, {"a": "agent_a", "b": "agent_b"})

# LangGraph Functional API
@entrypoint()
async def workflow(query: str):
    classification = await classify(query)
    if classification == "a":
        return await agent_a(query)
    return await agent_b(query)
```

### WIRE-03: Event-Driven Agents (MEDIUM)

For agents that react to external events:

```typescript
// Webhook -> Agent
app.post("/webhook/email", async (req, res) => {
  const result = await emailAgent.run(req.body);
  res.json(result);
});

// Queue -> Agent
queue.subscribe("tasks", async (message) => {
  await taskAgent.run(message.data);
});
```

## Additional Frameworks

### AF-05: CrewAI (MEDIUM)

Role-based multi-agent framework.

```python
from crewai import Agent, Task, Crew

researcher = Agent(
    role="Senior Researcher",
    goal="Find comprehensive information on the topic",
    backstory="Expert at finding and synthesizing information.",
    tools=[search_tool, scrape_tool],
)

writer = Agent(
    role="Content Writer",
    goal="Write engaging content based on research",
    backstory="Skilled writer who turns research into clear content.",
)

research_task = Task(description="Research {topic}", expected_output="Research report", agent=researcher)
write_task = Task(description="Write an article based on the research", expected_output="Article", agent=writer)

crew = Crew(agents=[researcher, writer], tasks=[research_task, write_task])
result = crew.kickoff(inputs={"topic": "AI agents in 2025"})
```

### AF-06: Mastra (MEDIUM)

TypeScript-first agent framework with workflows, observational memory, and AI Gateway support.

```typescript
import { Mastra } from "@mastra/core";
import { Agent } from "@mastra/core/agent";
import { createTool } from "@mastra/core/tools";
import { z } from "zod";

const searchTool = createTool({
  id: "search",
  description: "Search the web",
  inputSchema: z.object({ query: z.string() }),
  execute: async ({ context }) => {
    return await webSearch(context.query);
  },
});

const agent = new Agent({
  name: "assistant",
  instructions: "You help users with tasks.",
  model: { provider: "ANTHROPIC", name: "claude-sonnet-4-20250514" },
  tools: { searchTool },
});

const mastra = new Mastra({ agents: { assistant: agent } });
```

**Key patterns:**
- `createTool()` with Zod schemas for type-safe tool definitions
- Observational Memory (Feb 2026): human-inspired memory scoring ~95% on LongMemEval, reduces costs 10x vs RAG
- AI Gateway tool support in the agentic loop
- Dynamic model fallback arrays for resilience
- Workflow API with steps, branching, and parallel execution
- MCP client integration with per-server diagnostics
- Cloudflare Durable Objects storage adapter
- AI SDK v6 support; server adapters for deployment
