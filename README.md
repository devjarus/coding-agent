# coding-agent

> A Claude Code plugin for shipping software end-to-end. Multi-agent pipeline with deterministic gates, codified testing, and real runtime verification.

**v2.0** · **5 agents** · **~58 skills** · **9 protocols** · **10 checks** · **7 MCP servers**

Turns a vague prompt like *"build me a blog with comments"* into a structured pipeline:

```
intake → spec (you approve) → plan (you approve) → implement (parallel where safe)
       → review (real Playwright/sim, runs your test suites)
       → close-out (distill learnings, archive, update docs)
       → commit (you approve push)
```

## Why v2

v1 grew through accretion: every recurring failure became more prose, more artifacts, more rules. Result: thorough but slow, and the same prose rules kept being violated. v2 is a first-principles redesign around four primitives.

| Symptom in v1 | v2 fix |
|---|---|
| Prose rules ignored after 5 dispatches | Replaced with deterministic Checks (bash scripts) |
| 9+ artifact types scattered | Collapsed to 5 categories with explicit mutability classes |
| Approved spec/plan rewritten mid-implementation | Immutable; amendments live in `work.md § Plan Revisions` with `Supersedes:` pointer |
| Evaluator skipped Playwright | `ui-evidence.sh` check verifies `screenshots/` non-empty before PASS |
| Multi-writer races on `progress.md` | One Orchestrator-owned `work.md`; subagents return structured updates |
| No audit trail for inline Micro edits | `session.md § Action Log` (append-only) — every Orchestrator action logged |
| Test scripts evaporated after review | Codified > scripted: Evaluator runs your committed test suites; missing test = FAIL |
| No memory across sessions | `session.md` checkpoint + action log enable resume |

## The Four Primitives

| Primitive | Definition | Examples |
|-----------|------------|----------|
| **Actor** | Produces work | User + 5 agent types |
| **Artifact** | Durable on-disk state, typed, one writer per | `intent.md`, `spec.md`, `plan.md`, `work.md`, `review.md`, `diagnosis.md`, `session.md`, `learnings.md` |
| **Skill** | Scoped knowledge an Actor loads | domain-specialist / practice / protocol-helper / general |
| **Check** | Deterministic verification (bash, no LLM) | `intent-approved`, `ui-evidence`, `close-out-complete`, `no-raw-print`, etc. |

Everything else (Protocol, Session, Pipeline) composes from these. Full design: `docs/redesign/primitives.md`.

## The Five Agents

| Agent | Model | Role | Owns |
|-------|-------|------|------|
| **orchestrator** | claude-opus-4-7 | Tech lead — state machine, dispatcher, check runner | `work.md`, `session.md`, `cache.json`, `CURRENT`, `learnings.md` |
| **architect** | opus | Staff eng — `spec.md` & `plan.md`, MCP-driven research | `spec.md`, `plan.md` (immutable after approval) |
| **implementor** | sonnet | Engineer — code + tests + structured returns | source/test files |
| **evaluator** | opus | QA — runs your test suites, drives Playwright/iOS-sim | `review.md`, `screenshots/` |
| **debugger** | opus | SRE — root cause, full or inspection mode | `diagnosis.md` |

Subagents return a structured YAML payload; orchestrator parses + applies to `work.md`. No multi-writer files.

## Quick Start

### Install

```bash
git clone https://github.com/devjarus/coding-agent ~/.claude/plugins/coding-agent
# or
claude --plugin-dir /path/to/coding-agent
```

### Per-project setup (one command)

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh
```

Writes a recommended `.claude/settings.local.json` (broad permissions, all plugin MCPs enabled) into the current project. Edit afterward to taste.

### Recommended `.claude/settings.local.json` (manually)

```json
{
  "agent": "coding-agent:orchestrator",
  "permissions": {
    "allow": [
      "Bash(*)", "Read(**)", "Write(**)", "Edit(**)", "MultiEdit(**)",
      "Glob(**)", "Grep(**)", "WebSearch", "WebFetch(*)",
      "Agent(*)", "AskUserQuestion", "Skill(*)",
      "mcp__*"
    ]
  },
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": [
    "context7", "exa", "deepwiki",
    "playwright", "chrome-devtools"
  ]
}
```

iOS: add `xcodebuild` and `ios-simulator` to `enabledMcpjsonServers`.

### Use it

```
You: "Build a todo API with Express and SQLite"

Orchestrator: classifies (medium feature) → AskUserQuestion approve path
You: approve

Architect (spec): asks discovery + tech-stack tradeoffs in one prompt
You: confirm
Architect: prints spec.md in chat → AskUserQuestion approve
You: approve (Gate 2)

Architect (plan): per-task skill manifests, per-wave test tiers (unit + integration + e2e), explicit parallel: blocks
You: approve (Gate 3)

Implementor: parallel where safe, serial otherwise. Returns structured updates.
Orchestrator: applies updates to work.md.

Evaluator: runs `npm test`, `npm run test:integration`, no UI so skips runtime
Returns review.md PASS

