---
artifact: deployments
feature: global
writer: orchestrator
mutability: append-only
state: active
---

# Deployments

<!--
Append-only deploy log. Newest at bottom. Never edit past entries.

One H2 section per deploy. Required fields: commit, preflight, execute, verify, status.
Status values: deployed | failed | rolled-back

Example:

## 2026-05-03T14:22:00Z — production
- commit: a1b2c3d
- preflight: env-vars-present ✓, pre-smoke ✓
- execute: railway up --service api (exit 0)
- verify: 3/3 URLs ✓
- status: deployed

## 2026-05-03T15:10:00Z — production
- commit: e4f5g6h
- preflight: env-vars-present ✗ (missing JWT_SECRET)
- execute: aborted
- verify: skipped
- status: failed
- thread: appended to open-threads.md
-->
