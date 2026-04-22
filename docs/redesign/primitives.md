# Primitives

The system is built from four primitives. Everything else — Protocols, Sessions, the Pipeline, the shape of each agent prompt — composes from these.

> **Status:** design proposal, not implemented. See `workflow-spec.md` for the canonical flow and `lifecycle.md` for artifact states and close-out.

## 1. Actor

An Actor produces work. Each has an identity, a fixed contract (what it promises to produce), a tool set, and a scope (what it is permitted to touch). Two classes: **Human** and **Agent**.

### Agent types (named by software-engineering role)

| Actor | Role analog | Unique responsibility |
|-------|-------------|----------------------|
| **Orchestrator** | Tech lead / PM | Reads state, classifies requests, dispatches other agents. **Only** actor with dispatch authority. |
| **Architect** | Design / staff eng | Converts intent into `spec.md` and `plan.md`. Makes irreversible choices (stack, scope, test infra, architecture). |
| **Implementor** | Engineer | Converts plan into code + tests. Shape varies per project via **Skills**. |
| **Evaluator** | Code reviewer / QA | Independent review of just-written code. Invokes committed test suites; does not write ad-hoc scripts. |
| **Debugger** | SRE / incident responder | Root cause analysis for production bugs or fix-round regressions. Writes diagnoses, not code. |

### User

The User is the Product Owner. Owns **Intent**. Approves named gates. Agents interact with the User only through structured approvals (not freeform chat), because approvals must be verifiable after the fact.

### Invariants

- **Only the Orchestrator dispatches.** Agents return Artifacts; they never call other agents.
- **Every Actor transition is mediated by an Artifact.** The Orchestrator does not convey information by prose in a dispatch prompt — the receiving agent reads it from disk.
- **User approval is an Artifact signature**, not a chat message. (See Artifact section.)

---

## 2. Artifact

A durable output on disk. Typed, owned by exactly one Actor, with declared readers. Has a **state** and a **category**.

### Categories

| Category | Purpose | Typical files |
|----------|---------|---------------|
| **Intent** | What we're trying to do, approved by User | `intent.md` |
| **Plan** | How we'll do it, approved by User | `spec.md`, `plan.md` |
| **Work** | Current state: task ledger, decisions, deviations, revisions, nits — one place | `work.md` |
| **Findings** | What the Critic saw | `review.md`, `diagnosis.md` |
| **Memory** | Durable across features or sessions | `profile.md`, `learnings.md`, `AGENTS.md`, `ARCHITECTURE.md`, `session.md` |

Five categories, five-to-seven files per active feature at most.

### States

```
draft ──(author signs)──> approved ──(work begins)──> active ──(close-out)──> archived
```

| State | Who may read | Who may write | Typical transition |
|-------|--------------|---------------|--------------------|
| `draft` | Author only | Author | Agent is building it |
| `approved` | Everyone | Nobody (immutable) | User signed footer |
| `active` | Everyone | Writer declared in frontmatter | Implementation in flight |
| `archived` | Everyone | Nobody (immutable) | Close-out complete |

Memory category is always `active` (never transitions). Spec and Plan go `draft → approved`. Work goes `active → archived`. Findings go `draft → active` (reviewed, not approved by user in the same sense).

#### Avoid vocabulary collision: three "state" concepts

The word "state" appears in three distinct vocabularies in this plugin. Don't confuse them:

| Vocabulary | Field name | Values | Where it lives |
|------------|-----------|--------|---------------|
| **Artifact lifecycle state** | `state:` (frontmatter) | `draft / approved / active / archived` | Every artifact's frontmatter |
| **Task state** | `task-state` (column in table) | `ready / in-progress / complete / blocked / failed / needs-revision` | `work.md § Tasks` table |
| **Review status** | `Status:` (heading body) | `PASS / FAIL` | `review.md ## Status` section |

The vocabularies do NOT overlap. A task with `task-state: complete` lives in a `work.md` whose frontmatter says `state: active`. A review with `## Status: PASS` lives in a `review.md` whose frontmatter says `state: active` (until close-out flips to `archived`). When in doubt, the artifact frontmatter `state:` always uses the lifecycle vocabulary — the other two never appear there.

### Mutability class

Every Artifact declares its mutability class in frontmatter. Three classes, no ambiguity:

