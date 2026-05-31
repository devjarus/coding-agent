#!/usr/bin/env bash
# run-and-record.sh — run the project's verification and record the RESULT as a
# measured artifact. Test counts / pass-fail are then READ from a file, never
# typed from memory. This is the mechanical kill for fabricated "verified / N
# tests" narration: the numbers in work.md and commit messages come from THIS
# file, tied to a git tree hash, so a number that was never measured cannot be
# typed.
#
# Usage:
#   run-and-record.sh <repo_root> [<verify_cmd>]
#     verify_cmd defaults to the project's test script (npm test / pytest / go
#     test / cargo test, best-effort detected). Override explicitly, e.g.
#     run-and-record.sh . "npm run typecheck && npm test"
#
# Writes <repo>/.coding-agent/last-verify.json:
#   { "ok": bool, "exit_code": N, "command": "...", "tree": "<git tree sha>",
#     "tests": {"passed": N|null, "failed": N|null}, "raw_tail": "...",
#     "ran_at": "<iso>" }
# `tree` is the content hash of all tracked+new source (excluding .coding-agent),
# computed in a throwaway index so the real index is untouched. The commit-msg
# hook compares it to the staged tree to reject a commit whose verification
# doesn't match what's actually being committed.
#
# Exit code MIRRORS the verification command (0 = green). The recorded file is
# the source of truth; this script never interprets pass/fail itself.

set -uo pipefail
REPO="${1:-$PWD}"
shift 2>/dev/null || true
VERIFY_CMD="${1:-}"

cd "$REPO" 2>/dev/null || { echo '{"ok":false,"reason":"not a directory"}'; exit 2; }

# ── detect a verify command if none was given ───────────────────────
if [[ -z "$VERIFY_CMD" ]]; then
  if [[ -f package.json ]] && grep -q '"test"[[:space:]]*:' package.json; then
    VERIFY_CMD="npm test"
  elif { [[ -f pyproject.toml ]] || [[ -f pytest.ini ]] || [[ -d tests ]]; } && command -v pytest >/dev/null 2>&1; then
    VERIFY_CMD="pytest"
  elif [[ -f go.mod ]]; then
    VERIFY_CMD="go test ./..."
  elif [[ -f Cargo.toml ]]; then
    VERIFY_CMD="cargo test"
  else
    echo '{"ok":false,"reason":"no verify command detected — pass one explicitly: run-and-record.sh <repo> \"<cmd>\""}'
    exit 2
  fi
fi

# ── content hash of all source (tracked + new), .coding-agent excluded ──
# Use a throwaway index so the real index/staging is never disturbed.
tree=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  tmp_index="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/cga-idx.$$")"
  if GIT_INDEX_FILE="$tmp_index" git read-tree HEAD 2>/dev/null \
     || GIT_INDEX_FILE="$tmp_index" git read-tree --empty 2>/dev/null; then
    GIT_INDEX_FILE="$tmp_index" git add -A -- . ':(exclude).coding-agent' 2>/dev/null || true
    tree="$(GIT_INDEX_FILE="$tmp_index" git write-tree 2>/dev/null || true)"
  fi
  rm -f "$tmp_index"
fi

# ── run verification, capture output + exit ─────────────────────────
out="$(eval "$VERIFY_CMD" 2>&1)"
code=$?

# ── parse test counts (best-effort across common runners) ───────────
passed="$(printf '%s\n' "$out" | grep -oiE '[0-9]+ (passed|passing)' | grep -oE '[0-9]+' | head -1)"
failed="$(printf '%s\n' "$out" | grep -oiE '[0-9]+ (failed|failing)' | grep -oE '[0-9]+' | head -1)"
passed="${passed:-null}"
failed="${failed:-null}"

ran_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
raw_tail="$(printf '%s\n' "$out" | tail -20)"

mkdir -p "$REPO/.coding-agent"
ok=false; [[ $code -eq 0 ]] && ok=true

jq -n \
  --argjson ok "$ok" \
  --argjson code "$code" \
  --arg cmd "$VERIFY_CMD" \
  --arg tree "$tree" \
  --argjson passed "$passed" \
  --argjson failed "$failed" \
  --arg raw "$raw_tail" \
  --arg ran_at "$ran_at" \
  '{ok:$ok, exit_code:$code, command:$cmd, tree:$tree, tests:{passed:$passed, failed:$failed}, raw_tail:$raw, ran_at:$ran_at}' \
  > "$REPO/.coding-agent/last-verify.json"

echo "verify: exit=$code passed=$passed failed=$failed tree=${tree:0:12} → .coding-agent/last-verify.json"
exit $code
