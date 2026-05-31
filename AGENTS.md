# Development Workflow — Plugin Self

This file tells agents (and humans) how to work on the coding-agent plugin itself. (For consumer-project AGENTS.md, see what individual projects generate during close-out.)

## What This Is

A Claude Code plugin: 5 agents + 55 skills + 10 named protocols + 16 deterministic checks + 12 artifact templates + 5 MCP servers. All Markdown + Bash. No build step.

## Project Structure (v2)

```
coding-agent/
├── .claude-plugin/plugin.json    # plugin manifest
├── .mcp.json                     # MCP server config
├── agents/                       # 5 agent prompts (each ≤300 lines, references protocols)
├── skills/                       # 55 skill folders, each with SKILL.md
│   ├── frontend/   backend/   data/   mobile/   infra/
│   ├── general/   practices/
├── protocols/                    # 10 named multi-actor workflows
│   ├── intake.md   research.md   spec-writing.md   plan-writing.md
│   ├── implementation.md   review.md   fix-round.md
│   ├── close-out.md   redirect.md   recovery.md
├── checks/                       # 16 deterministic verification scripts
│   ├── lib.sh                    # shared helpers (sourced)
│   ├── intent-approved.sh    spec-approved.sh    plan-approved.sh
│   ├── ui-evidence.sh   no-raw-print.sh   close-out-complete.sh
│   ├── action-logged.sh   active-feature-consistent.sh   revisions-resolved.sh
│   ├── env-vars-present.sh   no-secrets-staged.sh   review-passed.sh
│   ├── stack-justified.sh   test-infra-declared.sh   tests-actually-committed.sh
│   ├── commit-gate.sh            # composite: review-passed→tests-committed→no-secrets→last-verify
├── templates/                    # 12 artifact frontmatter templates
│   ├── intent.template.md   spec.template.md   plan.template.md
│   ├── work.template.md   review.template.md   diagnosis.template.md
│   ├── research.template.md   session.template.md   learnings.template.md
│   ├── deployments.template.md   environments.template.md   open-threads.template.md
├── hooks/hooks.json              # SessionStart context-inject + PreCompact breadcrumb + SubagentStart logging + PostToolUse validation
├── scripts/
│   ├── validate.sh               # plugin self-validator
│   ├── post-edit-validate.sh     # called by PostToolUse hook
│   ├── session-start-context.sh  # SessionStart hook — injects resume state (CURRENT, open-threads, action-log)
│   ├── pre-compact-checkpoint.sh # PreCompact hook — durable compaction breadcrumb to agent-log.txt
│   ├── run-and-record.sh         # runs verification, records exit+counts+tree → .coding-agent/last-verify.json
│   └── setup.sh                  # writes .claude/settings.local.json + installs commit-msg hook (blocks fabricated "verified" claims)
├── docs/
│   ├── README.md                 # docs index
│   └── concepts/                 # primitives, workflow, lifecycle (canonical design)
├── CHANGELOG.md
├── CLAUDE.md                     # short redirect index
├── README.md                     # project landing page
├── ARCHITECTURE.md               # topology + diagrams
└── AGENTS.md (this file)
```

## After Making Changes — Checklist

Run every time you edit an agent, skill, protocol, check, or doc:

1. **Run the validator** — `./scripts/validate.sh`. Must report PASSED before you commit (it lints protocol/check existence, frontmatter schema, and inventory counts).
   - **On inventory drift, the directory count wins.** Copy the validator's counts into the AGENTS.md "Project Structure" inventory line, then mirror them into `.claude-plugin/plugin.json` `description`, `.claude-plugin/marketplace.json`, and `ARCHITECTURE.md` / `docs/README.md` if they cite counts. Re-run until PASSED.

2. **If you added a skill**: add to the implementor's domain routing (if domain-specific) and to the agent frontmatter `skills:` list (if preloaded). The skill *count* is derived by the validator — don't hand-maintain it anywhere.

3. **If you added a protocol or check**: protocol → row in `protocols/README.md`; check → add to the `agents/orchestrator.md` checks list. Reference it from the agent prompt(s) that use it via `${CLAUDE_PLUGIN_ROOT}/<protocols|checks>/<name>.{md,sh}`.

4. **If you added an artifact category**: update `docs/concepts/primitives.md` Artifact Categories table AND create `templates/<name>.template.md`.

5. **Path conventions**:
   - Plugin internals: always `${CLAUDE_PLUGIN_ROOT}/...` (works in dev + marketplace cache)
   - User project artifacts: `.coding-agent/...` (relative to project root, set by user)
   - NEVER use relative `..` paths — they break in marketplace caching

