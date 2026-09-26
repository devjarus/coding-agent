# Contributing to coding-agent

Thanks for improving the plugin. Changes should address an observed failure,
make an invariant executable, or add scoped knowledge that materially improves a
worker decision.

## Before you start

1. Read [README.md](README.md), [ARCHITECTURE.md](ARCHITECTURE.md), and
   [AGENTS.md](AGENTS.md).
2. Inspect the relevant role, gate, library, hook, or skill rather than assuming
   its contract from a release note.
3. Open an issue before a major primitive, agent-set, or artifact-format change.

## Development setup

```bash
git clone https://github.com/devjarus/coding-agent
cd coding-agent
claude --plugin-dir "$(pwd)"
```

No build step is required.

## What to contribute

- Reproducible agent or gate defects
- Clearer, shorter role instructions
- Deterministic assertions for previously prose-only claims
- Engineering skills with a defined trigger and bounded scope
- MCP integrations that support research, testing, design review, or deployment
- Scenario evals derived from real failures
- Documentation corrections grounded in the current runtime

## Validation

Run before opening a pull request:

```bash
./scripts/validate.sh
evals/run.sh 00-smoke
evals/run.sh 08-wall-integrity
```

For broader runtime changes, also run `evals/run.sh all`. For version-sensitive
skills, update and validate `skills/freshness.json`.

## Agent changes

- Keep a worker stateless and bounded to its dispatch.
- Preserve the structured return contract.
- Do not give workers ledger/product write access or nested delegation.
- Keep user questions and approvals in the conductor’s conversation.
- Add a smoke assertion when the instruction protects a load-bearing behavior.

## Gate and library changes

- Gates observe and return one JSON verdict; they do not repair state.
- Execution claims must remain bound to current evidence.
- `record.sh` remains the only evidence writer.
- Test evidence remains pinned to the frozen intent’s exact tier command.
- The pre-commit gate runs the pre-commit prefix of the arc; a gate added before
  `clean?` belongs in `hooks/pre-commit.sh` too.
- `designed?` verifies the human's verdict itself; never let it pass on a
  recorded command alone.
- Shell scripts use `set -uo pipefail` and pass `bash -n`.

## Skill changes

Use the standard shape:

```text
skills/<category>/<skill-name>/
├── SKILL.md
├── rules/       optional
└── scripts/     optional
```

Descriptions should state when the skill applies in fewer than 250 characters.
Keep the entry file below 500 lines, move detail to rules, and cite primary
sources for version-sensitive guidance.

## Pull requests

Include:

- the observed failure or capability gap;
- the design choice and important trade-offs;
- commands and scenarios run;
- screenshots for design-surface changes;
- any remaining risk or untested environment.

Use one logical commit per change and follow the version/changelog rules in
[AGENTS.md](AGENTS.md). If outside work inspired a skill, update
[ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md).

## Bug reports

Provide the exact prompt, plugin version, active role/kind, relevant ledger and
evidence excerpts with secrets removed, expected behavior, actual behavior, and
the smallest reproduction you can share.

## License

Contributions are licensed under the repository’s [MIT License](LICENSE).
