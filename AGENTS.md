# Development workflow — coding-agent

This file is the contributor contract for the plugin itself. Consumer projects
may generate their own AGENTS.md; do not copy plugin-runtime details into them.

## What this is

A Claude Code and Codex plugin: 6 registered agents, 60 skills, 8 executable
gates, 12 artifact/documentation templates, 2 runtime libraries, 2 lifecycle
hooks plus a git pre-commit gate, and 5 optional MCP servers. The runtime has one conductor, five bounded worker roles,
and three primitives: ledger, evidence, and gate.

Codex enters through the `delivery-pipeline` skill. Claude Code registers the six
role prompts directly and selects the conductor in `settings.json`.

## Project structure

```text
coding-agent/
├── .agents/plugins/marketplace.json # repo-local Codex marketplace
├── .claude-plugin/plugin.json       # Claude Code manifest
├── .codex-plugin/plugin.json        # Codex local-plugin manifest
├── .mcp.json                        # 5 optional MCP servers
├── agents/                          # conductor + 5 worker prompts
│   ├── conductor.md    planner.md       developer.md
│   └── diagnostician.md designer.md     deployer.md
├── gates/                           # 8 predicates + shared helpers
│   ├── framed.sh       architected.sh   designed.sh   proven.sh
│   ├── reviewed.sh     clean.sh          shipped.sh    observed.sh
│   └── lib.sh
├── lib/                             # ledger.sh + record.sh
├── hooks/                           # evidence wall, session resume, pre-commit gate
├── skills/                          # 60 scoped engineering skills
│   ├── frontend/ backend/ data/ mobile/ infra/
│   └── general/ practices/
├── templates/                       # 12 runtime + portable-doc templates
├── scripts/
│   ├── validate.sh                  # plugin self-validator
│   ├── validate-skill-freshness.sh  # version-guidance expiry gate
│   ├── design-review.sh             # browser review controller
│   ├── design-review-server.py      # stdlib localhost server
│   ├── design-review.html           # review application
│   └── setup-external-skills.sh
├── evals/                           # scenario prompts + artifact assertions
├── docs/concepts/                   # canonical runtime design
├── README.md                        # project landing page
├── ARCHITECTURE.md                  # topology + component contracts
└── CHANGELOG.md
```

## Architecture invariants

- **Three primitives, nothing more:** ledger, evidence, gate.
- **One coordinator writer:** only the conductor edits ledger/product state.
- **One evidence writer:** only `lib/record.sh` appends `evidence.jsonl`.
- **Current-tree proof:** evidence cannot clear a gate after source changes.
- **Frozen command contract:** test evidence must use the intent’s exact command
  for that tier.
- **User owns authority:** never invent intent agreement, a one-way-door
  decision, design approval, destructive action, deployment, or push consent.
- **Separate role instances:** each bounded dispatch is a worker instance; a
  role is not a personality toggle on the conductor.
- **Architecture dialogue first:** ask design-changing system/component questions
  before drafting an ADR.
- **Explicit staging:** never stage `.coding-agent/`, unrelated changes, or a
  repo-wide pathspec. `clean?` blocks staged coordinator state.
- **Commit wall:** while a feature is active, the git pre-commit gate refuses a
  commit past an unmet gate. Agents never pass `--no-verify`.
- **Human design verdict:** `designed?` re-verifies the browser verdict against
  `design.html` itself; a recorded command alone is never approval.
- **Portable consumer docs:** project docs never mention plugin runtime state or
  vendor-specific instructions.

## After making changes

Run this checklist whenever you edit an agent, gate, library, hook, skill,
template, script, eval, manifest, or canonical doc:

1. Run `./scripts/validate.sh`; it must end in `PASSED`.
2. Run `evals/run.sh 00-smoke` and `evals/run.sh 08-wall-integrity` after any
   runtime script, gate, hook, agent, or template change.
3. If a skill contains version-sensitive guidance, update `skills/freshness.json`
   and run `./scripts/validate-skill-freshness.sh`.
4. If inventory changes, update the pinned counts in `scripts/validate.sh`,
   then copy them into this file, README badges/text, both manifests and
   marketplace files, the docs index, and the architecture document.
5. Update `CHANGELOG.md` and bump versions unless the edit is a truly internal
   typo that changes no published behavior.