| Class | Write rules | Examples |
|-------|-------------|----------|
| `immutable` | Never written after state transition. Amendments live in a separate mutable artifact that references it. | `spec.md`, `plan.md`, `review.md`, `diagnosis.md`, archived artifacts |
| `append-only` | Writes must add content; never modify or delete existing content. One writer. | `learnings.md`, the action-log portion of `session.md` |
| `single-writer-mutable` | One owner writes any part. Others return structured updates; owner parses and applies. | `work.md`, the checkpoint portion of `session.md`, `cache.json`, `CURRENT`, `profile.md` |
| `composite` | A file with multiple sections, each section declares its own class. Rare; used only when splitting would cost more than it saves. | `session.md` (checkpoint = single-writer-mutable + action-log = append-only) |

### Supersession rule

When an `immutable` artifact needs an effective change, we **do not rewrite it**. A `single-writer-mutable` artifact holds the amendment with a reference back to the immutable source. Readers must consult both.

Concrete example: an approved `plan.md` cannot be modified. If wave 2 needs a design change, the amendment goes into `work.md`:

```markdown
## Plan Revisions
### R-1 — 2026-04-20 — material, approved by user
Supersedes: plan.md §Wave 2 T-5
Change: replace Redis counters with in-memory LRU
Why: target env has no managed Redis
Downstream: T-7 evaluation criterion "survives restart" → "degrades gracefully on restart"
```

`plan.md` is untouched. Its approval signature remains meaningful. The Evaluator reads `plan.md` for the original contract and `work.md` for approved amendments. Same for spec revisions, findings retractions, etc.

### Memory scopes

| Scope | Path | Contents | Read |
|-------|------|----------|------|
| **Project** | `.coding-agent/` in repo | `learnings.md`, `decisions.md`, `session.md`, `features/<slug>/` archives | Every session start in this repo |
| **Global** | `~/.coding-agent/` | `profile.md` (user preferences) | Every session across all repos |

Profile is the only Global Memory item by default. Cross-project "breadcrumbs" (topic-tagged gotchas) may be added later but are not required; the Project learnings are usually enough.

### Frontmatter format

Every Artifact carries a frontmatter block. Checks read this block; they never parse prose.

```yaml
---
artifact: plan                      # category (intent | plan | work | findings | memory)
feature: notifications-v1           # feature slug (or "global" for profile)
writer: architect                   # declared owner — only this Actor may write
mutability: immutable               # immutable | append-only | single-writer-mutable | composite
state: approved                     # draft | approved | active | archived
approved_by: user                   # present only in approved state
approved_at: 2026-04-20T14:32:00Z   # ISO timestamp
supersedes: null                    # set when this artifact amends another (e.g. work.md R-1 → plan.md §Wave 2)
---
```

### Invariants

- **Every Artifact has exactly one `writer`.** Declared in frontmatter. No multi-writer state.
- **Every Artifact has at least one Check.** Existence + required frontmatter fields minimum.
- **Memory is read at session start, written at feature close-out** — never mid-session, except the `session.md` action log which appends continuously.
- **`approved` artifacts are `immutable` forever.** Amendments go into a `single-writer-mutable` artifact via the supersession rule.
- **`work.md` is the amendment surface.** Plan revisions, deviations, nits, decisions — all live here, not in the spec/plan themselves.

---

## 3. Skill

A Skill is scoped knowledge an Actor loads to adapt. The Implementor producing a Next.js frontend is a different engineer than the Implementor producing a Swift iOS app — same Actor, different Skills. Skills make Actors pluripotent.

### Skill properties

| Property | Meaning | Example |
|----------|---------|---------|
| `name` | Unique id | `react-specialist` |
| `scope` | Which Actor(s) may use it | `implementor`, `architect`, `any` |
| `trigger` | When it loads | `always` (frontmatter preload), `on-match: [tags]` (routed), `on-invoke` (explicit `Skill` tool call) |
| `category` | What kind of knowledge | `domain-specialist`, `practice`, `protocol-helper`, `general` |
| `content` | The SKILL.md body | Prose + rules + optional scripts |

### Skill categories

| Category | Purpose | Examples |
|----------|---------|----------|
| **Domain specialist** | Stack knowledge for a specific technology | `react-specialist`, `nodejs-specialist`, `postgres-specialist`, `ios-swiftui-specialist` |
| **Practice** | Cross-cutting engineering discipline | `tdd`, `test-doubles-strategy`, `observability`, `security-checklist` |
| **Protocol helper** | Executes part of a multi-Actor Protocol | (v2 collapsed these into `protocols/*.md` + `templates/*.md`; no skill instances currently — protocols ARE the helpers) |
| **General** | Widely applicable, not tied to a stack or practice | `debugging`, `git-workflow` |

### Skill manifest

Each Implementor dispatch carries an explicit Skill manifest derived from the task's domain tags. The Architect decides the manifest in `plan.md`; the Orchestrator passes it through verbatim.

