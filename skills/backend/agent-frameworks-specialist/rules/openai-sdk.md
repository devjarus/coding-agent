# AF-02: OpenAI Agents SDK (CRITICAL)

OpenAI's framework for multi-agent orchestration. Current version 0.13+.

## Basic Agent

```python
from agents import Agent, Runner, function_tool

@function_tool
def get_weather(city: str) -> str:
    """Get current weather for a city."""
    return f"Sunny, 72F in {city}"

agent = Agent(
    name="weather_agent",
    instructions="You help users check weather conditions.",
    tools=[get_weather],
    model="gpt-4o",
)

result = Runner.run_sync(agent, "What's the weather in SF?")
print(result.final_output)
```

## Handoffs (Multi-Agent)

```python
from agents import Agent, handoff

triage_agent = Agent(
    name="triage",
    instructions="Route users to the right specialist.",
    handoffs=[
        handoff(billing_agent, tool_description_override="Billing questions"),
        handoff(technical_agent, tool_description_override="Technical support"),
    ],
)
```

## Hosted Tools and Tool Search

```python
from agents import Agent, WebSearchTool, FileSearchTool, ToolSearchTool, function_tool, tool_namespace

@function_tool(defer_loading=True)
def get_customer_profile(customer_id: str) -> str:
    """Fetch a CRM customer profile."""
    return f"profile for {customer_id}"

crm_tools = tool_namespace(name="crm", description="CRM tools", tools=[get_customer_profile])
agent = Agent(
    name="ops_assistant",
    tools=[*crm_tools, ToolSearchTool(), WebSearchTool()],
)
```

## Key Patterns

- `Runner.run_sync()` / `Runner.run()` / `Runner.run_streamed()` for execution
- Handoffs for agent-to-agent routing with `on_handoff` callbacks and `input_type` for structured data
- `agent.as_tool()` to expose an agent as a callable tool without full handoff
- Hosted tools: `WebSearchTool`, `FileSearchTool`, `CodeInterpreterTool`, `HostedMCPTool`, `ImageGenerationTool`
- `ToolSearchTool` + `defer_loading=True` / `tool_namespace()` for on-demand tool discovery
- Guardrails: `InputGuardrail`, `OutputGuardrail` with tripwire pattern
- Tracing built-in: `trace()` context manager, `agent_span()`, `generation_span()`, `function_span()`
- Context variables for shared state; `RunConfig` for tracing, model settings