Orchestrator: close-out (8 steps) — archives feature, distills learnings, updates AGENTS.md
Shows diff + commit message → AskUserQuestion approve push
You: approve push (Gate 4)
```

## The Nine Protocols

Lifted out of agent prompts into one source of truth each:

| Protocol | Owner | When |
|----------|-------|------|
| `intake` | Orchestrator | every user request |
| `spec-writing` | Architect | medium/large features |
| `plan-writing` | Architect | medium/large features |
| `implementation` | Orchestrator | once plan approved |
| `review` | Evaluator | implementation complete |
| `fix-round` | Orchestrator | review FAIL (3 rounds before user escalation) |
| `close-out` | Orchestrator | review PASS, before commit (8 steps) |
| `redirect` | Orchestrator | new user message during active pipeline |
| `recovery` | Orchestrator | dispatch threshold or pivot |

See `protocols/`.

## The Ten Checks

Deterministic bash scripts — no LLM. A failed check blocks the transition. Replaces ~70 prose "MUST" rules.

| Check | Verifies |
|---|---|
| `active-feature-consistent` | CURRENT empty OR points to a non-archived feature |
| `intent-approved` | intent.md has `approved_by: user` footer |
| `spec-approved` | spec.md approved + has Tech Stack / Test Infra / Requirements sections |
| `plan-approved` | plan.md approved + tasks have `skills:` and `evaluation:` |
| `revisions-resolved` | no `Status: pending` revisions in work.md |
| `ui-evidence` | UI projects have non-empty `screenshots/` with descriptive filenames |
| `no-raw-print` | no `console.log` / `print()` / `fmt.Println` in production code |
| `close-out-complete` | all 8 close-out steps ran |
| `action-logged` | session.md action log has corresponding entry |

Plus the existing plugin-self validator: `./scripts/validate.sh`.

## Artifact lifecycle

```
draft ──(author signs)──> approved ──(work begins)──> active ──(close-out)──> archived
```

| Mutability | Rule |
|------------|------|
| **immutable** | Never written after state transition. Examples: approved `spec.md`/`plan.md`, archived feature dirs |
| **append-only** | Writes add content, never modify or delete. One writer. Example: `learnings.md` |
| **single-writer-mutable** | One owner writes; others return structured updates. Example: `work.md` |
| **composite** | Multi-section file, each section declares its own class. Example: `session.md` (Checkpoint + Action Log) |

**Approved artifacts are immutable forever.** Amendments live in `work.md § Plan Revisions` with `Supersedes: <file> §<section>` pointer. Original signature stays meaningful.

## Skills (~58)

Implementor's skill manifest is declared per task in `plan.md` by the Architect. Orchestrator passes it verbatim. No magic routing.

Categories:
- **Domain specialists**: react, next, postgres, swiftui, etc. (32)
- **Practices**: tdd, test-doubles-strategy, observability, security-checklist, etc. (24)
- **General**: debugging, git-workflow (2)

See `CLAUDE.md` for the full table.

## MCP Servers

| Server | Used by | Purpose |
|--------|---------|---------|
| context7 | architect, implementor | Current library docs (memory is stale; use this) |
| exa | architect | Web search for blog posts, release notes, migration guides |
| deepwiki | architect | GitHub repo deep-dives |
| playwright | evaluator | Browser UI testing |
| chrome-devtools | evaluator | Console + network inspection |
| xcodebuild | evaluator (iOS) | Build/test/debug |
| ios-simulator | evaluator (iOS) | Simulator control |

## Architecture (high-level)

```
              User
                │
                ▼
         ┌────────────┐    AskUserQuestion gates: Intent, Spec, Plan, Push
         │Orchestrator│ ◄──┐
         └─────┬──────┘    │
               │ dispatches│
   ┌───────────┼───────────┤    structured-return YAML
   ▼           ▼           ▼   │
┌────────┐ ┌─────────┐ ┌─────┐ │
│Architect│ │Implem'r│ │Eval'r│┘
└─────┬───┘ └────┬────┘ └──┬──┘
      │          │         │
      │  reads/  │  reads  │ runs npm test, Playwright,
      │  writes  │  writes │ writes review.md + screenshots/
      ▼          ▼         ▼
   ┌─────────────────────────┐
   │  features/<slug>/       │ ← user's project (.coding-agent/)
   │   intent.md spec.md     │
   │   plan.md  work.md      │
   │   review.md screenshots/│
   └────────┬────────────────┘
            │ close-out distills
            ▼
   ┌─────────────────────────┐
   │ .coding-agent/          │
   │   learnings.md  session.md │
   │   CURRENT  cache.json   │
   └─────────────────────────┘
```

Detailed: `docs/redesign/workflow-spec.md` and `ARCHITECTURE.md`.

## Status

Used on real projects: blog platforms, deep research agent, iOS apps, AI agent systems. v2 is a clean break from v1 (no migration; v1 archives stay readable but aren't consumed).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Design docs in `docs/redesign/`.

## Acknowledgments

See [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md). Inspiration from skills.sh, Anthropic's official skills, and harness design principles.

## License

MIT — see [LICENSE](LICENSE).
