# coding-agent

**A Claude Code plugin for shipping real software, not just writing code that compiles.**

Drop-in multi-agent pipeline that turns `"build me a notifications system"` into shipped, tested, reviewed code — with human checkpoints at the decisions that matter and real runtime verification before anything ships.

[![Version](https://img.shields.io/badge/version-2.0.1-blue)]() [![Agents](https://img.shields.io/badge/agents-5-green)]() [![Skills](https://img.shields.io/badge/skills-54-green)]() [![License](https://img.shields.io/badge/license-MIT-blue)]()

---

## What you get

- **A real pipeline, not a one-shot.** Intent → Spec → Plan → Implement → Review → Commit. Each stage has an owner, an artifact, and a deterministic check.
- **Human gates at the right spots.** You approve intent, spec, plan, and push. No agent fakes your signature.
- **Runtime testing, not just typechecks.** The reviewer launches your app in a real browser (Playwright) or iOS simulator, takes screenshots, runs your committed test suites. "Compiles" isn't evidence.
- **Memory across sessions.** Decisions, gotchas, and patterns survive. Tomorrow's architect reads yesterday's learnings. No cold starts.
- **Research from real docs, not stale training data.** Architect queries Context7 / Exa / DeepWiki for current library APIs. No more `shadcn v2` flags in a v4 project.
- **Per-task skill manifest.** Architect picks the right specialist skills for each task. Implementor loads them on dispatch. No one-size-fits-all prompt.
- **Zero-ceremony touch-ups.** Fix a button color? One intent gate, smoke review, commit. Full pipeline only when the work warrants it.

## Why this exists

Most AI coding tools happily generate code that compiles and breaks at runtime. They skip the design step, hallucinate library APIs, never actually launch the app, silently swallow errors, and forget everything the moment you close your terminal.

coding-agent is a reaction to those failures — an opinionated pipeline built from real pain:

| Failure mode | How the plugin handles it |
|---|---|
| "It compiles but the button is broken" | Evaluator runs Playwright against the live UI and screenshots it before PASS |
| "The architect hallucinated an API" | Architect must cite MCP queries (Context7/Exa) for stack and test-infra decisions |
| "Approvals got forged" | Only the orchestrator can call AskUserQuestion; subagents write drafts with blank signatures |
| "Same bug twice" | After a fix fails, next round routes to the Debugger (not another Implementor) |
| "Parallel work broke everything" | Plan declares explicit parallelism; orchestrator fans out only when declared |
| "The evaluator skipped screenshots" | Orchestrator's `ui-evidence.sh` check verifies screenshots exist before commit |
| "Learnings evaporated" | Close-out distills decisions/gotchas/patterns into `learnings.md`; every new feature reads it first |

---

## Install

```bash
git clone https://github.com/devjarus/coding-agent ~/.claude/plugins/coding-agent
# or point to a working tree during development:
claude --plugin-dir /path/to/coding-agent
```

## Setup (per project, one command)

```bash
bash ~/.claude/plugins/coding-agent/scripts/setup.sh
```

Writes `.claude/settings.local.json` with recommended permissions (broad allow + narrow ask for dangerous ops), enables all plugin MCPs, auto-detects iOS, updates `.gitignore`. Restart Claude Code to pick it up.

## First run

```bash
cd ~/my-project
claude
```

Then type something concrete:

> *"Build a notes API with Node + SQLite. Endpoints for POST /notes (text + tags) and GET /notes?tag. Integration tests required."*

What happens next:

```
Orchestrator: classifies (medium feature), proposes path → AskUserQuestion
You: approve

Architect:   reads profile + learnings.md
             bundles stack decisions + discovery questions
             → returns ask_user to orchestrator
Orchestrator: surfaces questions in ONE AskUserQuestion
You: confirm stack

Architect:   researches test infra (Context7/Exa)
             writes spec.md → orchestrator prints it in chat
             → AskUserQuestion to approve
You: approve spec (Gate 2)

Architect:   writes plan.md with per-task skill manifest + test tiers
             → orchestrator prints it, AskUserQuestion
You: approve plan (Gate 3)

Implementor: loads skills from plan, writes tests first, implementation
             returns structured update
Orchestrator: applies to work.md

Evaluator:   npm test + integration tests
             (no runtime — not a UI project)
             writes review.md: PASS

Orchestrator: close-out — archives feature, distills to learnings.md,
              updates AGENTS.md if conventions changed
              shows diff + commit message → AskUserQuestion
You: approve push (Gate 4)

Done.
```

Four human gates (intent, spec, plan, push) + one architect discovery prompt per feature. Everything else is automated.

---

## How it works

Five agents, six artifact categories, nine named protocols, nine deterministic checks.

```
                          You
                           │
                           ▼
                    ┌─────────────┐
                    │ Orchestrator│ ← state machine, dispatches, never writes code
                    └──┬──────────┘
                       │
         ┌─────────────┼──────────────┬────────────┐
         ▼             ▼              ▼            ▼
    ┌─────────┐  ┌───────────┐  ┌─────────┐  ┌─────────┐
    │Architect│  │Implementor│  │Evaluator│  │Debugger │
    │ (design)│  │  (build)  │  │ (review)│  │(diagnose)│
    └────┬────┘  └─────┬─────┘  └────┬────┘  └────┬────┘
         │             │             │             │
         └─────────────┴─────────────┴─────────────┘
                       │
                       ▼
        .coding-agent/features/<slug>/
        intent.md → spec.md → plan.md → work.md → review.md
```

**Full architecture with ASCII diagrams:** [ARCHITECTURE.md](ARCHITECTURE.md)

**Design principles** (four primitives, immutability, supersession): [docs/concepts/primitives.md](docs/concepts/primitives.md)

**Canonical flow walkthrough:** [docs/concepts/workflow.md](docs/concepts/workflow.md)

**Artifact lifecycle + protocols catalog:** [docs/concepts/lifecycle.md](docs/concepts/lifecycle.md)

---

## Daily use — three common workflows

### 1. Greenfield feature

```
You:    "Build a rate-limiter middleware with Redis"
Gates:  Intent → Discovery → Spec → Plan → Push (4 approvals)
Output: Committed feature + learnings entry + updated AGENTS.md
```

### 2. Touch-up (fix, tweak, small addition)

```
You:    "The login button should be brand blue (#1A73E8)"
Gates:  Intent → Push (2 approvals)
Output: One-file change, smoke review, commit
```

### 3. Multi-feature session

```
You:    "Build A. Now add B. Now fix C."
        Each restates → approves → ships → next.
        Learnings carry forward; no contamination.
        Close-out between features is automatic.
```

---

## Configuration

### MCP servers (`.mcp.json` — enabled in settings)

| Server | Used by | Purpose |
|--------|---------|---------|
| `context7` | architect, implementor, debugger, evaluator | Current library docs (memory is stale) |
| `exa` | architect, implementor, evaluator | Web search for release notes, migration guides |
| `deepwiki` | architect | GitHub repo deep-dives |
| `playwright` | evaluator | Browser UI testing (required for UI PASS) |
| `chrome-devtools` | evaluator | Console + network inspection |
| `xcodebuild` | evaluator (iOS) | Build/test |
| `ios-simulator` | evaluator (iOS) | Simulator control |

### Permissions

`scripts/setup.sh` writes `.claude/settings.local.json` with:

- **`defaultMode: acceptEdits`** — no prompts for Read/Edit/Write/Bash/MCP
- **`allow`**: blanket access to all normal tools
- **`ask`**: `git push`, `rm -rf`, `sudo`, `npm publish` still prompt
- **`deny`**: `rm -rf /` and `rm -rf ~` outright blocked

**For parallel-implementor scenarios**: Bash patterns may not inherit reliably from `settings.local.json` to parallel subagent batches. If you see permission prompts during parallel work, move the permissions block to `settings.json` (project-shared).

### Profile

Edit `~/.coding-agent/profile.md` to set your stack defaults — architect reads it on every session and skips questions you've already answered (Next 15? shadcn? TanStack Query? All pre-filled.)

---

## Documentation

| Doc | For |
|-----|-----|
| [ARCHITECTURE.md](ARCHITECTURE.md) | How the pipeline works internally, with ASCII diagrams |
| [docs/concepts/primitives.md](docs/concepts/primitives.md) | The four primitives (Actor / Artifact / Skill / Check), invariants, supersession rule |
| [docs/concepts/workflow.md](docs/concepts/workflow.md) | Canonical happy-path walkthrough (T=0 → T=10), Micro/Touch-up state machines |
| [docs/concepts/lifecycle.md](docs/concepts/lifecycle.md) | Artifact states, close-out protocol, fix-round escalation, recovery |
| [AGENTS.md](AGENTS.md) | Working on the plugin itself (meta-dev guide) |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contributing back |
| [CHANGELOG.md](CHANGELOG.md) | Version history |

---

## Status

v2.0.1. Used daily on real projects (blog platforms, research agents, iOS apps). Each iteration shaped by actual failures — see [CHANGELOG.md](CHANGELOG.md) for the full trail and [docs/concepts/](docs/concepts/) for the design rationale.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Design conversations start with opening an issue.

## Acknowledgments

See [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md). Inspired by [skills.sh](https://skills.sh), Anthropic's [official skills](https://github.com/anthropics/skills), and harness-design principles from Anthropic's research team.

## License

MIT — [LICENSE](LICENSE).
