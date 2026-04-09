---
name: pipeline-verification
description: Deterministic stage gates for the development pipeline — validates artifacts (spec, plan, review), verifies builds, and runs tests. Called by the orchestrator between stages to ensure nothing is skipped.
---

# Pipeline Verification

Deterministic checks the orchestrator runs before advancing the pipeline.

## How to Run

```bash
${CLAUDE_SKILL_DIR}/scripts/verify-stage.sh <stage>
```

Stages: `spec`, `plan`, `build`, `tests`, `review`

Exit code 0 = PASS, 1 = FAIL (details on stderr).

## When to Run

| After | Command |
|-------|---------|
| Architect returns spec | `${CLAUDE_SKILL_DIR}/scripts/verify-stage.sh spec` |
| Architect returns plan | `${CLAUDE_SKILL_DIR}/scripts/verify-stage.sh plan` |
| Implementor returns | `${CLAUDE_SKILL_DIR}/scripts/verify-stage.sh build` then `${CLAUDE_SKILL_DIR}/scripts/verify-stage.sh tests` |
| Evaluator returns | `${CLAUDE_SKILL_DIR}/scripts/verify-stage.sh review` |

## What Each Stage Checks

### `spec`
- spec.md exists, has Overview, Requirements (FR-*), Non-Goals
- Warns if missing Technical Risks

### `plan`
- plan.md exists, has Tasks (T-*), Waves, Evaluation Criteria

### `build` (auto-detects stack)
- Node/TS: `npm install` + `npm run build` (monorepo aware)
- Swift: `swift build` or `xcodebuild`
- Go: `go build ./...`
- Python: `py_compile`

### `tests` (auto-detects runner)
- Node/TS: `npm test` (monorepo: server + client)
- Swift: `swift test`
- Go: `go test ./...`
- Python: `pytest`

### `review`
- review.md exists, has Status (PASS/FAIL), Findings
- Warns if missing Build Result or Runtime Verification

## Rules

- **FAIL blocks the pipeline.** Re-dispatch subagent with error output.
- **WARN doesn't block** but note in progress.md.
- **Max 2 retries** per stage, then escalate to user.
