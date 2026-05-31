#!/usr/bin/env bash
# no-secrets-staged — Block commits that stage secret-bearing files
# or contain high-signal credential patterns in the diff.
#
# Usage:  no-secrets-staged.sh [<repo_root>]
#         repo_root defaults to $PWD
#
# Exits 0 with {"ok":true,...}  if the staged set is clean.
# Exits 1 with {"ok":false,"reason":"...","hits":[...]} otherwise.
#
# Designed to run in the orchestrator's commit gate, BEFORE the diff is shown
# to the user for approval. False positives are possible — they should be
# rare; resolve by un-staging the file or, if genuinely intended (e.g. test
# fixture), the user can explicitly override at the approve gate.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

CHECK_NAME="no-secrets-staged"
REPO_ROOT="${1:-$PWD}"

cd "$REPO_ROOT" 2>/dev/null || { emit_fail "$CHECK_NAME" "not a directory: $REPO_ROOT"; exit 1; }

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  emit_fail "$CHECK_NAME" "not a git repository: $REPO_ROOT"
  exit 1
fi

# ── 1. Filename deny-list ───────────────────────────────────────────
# Patterns matched against staged file paths. Anchor with $ for bare names,
# leave bare for substring matches (e.g. ".pem" matches anywhere).
FILE_DENY=(
  '(^|/)\.env$'
  '(^|/)\.env\.[^/]*$'        # .env.local, .env.production, etc — but NOT .env.example/.env.sample/.env.template
  '\.pem$'
  '\.p12$'
  '\.pfx$'
  '(^|/)id_rsa$'
  '(^|/)id_ed25519$'
  '(^|/)id_ecdsa$'
  '(^|/)id_dsa$'
  '\.keystore$'
  '(^|/)credentials\.json$'
  '(^|/)service-account\.json$'
)
# Allowlist — these are explicitly fine (templates and examples).
FILE_ALLOW=(
  '\.env\.example$'
  '\.env\.sample$'
  '\.env\.template$'
)

staged_files=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null)

file_hits=()
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  allowed=0
  for a in "${FILE_ALLOW[@]}"; do
    if [[ "$f" =~ $a ]]; then allowed=1; break; fi
  done
  [[ $allowed -eq 1 ]] && continue
  for d in "${FILE_DENY[@]}"; do
    if [[ "$f" =~ $d ]]; then
      file_hits+=("$f")
      break
    fi
  done
done <<< "$staged_files"

# ── 2. Content pattern scan on staged diff ──────────────────────────
# Only added lines (+ prefix), high-signal patterns only. Keep tight to
# minimize false positives. The user can still approve at the commit gate.
CONTENT_PATTERNS=(
  'AKIA[0-9A-Z]{16}'                            # AWS access key
  'ASIA[0-9A-Z]{16}'                            # AWS temp access key
  '-----BEGIN (RSA|EC|OPENSSH|DSA|PRIVATE) ?'   # private key blocks
  'xox[baprs]-[0-9A-Za-z-]{10,}'                # Slack tokens
  'ghp_[0-9A-Za-z]{36}'                         # GitHub personal access token
  'gho_[0-9A-Za-z]{36}'                         # GitHub OAuth token
  'github_pat_[0-9A-Za-z_]{82}'                 # GitHub fine-grained PAT
  'glpat-[0-9A-Za-z_-]{20}'                     # GitLab PAT
  'sk-[A-Za-z0-9]{32,}'                         # OpenAI / Anthropic-style API keys
  'sk-ant-[A-Za-z0-9_-]{20,}'                   # Anthropic API keys
)

content_hits=()
diff_added=$(git diff --cached -U0 --diff-filter=ACMR 2>/dev/null \
  | grep -E '^\+' | grep -vE '^\+\+\+' || true)

if [[ -n "$diff_added" ]]; then
  for pat in "${CONTENT_PATTERNS[@]}"; do
    # `-- "$pat"` so patterns starting with `-` (e.g. -----BEGIN) aren't parsed as flags.
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      content_hits+=("$(printf '%.80s' "${pat} → ${line#+}")")
    done < <(printf '%s\n' "$diff_added" | grep -E -- "$pat" || true)
  done
fi

# ── 3. Emit result ──────────────────────────────────────────────────
if [[ ${#file_hits[@]} -eq 0 && ${#content_hits[@]} -eq 0 ]]; then
  emit_pass "$CHECK_NAME"
  exit 0
fi

reason=""
[[ ${#file_hits[@]} -gt 0 ]]    && reason+="staged secret files: ${file_hits[*]}; "
[[ ${#content_hits[@]} -gt 0 ]] && reason+="credential patterns in diff: ${#content_hits[@]} hit(s); "
reason="${reason%; }"

# JSON output with both lists for orchestrator to surface.
# Guard array expansions with `${arr[@]+"${arr[@]}"}` for bash 3.2 + set -u.
to_json_array() {
  if [[ $# -eq 0 ]]; then echo '[]'; return; fi
  printf '%s\n' "$@" | jq -R . | jq -sc .
}
file_json=$(to_json_array ${file_hits[@]+"${file_hits[@]}"})
content_json=$(to_json_array ${content_hits[@]+"${content_hits[@]}"})
printf '{"check":"%s","ok":false,"reason":%s,"file_hits":%s,"content_hits":%s}\n' \
  "$CHECK_NAME" \
  "$(printf '%s' "$reason" | jq -Rs .)" \
  "$file_json" \
  "$content_json"
exit 1
