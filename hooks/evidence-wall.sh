#!/usr/bin/env bash
# The single mechanical wall (design doc §5): evidence.jsonl is append-only and
# may be written ONLY by record.sh. This PreToolUse hook denies any Edit/Write to
# it, and any Bash redirection into it that doesn't go through record.sh.
# Other workflow rules are prompt- or gate-enforced.
set -uo pipefail
input="$(cat)"

field() { printf '%s' "$input" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d$1)" 2>/dev/null || true; }
deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' \
    "$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
  exit 0
}

tool="$(field '.get("tool_name","")')"
case "$tool" in
  Edit|Write|MultiEdit)
    path="$(field '.get("tool_input",{}).get("file_path","")')"
    [[ "$path" == *evidence.jsonl ]] && deny "evidence.jsonl is append-only and written only by record.sh. Do not edit it. Run: \${CLAUDE_PLUGIN_ROOT}/lib/record.sh \"<command>\" <kind>"
    ;;
  Bash)
    c="$(field '.get("tool_input",{}).get("command","")')"
    if printf '%s' "$c" | grep -q 'evidence.jsonl' && ! printf '%s' "$c" | grep -q 'record.sh'; then
      printf '%s' "$c" | grep -Eq '(>>?|tee|sed -i|cp |mv |truncate)' \
        && deny "Write to evidence.jsonl only via record.sh — never by hand."
    fi
    ;;
esac
printf '{}\n'
