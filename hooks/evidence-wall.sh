#!/usr/bin/env bash
# The evidence wall: evidence.jsonl is append-only and may be written ONLY by
# record.sh. This PreToolUse hook denies any Edit/Write to it, and any Bash
# command that names it alongside a write mechanism — shell redirection, tee,
# in-place editors, file-moving tools, or an interpreter writing a file.
#
# Scope, stated plainly: this stops accidental and casual writes (the common
# failure is an agent "fixing" a line by hand). It is not a security boundary.
# An agent that builds the path indirectly, or writes from a script file, can
# still reach the file; the defenses there are the prompt law, the tree-bound
# gates (a forged line must also match the current tree and frozen command), and
# the ledger audit trail. Codex runs no lifecycle hooks, so there the wall is
# prompt-only.
set -uo pipefail
input="$(cat)"

field() { printf '%s' "$input" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d$1)" 2>/dev/null || true; }
deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' \
    "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
  exit 0
}
msg="evidence.jsonl is append-only and written only by record.sh. Record with: \${CLAUDE_PLUGIN_ROOT}/lib/record.sh \"<command>\" <kind> [tier]. Read it with cat/grep/jq/tail."

tool="$(field '.get("tool_name","")')"
case "$tool" in
  Edit|Write|MultiEdit|NotebookEdit)
    path="$(field '.get("tool_input",{}).get("file_path","") or d.get("tool_input",{}).get("notebook_path","")')"
    [[ "$path" == *evidence.jsonl* ]] && deny "$msg"
    ;;
  Bash)
    c="$(field '.get("tool_input",{}).get("command","")')"
    printf '%s' "$c" | grep -q 'evidence\.jsonl' || { printf '{}\n'; exit 0; }
    # Discard harmless stream plumbing so read-only commands such as
    # `grep x evidence.jsonl 2>/dev/null` are not mistaken for writes.
    w="$(printf '%s' "$c" | sed -E 's/[0-9]*>&[0-9]+//g; s#[0-9]*>+[[:space:]]*/dev/null##g')"
    if printf '%s' "$w" | grep -Eq \
      '>|\btee\b|\bsed[[:space:]]+(-[A-Za-z]*i|--in-place)|\bperl[[:space:]]+-[A-Za-z]*i|\b(cp|mv|rm|truncate|dd|install|ln|rsync)\b|\.write\(|write_text|write_bytes|appendFile|writeFile|File\.(write|open)|open\([^)]*,[[:space:]]*["'"'"'][wax+]'; then
      deny "$msg"
    fi
    ;;
esac
printf '{}\n'
