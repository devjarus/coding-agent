# coding-agent — plugin notes

Claude Code reads this file at session start. It's intentionally short. Authoritative content lives elsewhere.

## What this plugin is

Multi-agent software development pipeline. **5 agents**, **54 skills**, **9 protocols**, **9 checks**, **8 templates**, **7 MCP servers**.

For users → [README.md](README.md)

## When working on this plugin

| You want to... | Read |
|----------------|------|
| Understand the design from scratch | [`docs/concepts/primitives.md`](docs/concepts/primitives.md) |
| Walk through a real session step-by-step | [`docs/concepts/workflow.md`](docs/concepts/workflow.md) |
| See artifact states and protocols | [`docs/concepts/lifecycle.md`](docs/concepts/lifecycle.md) |
| See the topology with diagrams | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Add a skill, modify an agent, validate changes | [AGENTS.md](AGENTS.md) |
| Understand how a specific agent works | `agents/<name>.md` |
| See a specific protocol | `protocols/<name>.md` |
| See a specific check's logic | `checks/<name>.sh` |
| See an artifact template | `templates/<name>.template.md` |

## Conventions Claude should follow in this repo

- **Validate before commit:** `./scripts/validate.sh`
- **Plugin-internal references** use `${CLAUDE_PLUGIN_ROOT}/...` (survives marketplace caching)
- **User project artifacts** use `.coding-agent/...` (relative to project root)
- **Approved artifacts are immutable.** Never edit `intent.md`, `spec.md`, `plan.md` after `state: approved`. Amendments go in `work.md § Plan Revisions` with `Supersedes:` pointer.
- **Only the orchestrator dispatches.** Subagents never call `Agent` even if inherited.
- **Only the orchestrator owns user gates.** Subagents never call `AskUserQuestion`; they return `ask_user.questions` for the orchestrator to surface.
- **Prompt edits over enforcement hooks.** When a rule fails, fix the prompt or convert to a check — don't add PreToolUse blockers.
- **Tests committed > scripts.** Evaluator runs your test suites; missing tests are findings, not gaps to paper over with bash.

## Versioning

Semver. See [CHANGELOG.md](CHANGELOG.md) for the full trail.
