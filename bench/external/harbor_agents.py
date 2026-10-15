"""Harbor agents for external benchmarks (Terminal-Bench 2.0 and any Harbor dataset).

Three arms, all Claude Code on the same model and the same prompt footer, so the
only difference is what bench/run.sh compares too:

  NativeClaude        Claude Code as shipped
  RulesControl        + the CLAUDE.md of a seed arm (bench/arms/<arm>/), passed
                      with --append-system-prompt so the task repo is untouched
  CodingAgentPlugin   + this plugin, uploaded into the task container and loaded
                      with --plugin-dir (a snapshot without bench/ and .git)

Written against harbor 0.24.0 (`harbor.agents.installed.claude_code.ClaudeCode`).
Harbor imports `--agent module:Class` without adding the working directory to
sys.path, so run from the repository root with PYTHONPATH set:

  PYTHONPATH=. harbor run -d terminal-bench@2.0 -m anthropic/claude-sonnet-5 \\
      --agent bench.external.harbor_agents:CodingAgentPlugin -l 20 -n 4

See bench/external/README.md.

Environment: ANTHROPIC_API_KEY (or the auth Harbor's claude-code agent accepts);
CODING_AGENT_RULES_ARM picks the seed arm for RulesControl (default rules3).
"""
import os
import shlex
import shutil
import tempfile
from pathlib import Path

from harbor.agents.installed.claude_code import ClaudeCode

REPO = Path(__file__).resolve().parents[2]
REMOTE_PLUGIN = "/installed-agent/coding-agent"

# The same pre-agreement bench/run.sh appends: a headless session cannot ask.
FOOTER = (
    "\n\n---\nThis is a non-interactive session: I cannot answer questions or "
    "approve anything later, so these are my answers in advance, from me, the "
    "user. I agree to any reasonable interpretation of the request above; where "
    "something is unspecified, choose sensibly and list your assumptions at the "
    "end. Do not push or deploy. Finish the whole request in this session."
)


class NativeClaude(ClaudeCode):
    """Claude Code as shipped, with the shared footer."""

    async def run(self, instruction, environment, context):
        return await super().run(instruction + FOOTER, environment, context)


class RulesControl(NativeClaude):
    """Claude Code plus a seed arm's CLAUDE.md as appended system prompt."""

    def build_cli_flags(self) -> str:
        arm = os.environ.get("CODING_AGENT_RULES_ARM", "rules3")
        rules = (REPO / "bench" / "arms" / arm / "CLAUDE.md").read_text()
        flags = super().build_cli_flags()
        return (flags + " " if flags else "") + "--append-system-prompt " + shlex.quote(rules)


class CodingAgentPlugin(NativeClaude):
    """Claude Code with this plugin loaded via --plugin-dir."""

    async def install(self, environment) -> None:
        await super().install(environment)
        # The plugin's hooks and gates need git and python3 in the task image.
        await self.ensure_system_dependencies(environment, ("git", "python3"))
        snap = Path(tempfile.mkdtemp(prefix="coding-agent-plugin-")) / "plugin"
        shutil.copytree(
            REPO, snap,
            ignore=shutil.ignore_patterns(".git", "bench", "evals", "__pycache__", "*.pyc"),
        )
        await environment.upload_dir(snap, REMOTE_PLUGIN)
        await self.exec_as_root(environment, command=f"chmod -R a+rX {REMOTE_PLUGIN}")

    def build_cli_flags(self) -> str:
        flags = super().build_cli_flags()
        return (flags + " " if flags else "") + f"--plugin-dir {REMOTE_PLUGIN}"
