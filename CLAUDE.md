# coding-agent — Claude Code Plugin (v2.0)

A multi-agent software development system, redesigned from first principles around four primitives.

## The Four Primitives

| Primitive | Definition | Examples |
|-----------|------------|----------|
| **Actor** | Produces work | User, Orchestrator, Architect, Implementor, Evaluator, Debugger |
| **Artifact** | Durable on-disk state, typed, one writer | `intent.md`, `spec.md`, `plan.md`, `work.md`, `review.md`, `diagnosis.md`, `session.md`, `learnings.md` |
| **Skill** | Scoped knowledge an Actor loads to adapt | domain-specialist, practice, protocol-helper, general |
| **Check** | Deterministic verification, no LLM | `intent-approved.sh`, `ui-evidence.sh`, `close-out-complete.sh`, etc. |

See `docs/redesign/primitives.md` for formal definitions, invariants, and what's deliberately not a primitive.

## The Five Agents

| Agent | Model | Role | Owns |
|-------|-------|------|------|
| **orchestrator** | claude-opus-4-7 | Tech lead — state machine, dispatcher, check runner | `work.md`, `session.md`, `cache.json`, `CURRENT`, `learnings.md` |
| **architect** | opus | Staff eng — spec & plan author, MCP researcher | `spec.md`, `plan.md` (immutable after approval) |
| **implementor** | sonnet | Engineer — code + tests, returns structured updates | source files, test files |
| **evaluator** | opus | QA — runs committed tests, drives Playwright/sim, writes review.md | `review.md`, `screenshots/` |
| **debugger** | opus | SRE — root cause analysis, full or inspection mode | `diagnosis.md` |

Subagents return a structured YAML payload; orchestrator parses and applies to `work.md`. No multi-writer state.

## The Nine Protocols

Named workflows that span agents. Each lives in `protocols/<name>.md` as the authoritative reference. Agent prompts cross-reference; they do not redescribe.

| Protocol | Owner | When |
|----------|-------|------|
| `intake` | Orchestrator | every user request |
| `spec-writing` | Architect | medium/large features |
| `plan-writing` | Architect | medium/large features |
| `implementation` | Orchestrator | once plan approved |
| `review` | Evaluator | implementation complete |
| `fix-round` | Orchestrator | review FAIL (3 rounds before escalation) |
| `close-out` | Orchestrator | review PASS, before commit (8 steps) |
| `redirect` | Orchestrator | user message during active pipeline |
| `recovery` | Orchestrator | dispatch threshold or pivot |

## Artifacts

| Category | Mutability | Files |
|----------|-----------|-------|
| **Intent** | immutable (after approval) | `intent.md` |
| **Plan** | immutable (after approval) | `spec.md`, `plan.md` |
| **Work** | single-writer-mutable (orchestrator) | `work.md` (merges deviations, revisions, decisions, nits, handoff, findings) |
| **Findings** | immutable (once written) | `review.md`, `diagnosis.md` |
| **Memory** | append-only or single-writer-mutable | `learnings.md`, `session.md` (composite), `profile.md` (global), `AGENTS.md`, `ARCHITECTURE.md` |

States: `draft → approved → active → archived`.
**Approved artifacts are never edited.** Amendments live in `work.md § Plan Revisions` with `Supersedes:` pointer.

## Path conventions

- **Plugin internals** (protocols, checks, templates, docs): `${CLAUDE_PLUGIN_ROOT}/...`
- **User project artifacts**: `.coding-agent/...` (relative to project root)
- **Global memory**: `~/.coding-agent/profile.md`

## Skills (~58)

Categories: domain-specialist, practice, protocol-helper, general. Each declares `scope`, `trigger`, `category` in frontmatter (schema being progressively backfilled).

Implementor's skill manifest comes from `plan.md` (per task, declared by the Architect). Orchestrator passes it verbatim — no magic routing.

## MCP Servers (`.mcp.json`)

| Server | Purpose |
|--------|---------|
| context7 | Library docs (architect, implementor) |
| exa | Web search (architect) |
| deepwiki | Repo deep-dives (architect) |
| playwright | Browser UI testing (evaluator) |
| chrome-devtools | Console/network inspection (evaluator) |
| xcodebuild | iOS build/test/debug (evaluator) |
| ios-simulator | iOS simulator control (evaluator) |

## Development

```bash
./scripts/validate.sh
```

## Migration from v1

v2 is a clean break — no backwards compatibility. Old `.coding-agent/features/<slug>/` directories from v1 still exist as historical archives but are not consumed by v2 protocols. Profile (`~/.coding-agent/profile.md`) and global learnings remain compatible.