6. **Update CHANGELOG.md + bump the version** (skip only for typos/pure-doc tweaks). This is not optional and not user-prompted — do it as part of the change, before committing:
   - **Semver** (see [Versioning](#versioning-semver)): patch = doc/typo; minor = new skill / protocol / check / agent instruction; major = primitive change or agent added/removed.
   - Prepend a dated entry to `CHANGELOG.md` (Added / Changed / Fixed) covering the change.
   - Set the new version in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, then re-run the validator.

7. **Commit**:
   - One logical change per commit; subject mentions the affected agent/skill/protocol/check (`type(scope): subject`), or `release: vX.Y.Z — summary` when the version bumped.
   - End the message with the `Co-Authored-By: Claude` line.
   - Push only when the user asks. PostToolUse hook validates frontmatter on every save.

## Adding a New Skill

```bash
mkdir -p skills/<category>/<skill-name>
cat > skills/<category>/<skill-name>/SKILL.md <<'EOF'
---
name: <skill-name>
description: <1-2 sentences — Claude uses this to decide when to apply. Under 250 chars.>
scope: any | architect | implementor | evaluator | debugger | orchestrator
trigger: always | on-match | on-invoke
category: domain-specialist | practice | protocol-helper | general
---

# <Title>

Content...
EOF
```

Then update CLAUDE.md routing tables and run validate.sh.

## Modifying an Agent

- **Keep prompts under 300 lines.** Long prompts get partially ignored.
- **Reference protocols, don't re-describe.** Use `${CLAUDE_PLUGIN_ROOT}/protocols/<name>.md`.
- **Critical rules first.** Ordering matters.
- **Tables and lists over prose.**

## Adding a Protocol or Check

- **Protocol**: write `protocols/<name>.md`. Add row to `protocols/README.md`. Reference from each agent that uses it.
- **Check**: write `checks/<name>.sh` (executable, exits 0/1, JSON output). Add to `agents/orchestrator.md` checks list. Source `lib.sh` for shared helpers.

## Conventions

### Agent prompts
- ≤300 lines target (orchestrator may be longer; aim for ≤350)
- Frontmatter: `name`, `description`, `model`, `tools`, `skills`
- Body: capabilities + protocols referenced + structured-return contract + hard rules + refusals

### Skills
- `SKILL.md` at root, optional `scripts/`, `rules/`
- ≤500 lines in `SKILL.md` (push detail to `rules/`)
- `description` ≤250 chars

### Commits
- One feature/fix per commit
- Subject references affected file/folder
- `Co-Authored-By: Claude` line

### Versioning (semver)
- Patch: typos, doc tweaks
- Minor: new skill / protocol / check / agent instruction
- Major: primitive change, agent removed/added, breaking artifact-format change

## Architecture Decisions

- **Four primitives, nothing more.** Actor / Artifact / Skill / Check. See [`docs/concepts/primitives.md`](docs/concepts/primitives.md).
- **Approved artifacts are immutable.** Amendments via `work.md § Plan Revisions` supersession.
- **Orchestrator owns coordinator state.** Subagents return structured updates.
- **Codified > scripted.** Tests are committed code, not ad-hoc curl pipelines.
- **`${CLAUDE_PLUGIN_ROOT}` for all plugin-internal references.** Survives marketplace caching.
- **Prompt edits over enforcement hooks.** When a rule fails, fix the prompt or convert to a Check — don't add a PreToolUse blocker.

## Testing Changes

The test suite lives in `~/workspace/test-agents/`:
- W1 — greenfield backend (Todo API)
- W2 — fullstack with parallel dispatch (Blog dashboard)
- W3 — brownfield (extend W2)
- W4 — session recovery

```bash
cd ~/workspace/test-agents/W1-todo-api
rm -rf .coding-agent/
claude
# paste prompt from PROMPT.md
```

Check `.coding-agent/session.md § Action Log` for the dispatch sequence.

## Known issues

- `${user_config.exa_api_key}` in `.mcp.json` — plugin configs can't resolve this. Users set `EXA_API_KEY` in shell env.
- No automated CI. `validate.sh` is the gate.

## Notes

- Agent/skill/protocol changes picked up on next session start
- `.coding-agent/` in user projects is runtime state, gitignored
- Test failures usually reveal prompt ambiguity — fix the prompt, not the test
- Canonical concepts and design rationale: [`docs/concepts/`](docs/concepts/)
