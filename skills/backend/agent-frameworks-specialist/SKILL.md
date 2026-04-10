---
name: agent-frameworks-specialist
description: Deep expertise in building AI agents using LangChain, LangGraph, LangChain Deep Agents (deepagents), OpenAI Agents SDK, Claude Agent SDK (claude_agent_sdk), Strands Agents, CrewAI, AutoGen, and Mastra. Covers agent architecture, tool use, multi-agent orchestration, memory, observability, and deployment. Use when building any AI agent system.
---

# Agent Frameworks Specialist

## When to Apply

- Building AI agents or multi-agent systems
- Integrating LLMs with tools, APIs, or external services
- Designing orchestration, routing, or handoff logic
- Implementing memory, state, or conversation persistence
- Adding observability to agent systems

## Framework Quick Reference

| Framework | Priority | Best For |
|-----------|----------|----------|
| Claude Agent SDK | CRITICAL | Claude-native agents, subagents, custom tools |
| OpenAI Agents SDK | CRITICAL | Multi-agent handoffs, guardrails, tool search |
| LangGraph | HIGH | Stateful graphs, conditional routing |
| **Deep Agents (deepagents)** | **HIGH** | **Planning + subagents + virtual filesystem on top of LangGraph** |
| Strands | HIGH | Model-agnostic, lightweight, AWS/Bedrock |
| CrewAI | MEDIUM | Role-based multi-agent teams |
| Mastra | MEDIUM | TypeScript-first, observational memory |

For detailed code examples, read from `rules/`:

- `rules/claude-sdk.md` -- agentic loop, query(), subagents, custom tools
- `rules/openai-sdk.md` -- agents, handoffs, tool search, guardrails
- `rules/langgraph.md` -- StateGraph, Functional API, conditional routing
- `rules/deepagents.md` -- createDeepAgent, subagents, virtual filesystem, tool factory pattern
- `rules/strands.md` -- model providers, memory, MCP support
- `rules/patterns.md` -- architecture (ARCH-01-05), wiring, CrewAI, Mastra

## Rules

- **AF-R01 (CRITICAL):** Use the agentic loop -- keep calling until stop signal.
- **AF-R02 (CRITICAL):** Tool descriptions are prompts. Write them clearly.
- **AF-R03 (CRITICAL):** No secrets in code. Use environment variables.
- **AF-R04 (HIGH):** Add observability from day one.
- **AF-R05 (HIGH):** Start single-agent. Add multi-agent only when needed.
- **AF-R06 (HIGH):** Use Context7 MCP for current SDK docs.
- **AF-R07 (HIGH):** Use tool search when tool count exceeds ~20.
- **AF-R08 (MEDIUM):** Test with `temperature: 0` for reproducibility.
- **AF-R09 (MEDIUM):** Set token/cost budgets to prevent runaway loops.

## Anti-Patterns

- **God agent** -- 50 tools in one agent. Split or use tool search.
- **No stop condition** -- always set max iterations.
- **Synchronous everything** -- use async/streaming.
- **Logging messages only** -- trace tool calls, latencies, tokens.
- **Hardcoded model** -- make model configurable.
- **All tools upfront** -- use `defer_loading` / `ToolSearchTool`.