Example task block in `plan.md`:

```markdown
### T-3 — signing-helper (backend)
domain_tags: [backend, nodejs, security]
skills: [nodejs-specialist, api-design, security-checklist, test-doubles-strategy, tdd, observability]
```

### Invariants

- **Architect decides the manifest.** Not the Orchestrator, not the Implementor.
- **Manifest is visible to the User during plan approval.** Skill choice is a design decision; the User can override.
- **A Skill with `trigger: always` is preloaded.** Declared in Actor frontmatter.
- **A Skill with `trigger: on-match` requires the dispatch prompt to name it.** No magic routing.

---

## 4. Check

A Check is a deterministic predicate over state:

```
check(state) → { ok: bool, reason: string }
```

No LLM. Runs in <1s. Written in bash or a small scripting language — whatever the repo can execute without adding heavy dependencies.

### Check kinds (by timing)

| Kind | Fires when | Example |
|------|-----------|---------|
| **Input** | Before an Actor runs | `plan-approved` before Implementor dispatch |
| **Output** | After an Actor returns | `review-has-required-sections` after Evaluator |
| **Invariant** | Continuously (or on each dispatch) | `current-points-to-existing-feature` |
| **Evidence** | Guards a state transition | `ui-screenshots-exist` before `Status: PASS` on a UI feature |

### Checks that replace prose rules

Every prose rule that has failed twice becomes a Check. Starting list:

| Check | Replaces today's prose |
|-------|------------------------|
| `intent-approved` | "Orchestrator must get user approval before spec" |
| `stack-justified` | "Architect must show stack tradeoffs" |
| `spec-approved` | "Gate 1: user approves spec" |
| `plan-approved` | "Gate 2: user approves plan" |
| `test-infra-declared` | "Plan must include test infrastructure research" |
| `test-tiers-covered` | "Each wave must require unit + integration + e2e" |
| `tests-actually-committed` | "Evaluator invokes real tests, not curl scripts" |
| `ui-screenshots-exist` | "UI projects require Playwright evidence" |
| `no-raw-print` | "Use structured logging; no console.log in prod code" |
| `logger-imported` | "New files must import project logger" |
| `close-out-complete` | "Feature completion distills to learnings + clears CURRENT" |
| `revisions-resolved` | "No pending plan revisions before next wave" |
| `mcp-preflight` | "UI projects require Playwright/iOS MCP enabled" |

### Invariants

- **Checks do not write Artifacts.** They only report.
- **A failed Check blocks a transition.** The Orchestrator refuses to dispatch or mark PASS.
- **Checks are composable.** A dispatch-time Check may invoke multiple atomic Checks; the Orchestrator reports all failures, not just the first.

---

## Composites (not primitives — compositions of the above)

### Protocol

A named, ordered sequence of `{Actor → Artifact} + Checks`. Lives in `protocols/*.md`. Agents reference a Protocol by name; they do not redescribe it in their own prompts.

Named Protocols in this design:
- `intake` — user request → Intent artifact → approval
- `spec-writing` — Architect discovery → `spec.md` → approval
- `plan-writing` — test-infra research → `plan.md` → approval
- `implementation` — serial or parallel Implementor dispatch
- `review` — Evaluator invocation (full / lightweight / smoke)
- `fix-round` — failure re-dispatch with `work.md` handoff
- `close-out` — freeze + distill + clear CURRENT
- `redirect` — mid-pipeline user direction change
- `recovery` — compact, clear, rewind with session checkpoint

### Session

A live instance of a Protocol (usually `pipeline`), running against a live repo. A Session reads Memory on start, writes Memory at feature close-out, and is checkpointed to `session.md` periodically.

### Pipeline

The default Protocol for shipping a feature. The composition:

```
intake → spec-writing → plan-writing → implementation → review → (fix-round)* → close-out
```

`(fix-round)*` means zero or more fix rounds depending on Evaluator findings.

---

## What's not a primitive (and why)

| Candidate | Status | Why demoted |
|-----------|--------|-------------|
| **Intent** | Artifact category | Behaves like an Artifact; no unique primitive properties |
| **Protocol** | Composite | Ordered use of primitives; adds no new capability |
| **Feedback / learning** | Property of Memory | Close-out protocol handles it; no separate primitive needed |
| **Preset** | Content in Profile | A preset is a named set of Profile defaults; not structural |
| **Breadcrumb** | Dropped | Project Memory's `learnings.md` is already the mechanism |
| **Session** | Composite | A live Protocol instance; not a distinct thing |

---

## Primitive count: 4

Actor, Artifact, Skill, Check. Everything else composes.
