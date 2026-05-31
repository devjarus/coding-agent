#!/usr/bin/env bash
# PreCompact hook — drop a durable breadcrumb just before the conversation is
# compacted, so the post-compaction session has an on-disk record of the boundary.
#
# The orchestrator is supposed to "log first, act second" so compaction never
# loses a step; this is the deterministic safety net for that contract. It pairs
# with session-start-context.sh, which re-surfaces durable state after compaction.
#
# NON-BLOCKING by design: never prevents compaction (no decision:block, exit 0).
# No-ops silently outside a coding-agent project. `trigger` is read defensively.

set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
TRIGGER=$(printf '%s' "$INPUT" | jq -r '.trigger // .compaction_trigger // "unknown"' 2>/dev/null || true)

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-${CWD:-$PWD}}"
STATE_DIR="$PROJECT_DIR/.coding-agent"

[ -d "$STATE_DIR" ] || exit 0

ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
echo "${ts} | compact-boundary | context compacted (trigger=${TRIGGER}); durable state on disk: session.md, work.md, open-threads.md" \
  >> "$STATE_DIR/agent-log.txt"
exit 0
