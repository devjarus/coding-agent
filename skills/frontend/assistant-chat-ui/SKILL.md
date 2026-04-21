---
name: assistant-chat-ui
description: Patterns for AI assistant UIs — chat, tool rendering, rich components. Uses assistant-ui + Vercel AI SDK + json-render + shadcn + TanStack Query. For chat interfaces, agent dashboards, conversational UIs.
---

# Assistant Chat UI

## When to Apply

- Building a chat-based AI assistant or agent interface
- Rendering tool call results as rich UI components (not raw JSON)
- Streaming LLM responses with real-time tool execution visualization
- Building thread management (multiple conversations)
- Adding file attachments, markdown rendering, or code highlighting to chat

## Core Stack

```
@assistant-ui/react          -- Chat UI primitives (Thread, messages, composer)
@assistant-ui/react-ai-sdk   -- Bridges assistant-ui with Vercel AI SDK
@assistant-ui/react-markdown  -- Markdown rendering in chat messages
ai                           -- Vercel AI SDK (streaming, transport)
@ai-sdk/react                -- React hooks (useChat)
@json-render/react           -- JSON-to-component rendering for structured output
@json-render/shadcn          -- Pre-built shadcn components for json-render
@tanstack/react-query        -- Server state for threads, settings, side panels
shadcn/ui                    -- Component library (cards, buttons, dialogs)
```

## Rules

### CRITICAL (rules/runtime-and-tools.md)

- **CHAT-01:** Runtime provider setup -- bridge Vercel AI SDK `useChat` with `AssistantRuntimeProvider`
- **CHAT-02:** Every tool must have a registered UI via `makeAssistantToolUI`; show loading/complete/error states

### HIGH (rules/threads-and-features.md)

- **CHAT-03:** Thread management with TanStack Query; invalidate caches after streaming completes
- **CHAT-04:** File attachments via `CompositeAttachmentAdapter` (PDFs, images)
- **CHAT-05:** Structured output rendering with `@json-render/react` + shadcn catalog
- **CHAT-06:** Standard app layout: sidebar + runtime provider + thread + optional right panel

### Rules Summary

- **CHAT-R01 (CRITICAL):** Every tool must have a registered UI -- unregistered tools render as raw JSON
- **CHAT-R02 (CRITICAL):** Show loading states for running tools
- **CHAT-R03 (HIGH):** Use `prepareSendMessagesRequest` to send only the last message when server has history
- **CHAT-R04 (HIGH):** Classify errors in `onError` -- network, auth, model, timeout
- **CHAT-R05 (HIGH):** Invalidate TanStack Query caches after streaming completes
- **CHAT-R06 (MEDIUM):** Support file attachments via `CompositeAttachmentAdapter`

## Anti-Patterns

- No tool UIs -- raw JSON dumped in the chat
- Full message re-send every turn when server has history
- No error classification -- showing raw error strings to users
- Polling for updates instead of TanStack Query invalidation
- Monolithic chat component -- split into RuntimeProvider, Thread, ToolUIs, Sidebar
