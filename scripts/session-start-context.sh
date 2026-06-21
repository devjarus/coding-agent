#!/usr/bin/env bash
# SessionStart hook — inject coding-agent resume state into the model's context.
#
# Fires on session startup / resume / post-compaction. Makes the orchestrator's
# "read on session start" deterministic: the durable state is placed in context
# directly instead of relying on the model to remember to read it.
#
# Observational + additive only — never blocks. No-ops SILENTLY in any project
# that isn't a coding-agent project (these hooks fire in every session).
#
# Reads the hook JSON on stdin; emits {hookSpecificOutput.additionalContext}.

set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // "startup"' 2>/dev/null || true)

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-${CWD:-$PWD}}"
STATE_DIR="$PROJECT_DIR/.coding-agent"

# Not a coding-agent project (or a fresh one) -> stay silent.
[ -d "$STATE_DIR" ] || exit 0

nl=$'\n'
ctx=""

# Active feature slug
if [ -f "$STATE_DIR/CURRENT" ]; then
  current=$(head -1 "$STATE_DIR/CURRENT" 2>/dev/null | tr -d '[:space:]')
  [ -n "$current" ] && ctx="${ctx}Active feature (.coding-agent/CURRENT): ${current}${nl}"
fi

# Unresolved open threads — lines that are not struck through (~~ = resolved)
if [ -f "$STATE_DIR/open-threads.md" ]; then
  threads=$(grep -E '^- \[' "$STATE_DIR/open-threads.md" 2>/dev/null | grep -v '~~' || true)
  if [ -n "$threads" ]; then
    ctx="${ctx}${nl}Unresolved open threads (survive /compact — address or carry forward):${nl}${threads}${nl}"
  fi
fi

# Resume pointer — last few action-log entries
if [ -f "$STATE_DIR/session.md" ]; then
  tail_lines=$(grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$STATE_DIR/session.md" 2>/dev/null | tail -3 || true)
  [ -n "$tail_lines" ] && ctx="${ctx}${nl}Last action-log entries:${nl}${tail_lines}${nl}"
fi

# Legacy-convention artifacts (pre-work.md / flat root layout). Surface ONCE so
# the orchestrator can OFFER a one-time cleanup (artifact-migration skill).
# Suppressed after a .migrated marker is written.
if [ ! -f "$STATE_DIR/.migrated" ]; then
  legacy=$(
    { ls "$STATE_DIR"/plan.prev*.md "$STATE_DIR"/spec.prev*.md "$STATE_DIR"/review.prev*.md \
         "$STATE_DIR"/progress.prev*.md "$STATE_DIR"/progress.md 2>/dev/null; \
      find "$STATE_DIR/features" -maxdepth 2 \( -name 'progress.md' -o -name 'nits.md' -o -name 'mode' \) 2>/dev/null; } | grep -c .
  )
  if [ "${legacy:-0}" -gt 0 ]; then
    ctx="${ctx}${nl}Legacy-convention artifacts detected (${legacy}: root .prev*/progress.md and/or per-feature progress.md/nits.md/mode — predate the work.md + per-feature layout). OFFER the user a one-time cleanup via the artifact-migration skill (archive to .coding-agent/.archive/, never delete; writes .coding-agent/.migrated when done).${nl}"
  fi
fi

# Nothing durable to surface -> stay silent.
[ -n "$ctx" ] || exit 0

header="coding-agent resume state (session source: ${SOURCE}):${nl}${nl}"

jq -n --arg c "${header}${ctx}" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
exit 0
