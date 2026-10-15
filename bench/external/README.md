# External benchmarks

`bench/` tasks were written alongside the plugin. These runs check it against
benchmarks nobody here wrote. Every arm is Claude Code on the same model with the
same prompt footer; only what is added differs:

| Arm | Class in `harbor_agents.py` | Adds |
|---|---|---|
| native | `NativeClaude` | nothing |
| rules control | `RulesControl` | `bench/arms/$CODING_AGENT_RULES_ARM/CLAUDE.md` (default `rules3`) as `--append-system-prompt` |
| plugin | `CodingAgentPlugin` | this plugin, uploaded to the task container, `--plugin-dir` |

Requirements: Docker running, Python ≥ 3.12, `ANTHROPIC_API_KEY`, and
[Harbor](https://pypi.org/project/harbor/) (`harbor_agents.py` targets 0.24.0).
The adapter was checked against Harbor's source, not executed: run one task per
arm first (step 2) before spending on a slice.

## Terminal-Bench 2.0 (correctness floor)

89 hard command-line tasks. Question it answers: does the plugin's overhead cost
correctness on hard single-session work?

```bash
# 1. install Harbor
uv tool install harbor==0.24.0        # or: pipx install harbor==0.24.0
harbor run --help | head -40          # confirm the flags below exist in your version
harbor dataset list | grep -i terminal  # confirm the dataset id (Harbor 0.24 uses terminal-bench@2.0)

# 2. smoke: one task per arm (minutes, cents to a few dollars)
for a in NativeClaude RulesControl CodingAgentPlugin; do
  PYTHONPATH=. harbor run -d terminal-bench@2.0 -m anthropic/claude-sonnet-5 \
    --agent bench.external.harbor_agents:$a -l 1 -o /tmp/tb2/smoke-$a
done

# 3. the slice: the same 20 tasks for every arm (fix the task list so arms are comparable)
for a in NativeClaude RulesControl CodingAgentPlugin; do
  PYTHONPATH=. harbor run -d terminal-bench@2.0 -m anthropic/claude-sonnet-5 \
    --agent bench.external.harbor_agents:$a -l 20 -n 4 -o /tmp/tb2/slice-$a
done
```

`-l` caps the task count after filters; if your Harbor version does not pick the
same tasks every time, list them explicitly with `-i <task-name>` (repeatable).
Compare resolved rate, cost and wall time per arm from each jobs directory.
Target (from `bench/goal.json`): plugin resolved rate ≥ native.

## SlopCodeBench (code quality over many iterations)

Agents repeatedly extend their own code; scored on checkpoint pass rate plus
erosion (complexity concentrating in a few functions) and verbosity (redundant
code). The best test of whether review and gates keep a codebase from rotting.
Before planning a run, confirm its harness is public (NeurIPS 2026 poster:
https://neurips.cc/virtual/2026/poster/138903) and whether it accepts a custom
Claude Code command; if it does, give it the three arms above.

## SWE-EVO (real repositories)

48 release-note-sized tasks on 7 mature Python projects (~21 files each), with
partial credit. Repository: https://github.com/bdqnghi/SWE-EVO — follow its
README for the harness, then run the three arms on a small slice.
