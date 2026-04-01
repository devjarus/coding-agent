---
name: ideation-council
description: Multi-perspective ideation pattern — the brainstormer assesses the user's query and dispatches parallel Explore subagents with relevant perspective lenses (product, architecture, deployment, security, data, cost). Dynamic — only dispatches perspectives the query actually needs.
---

# Ideation Council

## When to Apply

- Brainstormer Step 1b (brownfield) or Step 4b (greenfield after approach chosen)
- Any time the brainstormer needs to research before forming recommendations
- User asks a broad question that benefits from multiple viewpoints

## How It Works

The brainstormer assesses the query and researches **only the relevant** perspectives. Each perspective focuses on a specific concern. The brainstormer synthesizes findings into a unified recommendation.

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
2. **Research** -- use Glob/Grep for codebase, Context7 for library docs, Exa for web search, DeepWiki for dependencies
3. **Synthesize** -- unified recommendation with tradeoffs and open questions

## Rules

- **Dynamic, not fixed** -- never research all 6 perspectives by default; assess the query first
- **Synthesize, don't dump** -- user gets a unified recommendation, not 6 separate reports; surface conflicts as tradeoffs
- **Use the right tool per perspective** -- Glob/Grep for codebase, Context7 for docs, Exa for web search, DeepWiki for open-source
- **Brownfield context matters** -- existing stack constrains recommendations; don't suggest replacing established choices
