#!/bin/bash
# PostToolUse hook script — runs after Write/Edit/MultiEdit on agent or skill files
# Reads tool input from stdin, validates only if the edited file is an agent or skill

set -uo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

# Only validate if the edited file is an agent or skill
case "$FILE_PATH" in
  */agents/*.md|*/skills/*/SKILL.md)
    ;;
  *)
    exit 0
    ;;
esac

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REL_PATH="${FILE_PATH#$PLUGIN_ROOT/}"

# Quick frontmatter check on the edited file
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

FIRST_LINE=$(head -1 "$FILE_PATH")
if [ "$FIRST_LINE" != "---" ]; then
  echo "⚠ $REL_PATH: missing frontmatter (no opening ---)" >&2
  exit 0  # warn but don't block
fi

NAME=$(sed -n '/^---$/,/^---$/p' "$FILE_PATH" | grep "^name:" | head -1 | sed 's/name: *//')
if [ -z "$NAME" ]; then
  echo "⚠ $REL_PATH: missing 'name' in frontmatter" >&2
  exit 0
fi

# For agent files, check model field
case "$FILE_PATH" in
  */agents/*.md)
    MODEL=$(sed -n '/^---$/,/^---$/p' "$FILE_PATH" | grep "^model:" | head -1 | sed 's/model: *//')
    if [ -z "$MODEL" ]; then
      echo "⚠ $REL_PATH: missing 'model' in frontmatter" >&2
    elif [[ "$MODEL" != "opus" && "$MODEL" != "sonnet" && "$MODEL" != "haiku" && "$MODEL" != "inherit" ]]; then
      echo "⚠ $REL_PATH: invalid model '$MODEL'" >&2
    fi
    ;;
esac

# Check for stale docs/agents/ references
if grep -q "docs/agents/" "$FILE_PATH" 2>/dev/null; then
  echo "⚠ $REL_PATH: contains 'docs/agents/' reference — should be '.coding-agent/'" >&2
fi

exit 0
