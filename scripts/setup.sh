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

# ─── git commit-msg hook — block fabricated verification claims ──────
# Rejects a commit whose message asserts verification ("verified", "passing",
# "N tests pass") unless .coding-agent/last-verify.json is green and its tree
# matches what is being committed. Makes "verified" a machine-checked fact.
if git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  HOOKS_DIR="$(git -C "$TARGET" rev-parse --git-path hooks 2>/dev/null)"
  if [[ -n "$HOOKS_DIR" ]]; then
    mkdir -p "$HOOKS_DIR"
    HOOK="$HOOKS_DIR/commit-msg"
    if [[ -f "$HOOK" ]] && ! grep -q 'coding-agent commit-msg hook' "$HOOK" 2>/dev/null; then
      cp "$HOOK" "$HOOK.backup.$(date +%Y%m%dT%H%M%S)"
      echo "  ✓ backed up existing commit-msg hook"
    fi
    cat > "$HOOK" <<'HOOK_EOF'
#!/usr/bin/env bash
# coding-agent commit-msg hook — blocks fabricated verification claims.
# A commit message asserting verification must be backed by a GREEN, CURRENT
# .coding-agent/last-verify.json: green (exit 0) AND its recorded source tree
# must still match the working source now (nothing changed since verifying).
# Tree comparison is content-based (non-racy). Installed by coding-agent
# setup.sh — delete this file to disable.
set -u
msg="$(cat "$1" 2>/dev/null)"
# Only gate messages that CLAIM verification — everything else passes untouched.
printf '%s' "$msg" | grep -qiE 'verified|passing|[0-9]+ tests? (pass|green)|all tests pass|tests pass' || exit 0
REPO="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
VF="$REPO/.coding-agent/last-verify.json"
reject() {
  echo "✗ commit-msg: message claims verification but $1" >&2
  echo "  Run run-and-record.sh for a fresh green record, or drop the claim from the message." >&2
  exit 1
}
[ -f "$VF" ] || reject "no .coding-agent/last-verify.json exists"
command -v jq >/dev/null 2>&1 || exit 0   # cannot validate without jq — degrade open
ok="$(jq -r '.ok // false' "$VF" 2>/dev/null)"
code="$(jq -r '.exit_code // 1' "$VF" 2>/dev/null)"
vtree="$(jq -r '.tree // ""' "$VF" 2>/dev/null)"
{ [ "$ok" = "true" ] && [ "$code" = "0" ]; } || reject "last-verify.json is red (exit_code=$code)"
# Currency: recompute the all-source tree the SAME way run-and-record did
# (throwaway index, .coding-agent excluded). If it differs, source changed since
# the verification was recorded.
now_tree=""
tmp="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/cga-h.$$")"
if GIT_INDEX_FILE="$tmp" git read-tree HEAD 2>/dev/null \
   || GIT_INDEX_FILE="$tmp" git read-tree --empty 2>/dev/null; then
  GIT_INDEX_FILE="$tmp" git add -A -- . ':(exclude).coding-agent' 2>/dev/null || true
  now_tree="$(GIT_INDEX_FILE="$tmp" git write-tree 2>/dev/null || true)"
fi
rm -f "$tmp"
if [ -n "$vtree" ] && [ -n "$now_tree" ] && [ "$vtree" != "$now_tree" ]; then
  reject "source changed since verification (recorded tree ${vtree} != current ${now_tree}) — re-verify"
fi
exit 0
HOOK_EOF
    chmod +x "$HOOK"
    echo "  ✓ installed commit-msg hook (rejects unverified 'verified/passing' claims)"
  fi
fi

echo ""
echo "✓ Setup complete."
echo ""
echo "What this configured:"
echo "  • defaultMode: acceptEdits (no prompts for Read/Edit/Write/Bash/MCP)"
echo "  • Dangerous ops still prompt: git push, git reset --hard, rm -rf, sudo, publish"
echo "  • Unrecoverable ops blocked: rm -rf /, rm -rf ~"
echo "  • commit-msg hook: rejects 'verified/passing' messages unless verification is recorded + green"
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