6. Inspect `git diff --check`, JSON validity, shell syntax, and the final scoped
   diff.
7. Commit one logical change. Push only when the user asks.

## Versioning

- **Patch:** documentation corrections and non-behavioral fixes.
- **Minor:** a new skill, gate, agent instruction, hook behavior, or compatible
  runtime capability.
- **Major:** primitive changes, agent additions/removals, breaking artifact
  formats, or replacing the canonical runtime.

Keep `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` on the same
semantic version. The Codex manifest may add `+codex.<UTC timestamp>` build
metadata for local-plugin refreshes.

Prepend a dated changelog entry with Added/Changed/Fixed/Removed sections as
applicable.

## Modifying an agent

- Keep prompts compact; target 300 lines or fewer (conductor may approach 350).
- Put critical rules first and use tables/lists for routing.
- Reference `${CLAUDE_PLUGIN_ROOT}/principles.md`, gates, and libraries instead
  of duplicating their contracts.
- Frontmatter fields: `name`, `description`, `model`, `effort`, `tools`, and
  optional `skills`.
- Worker returns must preserve: `did`, `changed_paths`, `evidence_ids`,
  `gate_status`, `open_questions`, and `skipped_or_assumed`.
- Worker prompts must not gain ledger/product write authority or nested
  delegation.

## Adding or changing a gate

A gate lives at `gates/<name>.sh`, sources `gates/lib.sh`, and:

- observes current state without repairing it;
- emits exactly one JSON result through `gate_result`;
- uses `pass`, `block`, or `n/a` semantics;
- binds execution claims to current evidence;
- is referenced from conductor routing and documented in README/architecture if
  it changes the delivery arc.

Add or update smoke assertions for every load-bearing condition.

## Adding a skill

```text
skills/<category>/<skill-name>/
├── SKILL.md
├── rules/       optional progressive detail
└── scripts/     optional deterministic helpers
```

Required frontmatter:

```yaml
---
name: <skill-name>
description: <when this knowledge should be used; under 250 characters>
---
```

Keep SKILL.md under 500 lines and move details into `rules/`. Reference bundled
resources relative to `${CLAUDE_SKILL_DIR}`. Add domain-specific skills to the
conductor routing table or relevant worker preload list. The validator pins the
skill count; when you add a skill, bump it there and sync the docs (checklist
step 4).

## Paths

- Plugin internals: `${CLAUDE_PLUGIN_ROOT}/...`
- Skill-local resources: `${CLAUDE_SKILL_DIR}/...`
- Consumer runtime state: `.coding-agent/...`
- Consumer committed docs: normal repository paths such as
  `docs/architecture.md`

Never use `../` to connect plugin internals; marketplace caches can change the
installation parent directory.

## Documentation architecture

For this repository:

- README owns product overview, install, first use, and navigation.
- ARCHITECTURE owns high-level topology and component-level contracts.
- `docs/concepts/` owns detailed semantics and workflow.
- AGENTS owns contributor mechanics and invariants.
- CHANGELOG owns historical release evolution.

For consumer projects, follow `skills/practices/project-docs/SKILL.md`: one fact,
one owning file; system topology in `docs/architecture.md`; substantial
component contracts in `docs/components/`; other docs link rather than copy.

## Testing

The in-repo harness judges artifacts, evidence, and Git state—not prose:

```bash
evals/run.sh 00-smoke
evals/run.sh 08-wall-integrity
evals/run.sh all
evals/run.sh 03-escalation --manual
evals/compare.sh evals/results/<A> evals/results/<B>
```

`00-smoke` and `08-wall-integrity` are the zero-cost runtime tests and must pass
after any runtime edit.
Headless scenarios require an authenticated `claude` CLI running as a non-root
user (`bypassPermissions` is refused under root). Manual scenarios are for
interactive human gates.

## Commit convention

- Use `type(scope): subject`, or `release: vX.Y.Z — summary` for a release bump.
- One logical change per commit.
- Include:

  `Co-Authored-By: Claude <noreply@anthropic.com>`

- Do not push unless the user asked.

## Known operational requirements

- Exa requires `EXA_API_KEY` in the shell; plugin config cannot resolve a user
  config placeholder reliably.
- Agent, skill, gate, and hook changes are picked up on the next session/task.
- `.coding-agent/` is runtime state and must remain gitignored.
- There is no build step; validation and evals are the release gates.
