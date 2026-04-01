# AF-03: LangChain / LangGraph (HIGH)

LangChain for chains and tools, LangGraph for stateful multi-agent graphs. LangGraph provides both `StateGraph` API and Functional API (`@task`/`@entrypoint`).

## LangGraph StateGraph Agent

```python
from langgraph.graph import StateGraph, MessagesState, START, END
from langchain_anthropic import ChatAnthropic
from langgraph.prebuilt import create_react_agent

# Simple: prebuilt ReAct agent
llm = ChatAnthropic(model="claude-sonnet-4-20250514")
agent = create_react_agent(llm, tools=[search])

# Custom: StateGraph with conditional routing
from typing import Annotated
from langgraph.graph.message import add_messages

class State(TypedDict):
    messages: Annotated[list, add_messages]

graph = StateGraph(State)
graph.add_node("researcher", researcher_fn)
graph.add_node("reviewer", reviewer_fn)
graph.add_edge(START, "researcher")
graph.add_edge("researcher", "reviewer")
graph.add_conditional_edges("reviewer", should_continue, {"researcher": "researcher", "end": END})
agent = graph.compile()
```

## Functional API (Alternative to StateGraph)

```python
from langgraph.func import task, entrypoint

@task
async def research(query: str) -> str:
    return await llm.ainvoke(query)

@task
async def review(content: str) -> str:
    return await review_llm.ainvoke(content)

@entrypoint()
async def workflow(query: str) -> str:
    result = await research(query)
    reviewed = await review(result)
    return reviewed
```

## Key Patterns

- `create_react_agent()` for simple tool-using agents
- `StateGraph` for complex multi-step workflows with conditional routing
- `@task` / `@entrypoint` functional API — Python control flow instead of explicit graph edges
- `Annotated[list, add_messages]` for append-mode message state
- Checkpointing with `MemorySaver` or database backends for persistence
- `interrupt_before` / `interrupt_after` for human-in-the-loop
- LangGraph CLI: `langgraph dev` (local), `langgraph build` (Docker), `langgraph deploy` (LangSmith)
- LangSmith for tracing and evaluation
