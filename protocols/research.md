---
name: research
# Research Protocol

Actors: **orchestrator** (lead — decomposes, dispatches, verifies, owns the artifact), **architect / Explore subagents** (parallel investigators), **architect** (synthesis when the result feeds a spec).

Output: `features/<CURRENT>/research.md` from `${CLAUDE_PLUGIN_ROOT}/templates/research.template.md`, or a `research` block returned inline for lightweight questions.

This is the multi-agent research pattern: a lead agent plans and fans out, isolated subagents investigate in parallel, the lead verifies before trusting. Mirrors Anthropic's [multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system).

## When to run

- Spec-writing needs broad external research (3+ dependencies, an unfamiliar stack, a "which approach wins" question).
- The user asks a research/comparison question directly.
- The architect returns `status: needs-research` with a `research_request` (it hit a breadth-heavy question it shouldn't burn its own context on).

Skip for single-fact lookups (one Context7 query inline) or anything `profile.md` / `learnings.md` already resolve.

## Steps

1. **Plan (lead, think hard).** Engage extended thinking. Decompose the question into 2–5 *independent* sub-questions that can be investigated without each other's results. Over-decomposition wastes subagents; one sub-question per distinct unknown. Write the decomposition to the action log.
2. **Fan out in parallel.** Dispatch one subagent per sub-question **in a single message** (multiple `Agent` calls) so they run concurrently — Explore for codebase sweeps, architect for design/stack judgment. Each subagent:
   - gets its own isolated context (separation of concerns reduces path dependency),
   - calls research tools in parallel where possible (Context7 / Exa / WebSearch),
   - reasons between queries **only when a result surprises or contradicts the working hypothesis** — refine then, rather than spending a thinking pass on every confirming result,
   - returns a brief: each claim paired with its source and a confidence (high / medium / low).
3. **Verify adversarially (lead).** Do not trust briefs on arrival. For every load-bearing or low-confidence claim, try to *refute* it: a second source, a counter-example, "is this version-current?". Demote or drop claims that don't survive. Record refuted claims — they are evidence too.
4. **Synthesize.** Reconcile across briefs. Resolve contradictions explicitly (don't average them). When the result feeds a spec, dispatch the architect to fold findings into `## Approach` / `## Alternatives` / `## Test Infrastructure`; otherwise the orchestrator writes `research.md` directly.
5. **Return.** Cited synthesis + open questions. Every recommendation traces to a verified source.

## Critical rules

- **Only the orchestrator fans out.** Subagents investigate and return briefs; they never dispatch each other (invariant: only the orchestrator holds `Agent`).
- **Every claim is cited.** A finding without a `source` is a guess — mark it `confidence: low` and verify or drop it.
- **Verification is not optional.** Unrefuted ≠ true; it means "survived one refutation attempt." Stop when further searches stop changing the answer, not after the first hit.
- **Parallel by default.** Independent sub-questions go out together, not one at a time. Sequential research is the slow path.
- **Memory is stale.** Library/API facts come from Context7/Exa, not training memory (it's 2026).
