---
artifact: learnings
feature: global
writer: orchestrator
mutability: append-only
state: active
---

# Project Learnings

Cumulative record of decisions made, gotchas discovered, and patterns introduced across every feature. **Append-only** — newest dated section at the top, older below. Never truncated. Never edited after writing.

<!--
Each feature's close-out protocol step 2 prepends one section below this
header. Template for each section:

## YYYY-MM-DD — <feature-slug>

### Decisions
- <stack choice> — chose X over Y because Z
- <tradeoff made> — <what was rejected + why>

### Gotchas
- <library bug / API quirk / platform difference / mental-model correction>
- Each entry should be specific enough that a future agent reading this,
  even without context, can avoid the same mistake.

### Patterns
- <reusable pattern introduced> — where it lives, what problem it solves
- Include file:line references so future agents can find the canonical impl.

Example:

## 2026-04-20 — notifications-v1

### Decisions
- Realtime: WebSocket (Fastify) — rejected SSE (unidirectional only)
- Push: FCM — rejected APNS-only (Android priority); recorded fixtures via msw
- Persist: Postgres (existing users table + new tables) — rejected Redis-only
  (users schema is the source of truth; don't split sources)

### Gotchas
- FCM device tokens silently expire on Android 14 — handle "token refreshed"
  event to rebuild; see src/push/fcm-gateway.ts:47
- Testcontainers Postgres startup adds ~3s to CI — acceptable; kept in CI
- WebSocket reconnect storms on deploy — jittered backoff required; see
  src/realtime/reconnect.ts:12

### Patterns
- PushGateway adapter pattern — src/push/gateway.ts defines interface;
  StripePaymentGateway / MockPushGateway implement it. Only one file
  imports fcm-admin. Unit tests fake the interface.
-->

<!-- dated entries appended here, newest first -->
