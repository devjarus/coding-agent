# Protocols

A Protocol is a named multi-actor workflow. Each is `{Actor → Artifact} + Checks`. Agents reference Protocols by name; they do not redescribe them.

| Protocol | Entry | Exit | Primary writer |
|----------|-------|------|----------------|
| `intake` | user message | intent.md approved | orchestrator |
| `spec-writing` | intent approved | spec.md approved | architect |
| `plan-writing` | spec approved | plan.md approved | architect |
| `implementation` | plan approved | all tasks complete | implementor (orchestrator dispatches) |
| `review` | implementation complete | review.md written | evaluator |
| `fix-round` | review FAIL | review PASS or escalation | orchestrator (coordinates) |
| `close-out` | review PASS | commit gate opened | orchestrator |
| `redirect` | user message during active pipeline | classified + routed | orchestrator |
| `recovery` | dispatch threshold or pivot | checkpoint written | orchestrator |

See `${CLAUDE_PLUGIN_ROOT}/docs/redesign/lifecycle.md` for the full state machine and `${CLAUDE_PLUGIN_ROOT}/docs/redesign/workflow-spec.md` for the canonical happy path.
