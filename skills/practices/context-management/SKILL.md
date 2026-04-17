---
name: context-management
description: Context window management for long-running orchestrator sessions. Detects when context is degrading and suggests user actions. Manages artifacts for session recovery.
---

# Context Management

The orchestrator's context window is finite. Every dispatch prompt, subagent summary, artifact read, and tool output accumulates. Performance degrades as context grows (context rot), and the model is at its least capable when autocompact fires near the limit.

**Key constraint:** `/compact`, `/clear`, and `/rewind` are user-initiated CLI commands. Agents cannot execute them. The orchestrator's job is to detect when context is degrading, write recovery artifacts, and suggest user actions via AskUserQuestion.

## Decision Point: After Every Subagent Return

When a subagent returns and you're about to act, choose one:

| Action | When to use |
|--------|-------------|
| **Continue** | Context is clean, next step is clear, dispatch count < 5 |
| **Suggest compact** | Dispatch count >= 5, or switching feature phases — ask user via AskUserQuestion |
| **Write session-state.md + suggest clear** | Round 3 escalation, major pivot, or 2+ features completed in one session |
| **Delegate to subagent** | Next chunk of work will produce intermediate output you won't need again (only the conclusion) |

## When to Suggest Compact

### Triggers (detect these, then ask the user)

- **5+ dispatches** since session start or last known compact
- **Phase transition**: spec complete -> starting implementation, or implementation complete -> starting evaluation
- **After a successful commit** before starting the next feature
- **Before a complex dispatch** that will need focused context (e.g., debugger dispatch with long history)

### How to suggest

Use AskUserQuestion with the trigger reason and a ready-to-paste compact command:

```
AskUserQuestion("Context is getting heavy (6 dispatches since start, entering fix round).
Suggest running:

/compact focus on open findings from review.md and handoff.md. Drop resolved findings and completed dispatch transcripts.

Want to compact before I continue?")
```

The steering text matters — it tells autocompact (or a manual /compact) what to preserve. Tailor it to the current phase:
- After spec approval: `focus on spec.md requirements and plan.md tasks. Drop discovery Q&A with user.`
- After fix round: `focus on open findings from review.md and handoff.md. Drop resolved findings and first implementor's transcript.`
- After commit: `keep only learnings.md entry and user's last message. Drop all feature artifacts — they're on disk.`

**After suggesting, do not assume the user ran it.** Continue with the next dispatch regardless. The suggestion is advisory.

## When to Suggest Clear

### Triggers

- Round 3 escalation: 2 failed fix attempts, bug persists
- User pivots to an entirely new task mid-session
- 2+ features completed in one session and context is stale

### What the orchestrator does (file I/O — this works)

Write `.coding-agent/features/<CURRENT>/session-state.md` before suggesting:

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

Then tell the user:

```
AskUserQuestion("I've written a session checkpoint to session-state.md.
Context is deep — suggest running /clear and starting fresh.
The new session will read session-state.md to resume where we left off.")
```

## When to Suggest Rewind (guidance for users)

The orchestrator cannot rewind, but it can recognize when rewind would have been better than correction. When the orchestrator notices it's about to re-dispatch because a previous dispatch went wrong (not incomplete — actually wrong approach), tell the user:

```
AskUserQuestion("The last dispatch took the wrong approach.
If you'd like to try a different angle, you can press Esc Esc to rewind
to before that dispatch, and I'll re-prompt with a different strategy.
Otherwise I'll re-dispatch with corrections.")
```

This is advisory only. The orchestrator should always be ready to re-dispatch normally if the user declines.

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

| Dispatch count (since session start or last known compact) | Action |
|------------------------------------------------------------|--------|
| 1-4 | Continue normally |
| 5-7 | Suggest compact to user before next dispatch |
| 8+ | Write session-state.md + suggest clear |

Multi-round fix sessions accumulate fastest: each round = implementor dispatch + evaluator dispatch + orchestrator reads review.md. Two fix rounds = 6+ dispatches. Suggest compact after Round 1 if entering Round 2.

### Counter tracking

Track dispatches informally — a one-line note in `progress.md`'s decisions log is enough. After the user runs `/compact` or `/clear`, reset the count. If you don't know whether the user compacted, assume the count did NOT reset.
