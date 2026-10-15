---
name: delivery-pipeline
description: Run coding-agent's canonical evidence-gated workflow in Codex, with the main task as conductor and bounded planner, developer, diagnostician, designer, and deployer subagents.
metadata:
  scope: conductor
  trigger: on-invoke
  category: protocol-helper
---

# Delivery Pipeline

Run the runtime through Codex subagents. Keep the main task focused
on state, user decisions, and gate transitions; delegate bounded worker moves.

## Resolve the plugin root

Derive the absolute plugin root from this skill's absolute path in the active
skills catalog by removing `/skills/general/delivery-pipeline/SKILL.md`. Use that
absolute path for every plugin file. When a referenced role prompt or example
contains `${CLAUDE_PLUGIN_ROOT}`, replace that marker with the resolved absolute
path before executing it; do not rely on a Codex environment variable.

Before a change workflow, read these files completely:

- `${CLAUDE_PLUGIN_ROOT}/agents/conductor.md`
- `${CLAUDE_PLUGIN_ROOT}/principles.md`

## Adapt the runtime to Codex

Apply these mappings; they override Claude-specific wording in the role files:

| Role prompt wording | Codex behavior |
|---|---|
| `Task`, `Agent`, or `subagent_type` | Use Codex subagent/collaboration tools with a bounded brief. |
| `AskUserQuestion` | Ask from the main task. Workers return questions; they never decide for the user. |
| Claude tool names | Use the equivalent available Codex capability. |
| Claude model/tool frontmatter | Treat it as role intent; current Codex policy remains authoritative. |
| Claude lifecycle hooks | Do not claim they ran. Perform required preflights explicitly. |

Delegate only where a separate agent adds judgment (review, architecture,
diagnosis, design, deploy). Do not delegate simple answers, read-only
questions, or the building of quick and standard changes.

## Start or resume

1. Read the consumer project's `AGENTS.md` and inspect git state. Preserve all
   pre-existing work.
2. Run `bash "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh"` once. Codex runs no
   lifecycle hooks, so this is the explicit preflight: it gitignores
   `.coding-agent/` before any state is written and refreshes the git
   pre-commit gate. Read its output for resume state.
3. If `.coding-agent/CURRENT` identifies an active feature ledger, resume it. Read the
   ledger tail and evidence file; do not initialize competing state.
4. Otherwise initialize product and feature state with the absolute scripts:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/ca.sh" start <feature-slug> --lane quick|standard|deep
   ```

5. The main task becomes the conductor and sole writer of the ledger and
   `product.md`, and of the code in the quick and standard lanes.

## Run the loop

The main task is the conductor: it builds quick and standard changes itself and
delegates only where a separate agent adds judgment. Pick a lane first:

| Lane | Use when | Builds | Review |
|---|---|---|---|
| quick | small fix, no UI / architecture / deploy, diff well under 150 lines | main task | none while `reviewed?` measures the diff as small |
| standard | features, services, multi-file changes | main task | one read-only reviewer subagent |
| deep | user asks, or a one-way door (schema migration, public API, auth boundary, infra) | developer subagents | reviewer (+ dimension fan-out) |

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/ca.sh" start <slug> --lane quick|standard|deep
bash "${CLAUDE_PLUGIN_ROOT}/lib/ca.sh" next      # every gate + the next action, in one call
```

Then follow `NEXT`: `ca frame --answer "<user's words>" < frame.md`, build, `ca prove`,
review (standard/deep) then `ca verdict`, `ca commit -m "..." -- <paths>`,
`ca close --summary ... --learnings ...`. Judge transitions from gate output and
`evidence.jsonl`, never from worker prose.

Specialists and their role files:

| Kind | Worker reads |
|---|---|
| `frame`, `architect` (deep lane, architecture questions) | `${CLAUDE_PLUGIN_ROOT}/agents/planner.md` |
| `review` (all standard/deep), `build`/`prove` (deep only) | `${CLAUDE_PLUGIN_ROOT}/agents/developer.md` |
| `diagnose` | `${CLAUDE_PLUGIN_ROOT}/agents/diagnostician.md` |
| `design` | `${CLAUDE_PLUGIN_ROOT}/agents/designer.md` |
| `ship`, `rollback` | `${CLAUDE_PLUGIN_ROOT}/agents/deployer.md` |

Each dispatch brief must include the resolved plugin root, kind, gate, feature
slug, exact file scope, the base commit, the smallest relevant ledger/product
slice, and relevant packaged skill names. Tell the worker to:

- read its role file and applicable principle tiers before acting;
- treat `${CLAUDE_PLUGIN_ROOT}` as the resolved absolute root;
- avoid nested delegation;
- never write the ledger or `product.md`;
- record verification only through `lib/record.sh`;
- return the role file's structured contract, including `changed_paths`, skips,
  and assumptions.

When the planner returns `status: needs-input`, keep the main task active, ask
the bundled 1–3 system/component architecture questions, record the user's
answers, and re-dispatch the planner with them. Do not count discovery as a gate
failure and do not collapse it into the later one-way-door approval.

Parallel reviews are read-only dimension passes. One final aggregate reviewer
alone writes `review.md`; sibling agents never append to the same file.

## Preserve evidence and authority

- Record every verification command through:

  ```bash
  bash "${CLAUDE_PLUGIN_ROOT}/lib/record.sh" "<command>" <kind> [tier]
  ```

- For `kind=test`, use the exact `test-command-<tier>:` value in the frozen
  intent. A different command is rejected even when it exits successfully.

- The conductor owns all user interaction and records the user's actual reply
  when freezing intent. Never manufacture approval.
- Require explicit user agreement for one-way architecture decisions, design
  approval, destructive actions, deployment, and push.
- Never let an agent approve its own design.
- Apply the conductor's two-strike rule. After the same gate blocks twice with
  no new evidence id, log the escalation and wait for the user.

## Keep git safe

- Never stage `.coding-agent/`. `clean?` blocks a commit that stages it.
- Never bypass the pre-commit gate with `--no-verify`; a refused commit is a
  gate block to route, not an obstacle.
- Stage only explicit paths attributable to the dispatched worker after comparing
  them with its pre-dispatch snapshot. Never use a repo-wide `git add` pathspec.
- Never use `git add -A`, `git add .`, `git reset --hard`, or `git clean`.
- Stage explicit source paths only after implementation and before `clean?`.
- Commit or push only when authorized by the request and repository instructions.

Complete only when every applicable gate passes against the current tree, the
requested changes exist on disk, review has no blocking findings, and all skips,
risks, and remaining user actions are stated plainly.
