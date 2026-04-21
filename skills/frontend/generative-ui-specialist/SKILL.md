---
name: generative-ui-specialist
description: Building generative UI — LLM-driven dynamic interfaces via Vercel AI SDK, JSON component rendering, streaming UI, agent-driven frontends. For chat interfaces, AI dashboards, runtime-composed UIs.
---

# Generative UI Specialist

## When to Apply

- Chat interfaces rendering rich components, not just text
- LLM responses with interactive UI (forms, charts, cards, tables)
- Streaming UI that progressively renders during generation
- Agent dashboards with real-time tool visualization

## Patterns

- **GEN-01 (CRITICAL):** Vercel AI SDK 6 -- `ToolLoopAgent`, `createAgentUIStreamResponse`, typed `message.parts`. See [rules/vercel-ai-sdk.md](rules/vercel-ai-sdk.md)
- **GEN-02 (CRITICAL):** JSON-based rendering -- json-render catalogs, custom registries. See [rules/json-render.md](rules/json-render.md)
- **GEN-03 (HIGH):** Streaming chat with tool visualization. See [rules/streaming-chat.md](rules/streaming-chat.md)
- **GEN-04 (HIGH):** Structured output -- `generateObject`/`streamObject`. See [rules/vercel-ai-sdk.md](rules/vercel-ai-sdk.md)
- **GEN-05 (HIGH):** Ecosystems -- CopilotKit, assistant-ui, A2UI, Tambo. See [rules/ecosystems.md](rules/ecosystems.md)
- **GEN-06 (HIGH):** Tool approval -- `needsApproval` patterns. See [rules/tool-approval.md](rules/tool-approval.md)

## Rules

- **GEN-R01 (CRITICAL):** Validate LLM JSON before rendering. Use Zod or json-render catalogs. Never `dangerouslySetInnerHTML`.
- **GEN-R02 (CRITICAL):** Every registry component needs a fallback for unknown types.
- **GEN-R03 (HIGH):** Stream everything. Never show blank screens.
- **GEN-R04 (HIGH):** Show tool status via typed `message.parts` with loading/complete states.
- **GEN-R05 (HIGH):** Use `stopWhen: stepCountIs(n)` to limit agent loops.
- **GEN-R06 (MEDIUM):** Keep registry small (10-15 components).
- **GEN-R07 (MEDIUM):** Design for mobile. Test at 375px.
- **GEN-R08 (MEDIUM):** Use Context7 MCP for current AI SDK docs.
- **GEN-R09 (MEDIUM):** Use `needsApproval` instead of custom approval flows.

## Anti-Patterns

- Raw JSON dump to users instead of typed components
- No loading/streaming states (blank screens)
- Rendering unsanitized LLM HTML
- Missing error boundaries per rendered block
- Blocking UI with long agent operations
- No conversation persistence across reloads
- Deprecated APIs: `maxSteps`, `parameters`, `toDataStreamResponse()`, `ai/rsc`
- Untyped `toolInvocations` instead of typed `message.parts`
