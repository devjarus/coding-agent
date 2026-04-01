# AF-04: Strands Agents (HIGH)

AWS's lightweight, model-agnostic agent framework. Python package `strands-agents`, TypeScript `@strands-agents/sdk` (1.0.0-rc.1, March 2026).

## Basic Agent

```python
from strands import Agent, tool

@tool
def calculator(expression: str) -> str:
    """Evaluate a math expression."""
    return str(eval(expression))

agent = Agent(
    system_prompt="You are a helpful math tutor.",
    tools=[calculator],
)
response = agent("What is 15% of 230?")
```

## Model Providers

```python
from strands.models import BedrockModel, AnthropicModel, OpenAIModel, GeminiModel, OllamaModel

agent = Agent(model=BedrockModel(model_id="anthropic.claude-sonnet-4-20250514-v1:0"))
agent = Agent(model=AnthropicModel(model="claude-sonnet-4-20250514"))
agent = Agent(model=OpenAIModel(model="gpt-4o"))
```

## Memory Management

```python
from strands.agent.conversation_manager import SlidingWindowConversationManager, SummarizingConversationManager

agent = Agent(conversation_manager=SlidingWindowConversationManager(window_size=10))
agent = Agent(conversation_manager=SummarizingConversationManager())
```

## MCP Support

```python
from strands.tools.mcp import MCPClient
agent = Agent(tools=[MCPClient(server_url="http://localhost:3000")])
```

## Multi-Agent (Agent-as-Tool)

```python
from strands import Agent, tool

researcher = Agent(system_prompt="You research topics thoroughly.", tools=[web_search])

@tool
def research_topic(query: str) -> str:
    """Research a topic using the research agent."""
    return str(researcher(query))

writer = Agent(system_prompt="You write based on research.", tools=[research_topic])
```

## Key Patterns

- Decorator-based tool definition with `@tool` from `strands`
- Model-agnostic: Bedrock, Anthropic, OpenAI, Gemini, Ollama providers
- Built-in conversation memory: sliding window and summarizing managers
- MCP support via `MCPClient`
- Observability: built-in OpenTelemetry via environment variables
- AG-UI protocol support with bidirectional streaming (Nova Sonic)
- TypeScript SDK: `@strands-agents/sdk` at 1.0.0-rc.1
