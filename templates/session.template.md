---
artifact: session
feature: global
writer: orchestrator
mutability: composite            # checkpoint=single-writer-mutable, action-log=append-only
state: active
---

## Checkpoint (mutable — overwritten on update)
active_feature: <slug or none>
phase: idle                      # idle|intake|spec|plan|implement|review|fix-round|close-out|touch-up-*|micro-*
last_completed: <slug @ ISO-timestamp or none>
dispatches_since_compact: 0       # incremented on every `dispatch` event; at 8, orchestrator collapses old entries into a `compact` line and resets to 0 (see orchestrator.md § Action log compaction)
pending_pushes: 0
resume_hint: null                # or "pick up at <state>"

## Action Log (append-only — never modify, only append)
<!--
Format: <ISO-timestamp> | <event-type> | <one-line description>
Event types: session-start, intake, dispatch, artifact-written, gate-passed,
             gate-declined, check-failed, close-out, micro, touch-up-*,
             pivot-requested, escalation, compact-suggested
-->
