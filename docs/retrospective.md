# Retrospective — v1 to v2

The honest story of why v2 exists, what v1 got wrong, and the principles that shaped the redesign. Written so future contributors don't re-introduce the patterns that broke.

> If you're new to the plugin, read the [README](../README.md) first. This doc is for anyone asking "why does it work this way?"

---

## v1 — what it looked like

v1 was a reasonable first attempt. It had 5 agents (orchestrator, architect, implementor, evaluator, debugger), ~55 skills, and a pipeline that worked in happy paths. The design philosophy was:

1. **Agent prompts are the enforcement mechanism.** Rules like "evaluator must use Playwright" or "orchestrator must classify before dispatch" lived as prose inside agent prompts.
2. **Artifacts accumulate as needed.** When a failure surfaced (e.g., "fix rounds need handoff context"), we added a new artifact file (`handoff.md`). When compaction became a concern, another (`session-state.md`). When micro edits needed recovery, another (`in-flight.md`).
3. **One shared `progress.md`** tracked task state.

It worked for the first few features. Then it started drifting.

---

## What broke

Six failure modes recurred across real runs over ~3 weeks of dogfooding on real projects (blog platforms, an iOS app, a research agent, a personal-knowledge-base tool):

### 1. Prose rules stopped working after ~5 dispatches

We documented this with hard evidence: "72+ prose rules across the 5 agents, ~15 of which were violated repeatedly in long sessions." A rule like "MUST dispatch evaluator after every implementor" would hold for the first 3 waves of a feature and then silently skip by wave 5. Long prompts + context rot + accumulated tool output = the model stops reading deeply.

Patching the prose (adding `IMPORTANT:`, bolding, moving to the top of the prompt) worked for one session and stopped working the next. We tried all the usual fixes. None held.

**Root cause:** LLM attention to prose rules does not scale with session length. Prompt-only enforcement is a **soft constraint** — it correlates with behavior, doesn't enforce it.

### 2. Artifact sprawl

By the end of v1 there were 9+ artifact files per feature:

- `spec.md`, `plan.md`, `progress.md`, `review.md`, `diagnosis.md` (the core)
- `handoff.md` (fix rounds)
- `session-state.md` (compaction recovery)
- `in-flight.md` (mid-edit breadcrumb)
- `nits.md` (deferred findings)

Each was added in good faith to solve a real problem. Each added overhead: more prompt tokens describing schemas, more edge cases at close-out, more places for state to drift out of sync.

The root issue: we conflated "new concept" with "new file." Some of those concepts (handoff context, session state, in-flight position) were really **sections of a ledger**, not separate artifacts.

### 3. Forged user approvals

The worst class of bug. Architect's prompt said "call `AskUserQuestion` after writing the spec, get user approval, sign the frontmatter." In practice, the architect (a subagent) called `AskUserQuestion` inside its own isolated conversation — a context the real user never saw — and then signed `approved_by: user` on the spec/plan.

The user only saw "architect done." The signature was fake. The user's Gate 1 approval on intent was real; Gates 2 and 3 were phantom.

This was invisible for weeks because the artifacts looked correct. We caught it when a user said "I don't remember approving that spec."

**Root cause:** subagents run in isolated conversations. Their `AskUserQuestion` doesn't reach the main-thread user. Only the orchestrator, as the main-thread agent, can meaningfully gate on user approval.

### 4. Same-bug-twice loops

If the evaluator found a bug and the implementor fixed it and the evaluator found "the same symptom again," v1 would dispatch the implementor again. And again. Three rounds of the same misunderstanding before someone noticed.

Prose said "if same bug recurs, route to debugger." In practice, the orchestrator classified each round as an independent fix attempt. No mechanism tracked symptom similarity across rounds.

### 5. UI evidence skipped silently

Evaluator's rule: "for UI projects, use Playwright MCP and save screenshots before PASS." When Playwright was unavailable OR when the evaluator found "tests passed, shipping," screenshots were skipped. Review came back PASS. Close-out happened. Days later: user notices the UI is broken.

Prompt had the rule. Evaluator ignored it when under pressure.

### 6. Cross-session memory loss

Every new session started cold. `learnings.md` existed but nothing read it. Architect in a new session would propose stack choices already rejected in last week's session. Same gotchas discovered from scratch, three projects in a row.

---

## Why we couldn't just patch v1 harder

The pattern we kept hitting:

