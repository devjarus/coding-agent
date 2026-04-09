# Acknowledgments

This plugin stands on the shoulders of many open source projects, communities, and individual contributors. Nothing here was built in isolation.

## Skills Ecosystem

### [skills.sh](https://skills.sh)

The agent skills marketplace was the single biggest inspiration for this plugin. Many of our skills are written from scratch but inspired by patterns and structures from skills published there:

| Our Skill | Inspired By |
|-----------|-------------|
| `ui-excellence` | [anthropics/skills/frontend-design](https://skills.sh/anthropics/skills/frontend-design), [vercel-labs/agent-skills/web-design-guidelines](https://skills.sh/vercel-labs/agent-skills/web-design-guidelines), [nextlevelbuilder/ui-ux-pro-max](https://skills.sh/nextlevelbuilder/ui-ux-pro-max-skill/ui-ux-pro-max), [pbakaus/impeccable/polish](https://skills.sh/pbakaus/impeccable/polish) |
| `ios-swiftui-specialist` | [wshobson/agents/mobile-ios-design](https://skills.sh/wshobson/agents/mobile-ios-design), [avdlee/swiftui-agent-skill/swiftui-expert-skill](https://skills.sh/avdlee/swiftui-agent-skill/swiftui-expert-skill), [twostraws/swiftui-agent-skill/swiftui-pro](https://skills.sh/twostraws/swiftui-agent-skill/swiftui-pro) |
| `ios-testing-debugging` | [joshuayoes/ios-simulator-mcp](https://github.com/joshuayoes/ios-simulator-mcp), [getsentry/XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP) |
| `tanstack` | [jezweb/claude-skills/tanstack-query](https://skills.sh/jezweb/claude-skills/tanstack-query), [DeckardGer/tanstack-agent-skills](https://github.com/DeckardGer/tanstack-agent-skills) |
| `publish-ready` | [antfu/skills/tsdown](https://skills.sh/antfu/skills/tsdown), patterns from Next.js, Vite, shadcn/ui, Tailwind CSS, tRPC |
| `tailwind` patterns in `css-tailwind-specialist` | [wshobson/agents/tailwind-design-system](https://skills.sh/wshobson/agents/tailwind-design-system) |

### [Anthropic Official Skills](https://github.com/anthropics/skills)

The structural patterns from Anthropic's official skills repository shaped how we organize our own:

- The `SKILL.md` + `scripts/` + `rules/` folder pattern
- Progressive disclosure via `rules/` subdirectories for long content
- Using relative paths for script references inside `SKILL.md`
- YAML frontmatter conventions (`name`, `description`, `allowed-tools`)

Specific skills studied: `docx`, `xlsx`, `skill-creator`, `pdf`.

## Design Principles

### Anthropic Harness Design

The pipeline architecture is directly inspired by Anthropic's research on building effective agents:

- **Generator-evaluator separation** — the evaluator is a different agent from the implementor to prevent self-evaluation bias
- **Sprint contracts** — evaluation criteria written before implementation (architect writes "what PASS looks like" before coding starts)
- **File-based handoffs** — structured artifacts between agents (`spec.md`, `plan.md`, `review.md`, `diagnosis.md`)
- **Prompt expansion** — the architect expands "build me a chat app" into 100+ line specs
- **Tool use and MCP integration patterns**

Reference: [Building Effective Agents](https://www.anthropic.com/research/building-effective-agents)

### CRISPR Framework Insights

- Vertical feature slices (wave-based planning)
- Research-first approach before committing to a stack

## Reference Open Source Projects

The `publish-ready` skill learned from how top OSS projects structure themselves:

- **[Next.js](https://github.com/vercel/next.js)** — monorepo with pnpm workspaces + Lerna, custom release scripts, taskr build tool
- **[Vite](https://github.com/vitejs/vite)** — conditional subpath `exports` field, rolldown bundling, npm provenance
- **[shadcn/ui](https://github.com/shadcn-ui/ui)** — changesets + release workflow, tsup bundling, clean `exports` structure
- **[Tailwind CSS](https://github.com/tailwindlabs/tailwindcss)** — logstash-logback-encoder style structured logging, multi-platform release matrix
- **[tRPC](https://github.com/tRPC/trpc)** — dual ESM/CJS exports with full type resolution, tsdown bundling

## MCP Servers

The plugin integrates with several excellent MCP servers:

- **[Context7](https://github.com/upstash/context7)** — current library documentation
- **[Exa](https://exa.ai)** — neural web search
- **[DeepWiki](https://github.com/anthropics/deepwiki-mcp)** — GitHub repo deep-dives
- **[Playwright MCP](https://github.com/microsoft/playwright-mcp)** — browser automation for UI testing
- **[Chrome DevTools MCP](https://github.com/google-labs/chrome-devtools-mcp)** — console and network inspection
- **[XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP)** — iOS build/test/debug (Sentry)
- **[ios-simulator-mcp](https://github.com/joshuayoes/ios-simulator-mcp)** — iOS simulator control (Joshua Yoes)

## Libraries & Tools

Skills reference and recommend patterns from many libraries. Credit to their maintainers:

- **Loggers:** pino, structlog, Logback + logstash-logback-encoder, slog, os.Logger, react-native-logs
- **State management:** TanStack (Query, Router, Table, Form, Store), Zustand
- **UI:** shadcn/ui, Tailwind CSS, Radix UI
- **Bundlers:** tsup, tsdown, rolldown
- **Observability:** OpenTelemetry, CloudWatch, Datadog, Sentry

## Contributors

See the [contributors graph](https://github.com/devjarus/coding-agent/graphs/contributors).

## License

This plugin is MIT licensed. We encourage you to fork, adapt, and build on it. If your adaptation is also open source, consider crediting both this plugin and the sources above.

---

If we missed crediting your work, please open an issue or PR to add it. The goal is to give credit where it's due.
