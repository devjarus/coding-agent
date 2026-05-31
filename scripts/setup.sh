#!/usr/bin/env bash
# setup.sh — one-command setup for coding-agent in a project.
# Writes .claude/settings.local.json with recommended permissions and MCP enablement.
# Backs up any existing settings before overwriting.
#
# Usage:
#   bash /path/to/coding-agent/scripts/setup.sh                       # full setup, current directory
#   bash /path/to/coding-agent/scripts/setup.sh /some/repo            # full setup, specific project
#   bash /path/to/coding-agent/scripts/setup.sh --gitignore-only      # safe-minimum: only append gitignore entries
#   bash /path/to/coding-agent/scripts/setup.sh --gitignore-only /repo

set -uo pipefail

GITIGNORE_ONLY=0
TARGET=""
for arg in "$@"; do
  case "$arg" in
    --gitignore-only) GITIGNORE_ONLY=1 ;;
    -*) echo "error: unknown flag '$arg'" >&2; exit 1 ;;
    *) TARGET="$arg" ;;
  esac
done
TARGET="${TARGET:-$PWD}"

if [[ ! -d "$TARGET" ]]; then
  echo "error: '$TARGET' is not a directory" >&2
  exit 1
fi

cd "$TARGET"
if [[ $GITIGNORE_ONLY -eq 1 ]]; then
  echo "▸ Appending gitignore entries only (no settings written): $TARGET"
else
  echo "▸ Setting up coding-agent in: $TARGET"
fi

# ─── gitignore (always runs, even in --gitignore-only mode) ─────────
# Idempotent — only appends entries that aren't already present.
GITIGNORE_PATTERNS=(
  ".claude/settings.local.json"
  ".coding-agent/"
  ".env"
  ".env.local"
  ".env.*.local"
  ".env.development.local"
  ".env.production.local"
  "*.pem"
  "*.key"
  "id_rsa"
  "id_rsa.pub"
  "id_ed25519"
  "id_ed25519.pub"
)
[[ ! -f .gitignore ]] && touch .gitignore
for pat in "${GITIGNORE_PATTERNS[@]}"; do
  if ! grep -qxF "$pat" .gitignore; then
    echo "$pat" >> .gitignore
    echo "  ✓ added $pat to .gitignore"
  fi
done

# ─── Stop here if caller only wanted gitignore changes ──────────────
if [[ $GITIGNORE_ONLY -eq 1 ]]; then
  echo ""
  echo "✓ gitignore-only setup complete."
  exit 0
fi

# Detect iOS project
HAS_IOS=0
if ls *.xcodeproj *.xcworkspace 2>/dev/null | head -1 >/dev/null; then
  HAS_IOS=1
  echo "  ✓ detected iOS project (will enable xcodebuild + ios-simulator MCPs)"
fi

mkdir -p .claude

SETTINGS=.claude/settings.local.json
if [[ -f "$SETTINGS" ]]; then
  BACKUP="$SETTINGS.backup.$(date +%Y%m%dT%H%M%S)"
  cp "$SETTINGS" "$BACKUP"
  echo "  ✓ backed up existing settings → $BACKUP"
fi

# Build MCP server list
MCP_LIST='"context7", "exa", "playwright"'
if [[ $HAS_IOS -eq 1 ]]; then
  MCP_LIST="$MCP_LIST, \"xcodebuild\", \"ios-simulator\""
fi

cat > "$SETTINGS" <<EOF
{
  "agent": "coding-agent:orchestrator",
  "permissions": {
    "defaultMode": "acceptEdits",
    "allow": [
      "Bash",
      "Read",
      "Write",
      "Edit",
      "MultiEdit",
      "Glob",
      "Grep",
      "WebSearch",
      "WebFetch",
      "Agent",
      "AskUserQuestion",
      "Skill",
      "mcp__*"
    ],
    "ask": [
      "Bash(git push*)",
      "Bash(git push -f*)",
      "Bash(git reset --hard*)",
      "Bash(git clean*)",
      "Bash(git checkout --*)",
      "Bash(rm -rf*)",
      "Bash(sudo*)",
      "Bash(curl*|*)",
      "Bash(npm publish*)",
      "Bash(pnpm publish*)"
    ],
    "deny": [
      "Bash(rm -rf /*)",
      "Bash(rm -rf ~*)"
    ]
  },
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": [
    $MCP_LIST
  ]
}
EOF

echo "  ✓ wrote $SETTINGS"

echo ""
echo "✓ Setup complete."
echo ""
echo "What this configured:"
echo "  • defaultMode: acceptEdits (no prompts for Read/Edit/Write/Bash/MCP)"
echo "  • Dangerous ops still prompt: git push, git reset --hard, rm -rf, sudo, publish"
echo "  • Unrecoverable ops blocked: rm -rf /, rm -rf ~"
echo "  • MCPs enabled: context7, exa, playwright"
if [[ $HAS_IOS -eq 1 ]]; then
  echo "                    + xcodebuild, ios-simulator (iOS detected)"
fi
echo ""
echo "Restart Claude Code (or /reload-settings) for changes to take effect."
echo ""
echo "Edit .claude/settings.local.json directly to customize."
echo ""
echo "Known issue: parallel implementor dispatches (multiple subagents in one"
echo "message) may not inherit Bash patterns from settings.local.json reliably."
echo "If you see permission prompts during parallel work, add the same"
echo "permissions block to .claude/settings.json (project-shared, checked in)"
echo "instead of (or in addition to) settings.local.json. The values are"
echo "identical; the file location determines scope."
