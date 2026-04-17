---
name: context-management
description: Context window management for long-running orchestrator sessions. Defines when and how to compact, rewind, clear, and delegate to subagents to prevent context rot.
---

# Context Management

The orchestrator's context window is finite. Every dispatch prompt, subagent summary, artifact read, and tool output accumulates. Performance degrades as context grows (context rot), and the model is at its least capable when autocompact fires near the limit. Manage context proactively.

## Decision Point: After Every Subagent Return

When a subagent returns and you're about to act, choose one:

| Action | When to use |
|--------|-------------|
| **Continue** | Context is clean, next step is clear, dispatch count < 5 since last compact |
| **Compact** | Dispatch count >= 5, or switching from one feature phase to another (e.g., spec done, starting implementation) |
| **Rewind** | A subagent produced bad output and you haven't acted on it yet — rewind to before the dispatch, adjust the prompt, re-dispatch |
| **Clear + handoff** | Round 3 escalation, major pivot from user, or accumulated context from 2+ completed features in one session |
| **Delegate to subagent** | The next chunk of work will produce intermediate output you won't need again (only the conclusion) |

## Compact Playbook

### Triggers (compact proactively, not reactively)

- **5+ dispatches** since last compact or session start
- **Phase transition**: spec complete -> starting implementation, or implementation complete -> starting evaluation
- **After a successful commit** before starting next feature
- **Before a complex dispatch** that will need focused context (e.g., debugger dispatch with long history)

### Steering (always steer, never bare `/compact`)

Include what to keep and what to drop:

```
/compact focus on: current feature <slug>, active plan tasks, evaluator findings still open.
Drop: completed dispatch transcripts, resolved findings, file contents already captured in artifacts.
```

Examples by phase:
- After spec approval: `/compact focus on spec.md requirements and plan.md tasks. Drop discovery Q&A with user.`
- After fix round: `/compact focus on open findings from review.md and handoff.md. Drop resolved findings and first implementor's transcript.`
- After commit: `/compact keep only learnings.md entry and user's last message. Drop all feature artifacts — they're on disk.`

## Rewind Playbook

### When to rewind (not re-dispatch)

Rewind drops messages after the rewind point. Use it when the **dispatched work was wrong**, not when it was incomplete:

- Subagent took wrong approach and you haven't dispatched a follow-up yet
- Tool output (file read, grep) returned irrelevant content that's now polluting context
- You assembled a dispatch prompt with wrong excerpts from spec/plan

### When NOT to rewind

- Subagent completed work and you've already dispatched the evaluator — rewind would lose the evaluator's output
- The "bad" output actually contains useful diagnostic information — extract what you need first, then compact

## Clear + Handoff Playbook

### When to clear

- Round 3 escalation: user provides new direction after 2 failed fix attempts
- User pivots to an entirely new task mid-session
- 2+ features completed in one session and context is stale

### Handoff brief structure

Before `/clear`, write `.coding-agent/features/<CURRENT>/session-state.md`:

```markdown
## Session State — <YYYY-MM-DD HH:MM>

### Current Phase
[classify/spec/plan/implement/evaluate/fix-round-N]

### What's Done
[Completed stages, committed work]

### What's In Progress
[Current stage, dispatched agent, pending action]

### What Was Tried and Failed
[Approaches attempted, why they failed — critical for avoiding repeat failures]

### Key Context
[Constraints, decisions, user preferences that must survive the clear]

### Next Action
[Exact next step for the fresh session to take]
```

After writing `session-state.md`, tell the user: "I've checkpointed the session state. Starting fresh — the new session will read session-state.md to resume."

## Subagent Delegation Patterns

### The mental test

> "Will I need this intermediate output again, or just the conclusion?"

If just the conclusion, use a subagent.

### Delegate these (keep orchestrator context clean)

| Task | Why delegate |
|------|-------------|
| Reading 3+ files to assemble a dispatch brief | File contents stay in subagent context, only the brief comes back |
| Verifying a fix against spec after evaluator PASS | Subagent reads spec + code, returns pass/fail |
| Generating docs after commit | Subagent reads git diff + code, writes docs, returns summary |
| Reading review.md + spec.md to decide fix strategy | Subagent synthesizes, returns "dispatch debugger because X" or "re-implement task T-3 because Y" |

### Don't delegate these

- Writing to artifacts (orchestrator must own artifact state)
- Dispatching other subagents (only orchestrator has Agent tool)
- User communication (only orchestrator has AskUserQuestion)

## Context Budget Heuristic

Don't count tokens. Use dispatch count as a proxy:

| Dispatch count (since last compact/clear) | Action |
|-------------------------------------------|--------|
| 1-4 | Continue normally |
| 5-7 | Compact with steering before next dispatch |
| 8+ | Clear with handoff brief — session is too deep |

Multi-round fix sessions accumulate fastest: each round = implementor dispatch + evaluator dispatch + orchestrator reads review.md. Two fix rounds = 6+ dispatches. Compact after Round 1 if entering Round 2.