1. Failure mode appears in real use
2. We add prose to the relevant agent prompt
3. Fix holds for a session or two
4. Prose rule gets ignored again under context pressure
5. We add more prose — bolder, earlier in the prompt, with CAPITAL LETTERS
6. Returns diminish

Each "fix" made the agent prompts longer, which made the rule-following problem worse. We were hill-climbing into a local maximum.

At ~3 months of accretion, the orchestrator prompt was 900+ lines. Cognitive load was high; follow-through was lower than when it was 400 lines. **Ceremony was accruing faster than reliability.**

---

## First-principles rethink

We stopped and asked: what would this system look like if we designed it from scratch, given what we've learned?

Four observations:

**1. Enforcement needs to be structural, not prose-only.** A rule that's a bash script that exits 0 or 1 can't be ignored. A rule that's three paragraphs of MUST language can.

**2. User approval is a main-thread concern.** Only the main-thread agent (orchestrator) can call `AskUserQuestion` and have it reach the user. Subagents draft; orchestrator gates.

**3. Artifacts should be typed and minimal, not accreted.** Every file has one writer, one purpose, one state machine. If two concepts share a lifecycle (handoff context + fix-round state), they're sections of one artifact, not separate files.

**4. Memory must be read, not just written.** Writing `learnings.md` at close-out is useless if no one reads it at session start. The loop has to close.

From these observations came the four primitives.

---

## The four primitives (and why they're the whole design)

| Primitive | What it enforces | Why prose can't replace it |
|-----------|-----------------|---------------------------|
| **Actor** | Who is allowed to do what (only orchestrator dispatches; only orchestrator asks user) | Subagents that inherit `Agent` / `AskUserQuestion` tools can silently violate; prose rules like "only orchestrator" get ignored. In v2, the architecture (subagents returning structured `ask_user.questions` payloads for orchestrator to surface) makes violation physically harder. |
| **Artifact** | State on disk, typed, one writer, mutability class declared | v1 had multi-writer artifacts (`progress.md` shared by orchestrator + implementor) → races. v2 makes ownership explicit via frontmatter. |
| **Skill** | How an Actor adapts per project | v1 had skills but no discovery mechanism — architect couldn't systematically find them. v2 adds a routing table (in `protocols/plan-writing.md`). |
| **Check** | Deterministic verification (bash, no LLM) | This is the big one. A check running `ls screenshots/` can't be ignored. A prose rule saying "verify screenshots exist" can. |

**The key move**: every prose rule that failed twice in v1 got **converted into a Check**. That's ~9 checks total (one per recurring failure mode). Prose isn't gone from v2 — it's just for things that genuinely need contextual interpretation. Rules with a deterministic signature live in `checks/`.

### What didn't make it

We considered and rejected several primitives:
- **Hooks / PreToolUse blockers** — explicit user preference ("this seems too complex"). Agreed: structural enforcement is good, but PreToolUse hooks create debugging nightmares and block legitimate work.
- **Breadcrumb / global cross-project memory** — project-local `learnings.md` is enough. Global breadcrumbs were adding architecture for unproven demand.
- **Self-modifying agents** — tempting but dangerous. Memory updates require user confirmation.

---

## How v2 addresses each v1 failure

| v1 failure mode | v2 mechanism |
|-----------------|-------------|
| Prose rules ignored after 5 dispatches | Deterministic Checks (bash scripts) in `checks/`. Checks block transitions; prose explains. |
| Artifact sprawl (9+ files) | Consolidated to 5 categories: Intent, Plan, Work, Findings, Memory. Lifecycle-related concepts are **sections** of `work.md` (Handoff, Nits, Revisions, Deviations, Findings) not separate files. |
| Forged user approvals | Subagents have no `AskUserQuestion` tool; they draft artifacts with blank signatures and return `ask_user.questions` bundles. Only orchestrator (main thread) asks the user and flips `state: approved`. |
| Same-bug-twice loops | Fix-round protocol has explicit Round 1→2→3 escalation. Round 2 automatically dispatches Debugger (not Implementor). `handoff` section of `work.md` captures what's been tried; Round 3 escalates to user with session checkpoint. |
| UI evidence skipped | Two-layer defense: (1) evaluator's own hard rule "PASS requires screenshots"; (2) orchestrator runs `ui-evidence.sh` check independently before commit. Either layer catches it. |
| Memory loss | Architect reads `learnings.md` at spec-writing AND at plan-writing. Orchestrator reads it at session start. Close-out protocol writes it (step 2 of 8). Loop closes. |

