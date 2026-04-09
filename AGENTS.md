# Development Workflow

This file tells agents (and humans) how to work on the coding-agent plugin itself.

## What This Is

A Claude Code plugin: 5 agents + 54 skills + 7 MCP servers that orchestrate multi-agent software development. Written in Markdown (agent/skill prompts) and Bash (pipeline verification scripts). No compiled code, no build step.

## Project Structure

```
coding-agent/
├── .claude-plugin/plugin.json    # plugin manifest
├── .mcp.json                     # MCP server configuration
├── agents/                       # 5 agent prompts (orchestrator, architect, implementor, evaluator, debugger)
├── skills/                       # 54 skill folders, each with SKILL.md
│   ├── frontend/
│   ├── backend/
│   ├── data/
│   ├── mobile/
│   ├── infra/
│   ├── general/
│   └── practices/
├── hooks/hooks.json              # plugin hooks (subagent logging, post-edit validation)
├── scripts/                      # plugin-level scripts (validation, setup)
└── docs/                         # design docs, retrospectives
```

## Working on the Plugin

There's no build or test command — this is a prompt-driven plugin. Changes are validated by:

1. **Running the plugin on a real project** — the best test is to use it
2. **Manual review** — read the updated agent prompts end-to-end
3. **Script validation** — `./scripts/validate.sh` checks frontmatter, required fields

### Adding a new skill

```bash
# Create skill folder
mkdir -p skills/<category>/<skill-name>

# Minimum: SKILL.md with frontmatter
cat > skills/<category>/<skill-name>/SKILL.md << 'EOF'
---
name: <skill-name>
description: <1-2 sentence description — Claude uses this to decide when to apply it>
---

# <Skill Name>

Content here...
EOF

# Optional: scripts/ for executables, rules/ for progressive disclosure
```

Then wire it into the implementor's skill routing table if it's domain-specific:
```
agents/implementor.md — add to the appropriate domain row
CLAUDE.md — update the skill table + count
```

### Modifying an agent

Agent prompts live in `agents/*.md`. Rules for modifying:

- **Keep them short** — under 800 words. Long prompts get skipped by the LLM.
- **Prioritize critical rules** — put the most important constraints first
- **Use explicit examples** — show the exact Agent tool call syntax for dispatches
- **Test on a real project** after changes — run a full pipeline

### Modifying the pipeline verification script

The deterministic gate script is at `skills/practices/pipeline-verification/scripts/verify-stage.sh`. It auto-detects project type (Node/Swift/Go/Python) and runs the appropriate build/test commands.

Test it manually before committing:
```bash
cd /path/to/any/project
/path/to/coding-agent/skills/practices/pipeline-verification/scripts/verify-stage.sh build
/path/to/coding-agent/skills/practices/pipeline-verification/scripts/verify-stage.sh tests
```

## Conventions

### Agent Prompts

- Short, direct, action-oriented — not exhaustive documentation
- Numbered steps for processes, tables for decision trees
- Use `${CLAUDE_SKILL_DIR}` inside SKILL.md to reference bundled scripts
- Always include frontmatter: `name`, `description`, optional `model`, `tools`, `skills`

### Skills

- Follow Anthropic's pattern: `SKILL.md` at the root, optional `scripts/` and `rules/` subdirectories
- Progressive disclosure: `SKILL.md` is the entry point, `rules/*.md` is detail loaded when relevant
- Keep `SKILL.md` under 500 lines — move detail to `rules/`
- Descriptions under 250 characters (Claude truncates longer ones in the skill index)

### Commits

- One feature/fix per commit
- Reference the relevant agent or skill in the commit message
- Test on a real project before committing architectural changes

### Versioning

Semver. Current version: `1.0.0`.

Bump rules:
- **Patch** — skill content updates, typo fixes, doc updates
- **Minor** — new skill, new agent instruction, new MCP server
- **Major** — architectural changes (new agent, pipeline reorganization, breaking changes to artifact format)

## Architecture Decisions

- **5 agents flat, 1 level deep** — Claude Code doesn't allow nested subagents. Only the main-thread orchestrator can dispatch via `Agent` tool.
- **Deterministic gates over prompts** — LLMs skip instructions. Scripts don't.
- **Short agent prompts** — learned the hard way: 2000-word prompts get partially ignored. Keep it tight.
- **Separate evaluator from implementor** — generator-evaluator separation prevents self-evaluation bias.
- **Research from real docs** — architect uses Context7/DeepWiki/Exa MCP, not training data.
- **Task size classification** — the orchestrator can write code for Micro tasks, must dispatch for everything larger.

## Known Issues

- `${user_config.exa_api_key}` in `.mcp.json` — plugin configs can't reference user config this way. Users must set `EXA_API_KEY` in their shell environment.
- The `coordination-templates` skill is minimal — could be expanded with more progress.md schema examples.
- No automated CI for the plugin itself (it's all prompt-based).

## Testing Changes

The test suite lives in `~/workspace/test-agents/` with test scenarios:
- **W1** — greenfield backend (Todo API)
- **W2** — fullstack with parallel dispatch (Blog dashboard)
- **W3** — brownfield (add features to W2)
- **W4** — session recovery

To run a test:
```bash
cd ~/workspace/test-agents/W1-todo-api
rm -rf .coding-agent/
claude
# Paste the prompt from PROMPT.md
```

Verify the agent-log shows the correct dispatch sequence.

## Development Notes

- Changes to agents/skills are picked up on the next Claude Code session start (no reload needed)
- `.coding-agent/` is gitignored — it's runtime state, not source
- Test failures in the test suite often surface agent instruction ambiguity — fix the prompt, not the test
- When in doubt, check `docs/` for past retrospectives and design discussions
