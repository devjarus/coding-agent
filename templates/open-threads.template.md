---
artifact: open-threads
feature: global
writer: orchestrator
mutability: append-only
state: active
---

# Open Threads

<!--
Append-only log of unresolved user-facing items that must survive /compact and /clear.
Format: - [YYYY-MM-DD] <one-line description, mention who is blocked / what is owed>

To resolve: prefix the line with `~~` and append `~~ (resolved YYYY-MM-DD: <reason>)`.
Never delete a line. The audit trail is the point.

Example:
- [2026-05-03] Linear UUID setup pending — user said "later this week"
- [2026-05-03] CORS smoke check missing for /api/feedback DELETE
- ~~[2026-05-01] DB migration rollback plan needed~~ (resolved 2026-05-02: documented in plan.md § Rollback)
-->