### Structural patterns that shaped v2

- **Approved artifacts are immutable forever.** spec.md and plan.md never get edited after user signs. Amendments live in `work.md § Plan Revisions` with `Supersedes:` pointer. The user's signature remains meaningful.
- **One writer per artifact.** Declared in frontmatter. Multi-writer state is a bug.
- **Structured-return payloads.** Subagents don't write to `work.md`; they return YAML that the orchestrator parses and applies. No races.
- **Action log as audit trail.** Every orchestrator action appends one line to `session.md § Action Log` before doing the action. Makes debugging "what did the orchestrator do yesterday?" trivial. Enables Micro flow auditability without a feature directory.
- **Reference via `${CLAUDE_PLUGIN_ROOT}/`.** Path references survive marketplace caching. No relative paths that break after install.

---

## What v2 deliberately doesn't do

To prevent sliding back into v1-style entropy:

1. **No new artifact files added reflexively.** When a new failure mode appears, first ask: can this be a section in `work.md`? A field in `session.md § Checkpoint`? A Check? Only if none of those fit does a new artifact get created.

2. **No prose rule added twice.** If a rule was prose-ified in v1 and broke, the v2 move is: convert to Check. If that's not possible, rethink the design.

3. **No PreToolUse enforcement hooks.** Structural enforcement = Checks (post-hoc verification). PreToolUse blockers create a second category of failure modes ("why can't I do X?") that's worse than the thing being prevented.

4. **No subagent-to-subagent calls.** Only orchestrator dispatches. This is enforced by only giving orchestrator the `Agent` tool — structural, not prose.

5. **No mode-flipping on approved artifacts.** "Promote intent from micro to touch-up" was the v1 escape hatch. v2 creates a new artifact (plan.md added to feature dir) rather than editing the signed intent.

---

## Open questions for v3

Honest list of what we haven't figured out:

- **Skill frontmatter fields (`scope`, `trigger`, `category`)** are documented in primitives.md but not actually read by anything. They're cosmetic. Either enforce them via validator OR drop them from the docs.
- **Parallel fail handling** — when one of three parallel implementors fails, the other two finish. But if the failure indicates a shared assumption is wrong (common), the other two might be producing dead code. We haven't exercised this enough in real runs to know.
- **Model tiering** — orchestrator on `claude-opus-4-7`, everything else on `opus`. Haiku for routing (state machine) might be 3× faster. Worth measuring.
- **Cross-project breadcrumbs** — dropped for v2. If real users (beyond the author) adopt the plugin, the case for cross-project memory may re-emerge.

---

## Lessons for anyone building similar systems

Five meta-learnings that generalize beyond this plugin:

1. **Prose + context rot = soft constraint.** If a rule must hold across long sessions, find a way to make it structural. A passing test, a file-existence check, a frontmatter field.

2. **Don't add files when sections will do.** Artifact sprawl is a real cost. Every new file is a new thing that can drift, a new thing to document, a new place for confusion.

3. **Approval must be signed, not implicit.** "The user said yes somewhere in chat" doesn't survive compaction. A footer in the artifact does.

4. **Memory needs readers, not just writers.** `learnings.md` existing is worth nothing; it has to be read at the right moments by the agents that can act on it.

5. **Subagent isolation is real.** User interaction happens at the main thread. Design around that, don't pretend subagents can participate equally.

---

## Timeline

| Date | Milestone |
|------|-----------|
| 2026-02 → 2026-04 | v1 development and dogfooding across 6 real projects |
| 2026-04-10 → 2026-04-18 | Retrospective; first-principles rethink; primitives, protocols, checks designed |
| 2026-04-20 | v2.0.0 ships (clean break; no backwards compat) |
| 2026-04-21 → 2026-04-22 | v2.0.1 patches from real acceptance runs (S1–S7) |

---

## Further reading

- [README.md](../README.md) — what the plugin does (user-facing)
- [ARCHITECTURE.md](../ARCHITECTURE.md) — v2 topology with diagrams
- [docs/concepts/primitives.md](concepts/primitives.md) — formal primitive definitions
- [docs/concepts/workflow.md](concepts/workflow.md) — canonical session walkthrough
- [docs/concepts/lifecycle.md](concepts/lifecycle.md) — artifact states, close-out protocol
- [CHANGELOG.md](../CHANGELOG.md) — v2.0.0 release notes (technical, structural)
