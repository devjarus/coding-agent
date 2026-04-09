# Contributing to coding-agent

Thanks for your interest in improving the plugin. This project has been shaped by real-world use — every fix comes from a bug we actually hit. Your contributions should follow the same principle: **if you can't point to a real failure, don't add it.**

## Ways to Contribute

- **Bug reports** — open an issue describing what you ran, what happened, what you expected
- **New skills** — specialist knowledge for a domain/framework not yet covered
- **Agent prompt improvements** — if you see an agent skipping instructions, propose a shorter/clearer prompt
- **New MCP integrations** — additional tools for research, testing, or deployment
- **Retrospectives** — real-world usage reports in `docs/` help shape the next iteration

## Before You Start

1. **Read the architecture** — `README.md` + `AGENTS.md` + the actual agent prompts in `agents/*.md`
2. **Check existing issues** — someone may have proposed the same thing
3. **For large changes** — open an issue first to discuss the approach

## Development Setup

No build step. Clone, edit, test.

```bash
git clone https://github.com/your-username/coding-agent
cd coding-agent

# Point Claude Code at your local copy
claude --plugin-dir $(pwd)
```

## Testing Your Changes

The real test is running the plugin on a project. There's a test suite at `~/workspace/test-agents/` with canonical scenarios:

- **W1** — greenfield backend (Todo API)
- **W2** — fullstack with parallel dispatch (Blog dashboard)
- **W3** — brownfield (add features to W2)
- **W4** — session recovery

For a new skill, pick a test project that exercises it. For agent prompt changes, run the full pipeline end-to-end and verify the agent-log shows the correct dispatch sequence.

### Running `validate.sh`

```bash
./scripts/validate.sh
```

Checks:
- All agent frontmatter is valid
- All skill SKILL.md files have required fields
- Required model values are one of: `opus`, `sonnet`, `haiku`, `inherit`

## Pull Request Process

1. **Fork** the repo
2. **Branch** — `feat/skill-name` or `fix/agent-issue` or `docs/topic`
3. **Commit** — one logical change per commit, clear message
4. **Test** — run on at least one real project
5. **PR description** — include:
   - What failure case this addresses (or what new capability it adds)
   - What you tested on
   - Any trade-offs considered

## Contribution Guidelines

### Adding a New Skill

Follow Anthropic's skill pattern:

```
skills/<category>/<skill-name>/
├── SKILL.md              # entry point (required)
├── rules/                # optional: progressive disclosure
│   └── detail.md
└── scripts/              # optional: bundled executables
    └── helper.sh
```

Rules:
- `SKILL.md` frontmatter must include `name` and `description`
- Description is under 250 characters and front-loads the key use case
- Keep `SKILL.md` under 500 lines — move detail to `rules/`
- Reference scripts via `${CLAUDE_SKILL_DIR}/scripts/name.sh` inside SKILL.md

### Modifying Agent Prompts

- **Keep it short** — agents skip instructions in long prompts. Aim for under 800 words per agent.
- **Structure first** — tables for decision trees, numbered steps for processes
- **Be explicit** — show exact Agent tool call syntax, exact script paths
- **One change at a time** — don't rewrite the whole prompt in one PR

### Code Style

- Markdown: GitHub-flavored, ATX-style headers (`#`, not underlines)
- Shell scripts: `set -uo pipefail`, comments for non-obvious logic
- JSON: 2-space indent

## Skills Inspired by Other Sources

Many skills in this plugin are inspired by or derived from patterns in public skill repositories. When adding a skill that's based on someone else's work:

1. **Credit the source** in `ACKNOWLEDGMENTS.md`
2. **Don't copy-paste** — rewrite in our plugin's voice and structure
3. **Add our own angle** — link it to our agents and pipeline

## Reporting Bugs

Good bug reports include:

- **The exact prompt** you gave the plugin
- **The agent-log** showing what was dispatched
- **The artifacts** produced (`.coding-agent/` contents)
- **What you expected** vs what happened

Agent misbehavior bugs should include the relevant agent prompt and which step was skipped.

## Questions

Open a [Discussion](https://github.com/your-username/coding-agent/discussions).

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
