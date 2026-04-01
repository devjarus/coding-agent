# AF-01: Claude Agent SDK (CRITICAL)

Anthropic's official SDK for building agents with Claude. Two interfaces: raw Anthropic SDK agentic loop (TypeScript/Python) and `claude-agent-sdk` package (Python) wrapping Claude Code.

## Raw Anthropic SDK — Agentic Loop (TypeScript)

```typescript
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

async function agent(userMessage: string) {
  const messages = [{ role: "user", content: userMessage }];
  while (true) {
    const response = await client.messages.create({
      model: "claude-sonnet-4-20250514",
      max_tokens: 8096,
      tools: toolDefinitions,
      messages,
    });
    messages.push({ role: "assistant", content: response.content });
    if (response.stop_reason === "end_turn") {
      return response.content.filter(b => b.type === "text").map(b => b.text).join("");
    }
    const toolResults = [];
    for (const block of response.content.filter(b => b.type === "tool_use")) {
      const result = await executeTool(block.name, block.input);
      toolResults.push({ type: "tool_result", tool_use_id: block.id, content: result });
    }
    messages.push({ role: "user", content: toolResults });
  }
}
```

## Claude Agent SDK (Python) — `query()` and `ClaudeSDKClient`

```python
# pip install claude-agent-sdk  (Python 3.10+, bundles Claude Code CLI)
import anyio
from claude_agent_sdk import query, ClaudeAgentOptions, AssistantMessage, TextBlock

async def main():
    options = ClaudeAgentOptions(
        system_prompt="You are a helpful assistant",
        allowed_tools=["Read", "Write", "Bash"],
        max_turns=5,
    )
    async for message in query(prompt="Analyze this codebase", options=options):
        if isinstance(message, AssistantMessage):
            for block in message.content:
                if isinstance(block, TextBlock):
                    print(block.text)

anyio.run(main)
```

## Custom Tools (In-Process MCP Servers)

```python
from claude_agent_sdk import tool, create_sdk_mcp_server, ClaudeSDKClient, ClaudeAgentOptions

@tool("greet", "Greet a user", {"name": str})
async def greet_user(args):
    return {"content": [{"type": "text", "text": f"Hello, {args['name']}!"}]}

server = create_sdk_mcp_server(name="my-tools", version="1.0.0", tools=[greet_user])
```

## Subagents (Programmatic)

```python
from claude_agent_sdk import query, ClaudeAgentOptions, AgentDefinition

options = ClaudeAgentOptions(
    allowed_tools=["Read", "Grep", "Glob", "Agent"],
    agents={
        "code-reviewer": AgentDefinition(
            description="Expert code review specialist.",
            prompt="You review code for security and quality...",
            tools=["Read", "Grep", "Glob"],
            model="sonnet",
        ),
    },
)
```

## Key Patterns

- Agentic loop: keep calling the model until `stop_reason === "end_turn"`
- `query()` for one-shot async iteration; `ClaudeSDKClient` for bidirectional conversations with custom tools and hooks
- Subagents via `AgentDefinition` with context isolation — each runs in its own conversation
- Tool Search Tool (Nov 2025): `defer_loading: true` lets Claude discover tools on-demand, reducing token usage by ~85%
- Programmatic Tool Calling: Claude executes tool calls in a code sandbox, reducing context overhead
- Extended thinking: use `thinking` blocks for complex reasoning
- Streaming: `client.messages.stream()` for real-time output
