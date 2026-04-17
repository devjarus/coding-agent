# Development Workflow

This file tells agents (and humans) how to work on the coding-agent plugin itself.

## What This Is

A Claude Code plugin: 5 agents + 57 skills + 7 MCP servers. All Markdown prompts, no build step, no compiled code. Changes to an agent or skill file take effect on the next Claude Code session start.

## Project Structure

```
coding-agent/
├── .claude-plugin/plugin.json    # plugin manifest (name, default main agent)
├── .mcp.json                     # MCP server configuration
├── agents/                       # 5 agent prompts (orchestrator, architect, implementor, evaluator, debugger)
├── skills/                       # 57 skill folders, each with SKILL.md
│   ├── frontend/   backend/   data/   mobile/   infra/
│   ├── general/
│   └── practices/                # cross-cutting: tdd, code-review, observability, etc.
├── hooks/hooks.json              # SubagentStart logging + PostToolUse validator
├── scripts/
│   ├── validate.sh               # plugin self-validator — run before commit
│   └── post-edit-validate.sh     # called by PostToolUse hook; validates frontmatter on every Write/Edit
├── CLAUDE.md, README.md          # docs (keep skill counts + tables in sync with reality)
└── docs/                         # design retrospectives
```

## After Making Changes — The Checklist

Run this every time you edit an agent, skill, or doc:

1. **Run the validator**
   ```bash
   ./scripts/validate.sh
   ```
   Must report PASSED (warnings are ok, errors are not). The validator checks:
   - Agent frontmatter: `name`, `description`, `model` (opus/sonnet/haiku/inherit or a full model ID like `claude-opus-4-7`)
   - Skill frontmatter: `name`, `description`
   - Skill references in agents actually exist on disk
   - No stale `docs/agents/` paths
   - Phase agents reference `.coding-agent/` for artifacts

2. **If you added or removed a skill**, update these in the same commit:
   - `CLAUDE.md` → `## Skills (N)` header count + the appropriate table row
   - `README.md` → subtitle count + `## Skills (N)` header + the relevant table
   - If the skill is domain-specific, add it to the implementor's routing row in both files
   - If the skill should be preloaded into an agent, add it to that agent's frontmatter `skills:` list

3. **If you added or removed an artifact** (spec/plan/review/etc.):
   - `CLAUDE.md` → artifact protocol table
   - `agents/orchestrator.md` → artifact layout diagram + state machine row

4. **If you changed an agent's model or behavior**, read the full agent file end-to-end after editing. Agent prompts are under 800 words for a reason; a drive-by edit can break flow.

5. **Commit**
   - One logical change per commit
   - Reference the affected agent or skill in the subject line
   - The `PostToolUse` hook already validated frontmatter on every save — no surprises at commit time

## Adding a New Skill

```bash
mkdir -p skills/<category>/<skill-name>
cat > skills/<category>/<skill-name>/SKILL.md <<'EOF'
---
name: <skill-name>
description: <1-2 sentences — Claude uses this to decide when to apply it. Under 250 chars.>
---

# <Title>

Content...
EOF
```

Then:
- Wire into `agents/implementor.md` routing if domain-specific, or an agent's frontmatter `skills:` if preloaded
- Update `CLAUDE.md` + `README.md` counts and tables
- Run `./scripts/validate.sh`

Optional subdirectories: `scripts/` for executables (reference via `${CLAUDE_SKILL_DIR}` inside SKILL.md), `rules/` for progressive-disclosure detail files.

## Modifying an Agent

- **Keep prompts under ~800 words.** Long prompts get partially ignored.
- **Put critical rules first.** Ordering matters.
- **Use tables and numbered lists** over prose where possible.
- **Show exact `Agent(...)` syntax** when documenting dispatches.
- **Run the full pipeline on a real project** after architectural changes.

## Conventions

### Skills
- `SKILL.md` at the root, optional `scripts/` and `rules/` subdirectories
- Keep `SKILL.md` under 500 lines — push detail into `rules/*.md`
- `description` under 250 characters (truncated in the skill index)

### Commits
- One feature/fix per commit
- Subject line mentions the affected agent or skill
- Run the plugin on a real project before committing architectural changes to agents

### Versioning (semver)
- **Patch** — content tweaks, typos, doc updates
- **Minor** — new skill, new agent instruction, new MCP server
- **Major** — new agent, pipeline reorganization, breaking artifact-format changes

## Architecture Decisions

- **5 agents flat, 1 level deep.** Claude Code subagents can't spawn subagents. Only the main-thread orchestrator has the `Agent` tool.
- **Short agent prompts.** 2000-word prompts get partially ignored.
- **Generator-evaluator separation.** The evaluator is independent from the implementor to prevent self-evaluation bias.
- **Research from real docs.** Architect uses Context7 / DeepWiki / Exa MCPs, not training data.
- **Task-size classification.** The orchestrator can inline Micro tasks but must dispatch for anything larger. Smoke-mode evaluator exists so "inline" still gets an independent review.
- **Prompt edits over enforcement hooks.** When an agent breaks a rule, the fix is a clearer prompt, not a JSON state file or a PreToolUse blocker.

## Testing Changes

The test suite lives in `~/workspace/test-agents/`:
- **W1** — greenfield backend (Todo API)
- **W2** — fullstack with parallel dispatch (Blog dashboard)
- **W3** — brownfield (extend W2)
- **W4** — session recovery

```bash
cd ~/workspace/test-agents/W1-todo-api
rm -rf .coding-agent/
claude
# paste prompt from PROMPT.md
```

Check `.coding-agent/agent-log.txt` for the dispatch sequence (the `SubagentStart` hook writes to it).

## Known Issues

- `${user_config.exa_api_key}` in `.mcp.json` — plugin configs can't currently resolve this reference. Users must set `EXA_API_KEY` in their shell environment.
- No automated CI for the plugin repo itself. The `validate.sh` script is the gate.

## Development Notes

- Agent/skill changes are picked up on next session start — no reload command needed
- `.coding-agent/` is runtime state, gitignored, not source
- Test failures in the test suite usually reveal prompt ambiguity — fix the prompt, not the test
- Past design decisions and retrospectives live in `docs/`
