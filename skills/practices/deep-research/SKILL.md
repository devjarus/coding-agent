---
name: deep-research
description: Multi-source research method — decompose a question, fan out parallel investigators, interleaved-think each result, verify claims adversarially, synthesize a cited answer. Use for breadth-heavy research, stack comparisons, "which approach wins" questions.
scope: any
trigger: on-invoke
category: practice
---

# Deep Research

How to run research that holds up: parallel breadth, then adversarial depth. The orchestrator is the lead agent; this skill is the method it (and its research subagents) follow. See `${CLAUDE_PLUGIN_ROOT}/protocols/research.md` for the actor choreography.

## The shape

```
decompose → fan out (parallel) → interleaved-think per result → verify (refute) → synthesize (cited)
```

Single-context, sequential research is the failure mode: it's slow, path-dependent (each query biased by the last), and rarely refutes itself.

## 1. Decompose (think hard first)

Engage extended thinking before any search. Break the question into 2–5 **independent** sub-questions — ones that don't need each other's answers. If two sub-questions must be answered in order, they're one investigation, not two.

Good decomposition for "best queue for our Node service":
- throughput/latency profile of candidates at our scale (Architecture)
- ops/cost of managed vs self-hosted (Deployment/Cost)
- delivery guarantees + dedupe semantics (Data)

## 2. Fan out in parallel

One investigator per sub-question, dispatched together. Isolated contexts mean independent exploration trajectories — less path dependency, broader coverage. Each investigator calls tools in parallel where it can.

Tool per job:
- **Glob/Grep** — what the codebase already does
- **Context7** — current library/framework/API docs (memory is stale)
- **DeepWiki** — open-source repo internals & patterns
- **Exa** — neural web search for comparisons, benchmarks, postmortems
- **WebSearch/WebFetch** — current events, vendor docs, pricing

## 3. Interleaved thinking on every result

Don't fire the next query blind. After each tool result, reason: *Did this answer the sub-question? What does it contradict? What's the next sharpest query?* Refine. A good investigator's 4th query is shaped by its first three results.

## 4. Verify adversarially

The most important step, and the one usually skipped. For every load-bearing claim, **try to break it**:
- Find a second independent source.
- Look for a counter-example or a "but not when…".
- Check recency — is this true for the current version?

Tag each surviving claim `high` / `medium` / `low` confidence. Record claims you *refuted* — they stop the answer from drifting back to a plausible-but-wrong default.

## 5. Synthesize, cited

Reconcile across investigators. Resolve contradictions explicitly — name the winner and why, don't average. Every recommendation carries its source. Surface what you *couldn't* resolve as open questions; a known gap beats false confidence.

## Anti-patterns

- One agent doing 15 sequential searches in its own context (slow, biased, no refutation).
- Accepting the first source as truth.
- A claim with no source.
- Synthesizing before verifying.
- Decomposing a 1-fact question into a 5-agent fan-out (match effort to the question).
