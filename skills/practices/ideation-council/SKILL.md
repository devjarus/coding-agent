---
name: ideation-council
description: Multi-perspective ideation. A planner researches only the relevant product, architecture, security, data, and cost lenses, then synthesizes one recommendation.
---

# Ideation Council

## When to Apply

- Architect Step 1 research (brownfield or greenfield, before writing spec)
- User asks a broad question that benefits from multiple viewpoints
- Spec requires tradeoff reasoning across domains (security ↔ cost, architecture ↔ deployment)

## How It Works

The **planner** assesses the query and researches **only the relevant** perspectives in its own context. It does not dispatch subagents; only the conductor coordinates parallel work. Each perspective is a focused research mode using code search and MCP servers. The planner synthesizes findings into one recommendation for the frame or ADR.

## Perspectives (rules/perspective-prompts.md)

| Perspective | Use When |
|-------------|----------|
| **Product** | New features, user-facing changes, MVP scoping |
| **Architecture** | New systems, tech stack decisions, scalability |
| **Deployment** | New services, hosting decisions, going to production |
| **Security** | Auth, user data, payments, LLM integration |
| **Data** | New data models, database choices, migrations |
| **Cost** | Cloud infrastructure, LLM API usage, vendor choices |

**Most queries need 2-3 perspectives, not all 6.** Assess first, then research.

## Process

1. **Assess** -- read the query and determine which perspectives are relevant
2. **Research** -- use code search for the repository, Context7 for library docs,
   and Exa for web research. Reason about each result before the next query. For
   breadth-heavy lenses, return an `open_question` describing the independent
   research slices so the conductor can fan them out and redispatch you with
   verified, cited findings.
3. **Synthesize (think hard)** -- this is the irreversible step; engage extended thinking. Unified recommendation with tradeoffs and open questions -- name a winner and why, don't average conflicting perspectives.

## Rules

- **Dynamic, not fixed** -- never research all 6 perspectives by default; assess the query first
- **Synthesize, don't dump** -- user gets a unified recommendation, not 6 separate reports; surface conflicts as tradeoffs
- **Use the right tool per perspective** -- Glob/Grep for codebase, Context7 for docs, Exa for web search
- **Brownfield context matters** -- existing stack constrains recommendations; don't suggest replacing established choices
