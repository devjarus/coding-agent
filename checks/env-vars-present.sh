#!/usr/bin/env bash
# env-vars-present — Verify the env-var NAMES declared in environments.md
# are actually present in the target environment, by running the project's
# declared `env_list_command`.
#
# Usage:  env-vars-present.sh <repo_root> [<env_name>]
#         env_name defaults to "production"
#
# Exits 0 with {"ok":true,...}  if all expected vars are present.
# Exits 1 with {"ok":false,"reason":"..."} otherwise.
#
# This check is platform-agnostic: the env_list_command is declared per-project.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

CHECK_NAME="env-vars-present"
REPO_ROOT="${1:-$PWD}"
ENV_NAME="${2:-production}"
ENV_FILE="$REPO_ROOT/.coding-agent/environments.md"

if [[ ! -f "$ENV_FILE" ]]; then
  emit_fail "$CHECK_NAME" "environments.md not found at $ENV_FILE"
  exit 1
fi

# Extract the H2 section for the requested env (lines from "## <env>" up to next "## " or EOF).
section=$(awk -v env="$ENV_NAME" '
  $0 ~ "^## "env"[[:space:]]*$" { in_section=1; next }
  in_section && /^## / { exit }
  in_section { print }
' "$ENV_FILE")

if [[ -z "$section" ]]; then
  emit_fail "$CHECK_NAME" "no '## $ENV_NAME' section in environments.md"
  exit 1
fi

# Extract env_list_command (single-line value after the field name).
env_list_command=$(printf '%s\n' "$section" | awk -F': ' '/^- env_list_command:/{sub(/^- env_list_command: */,""); print; exit}')
if [[ -z "$env_list_command" || "$env_list_command" == "<"* ]]; then
  emit_fail "$CHECK_NAME" "env_list_command not configured for $ENV_NAME"
  exit 1
fi

# Extract expected_env_vars (YAML list under that key).
expected=$(printf '%s\n' "$section" | awk '
  /^- expected_env_vars:/ { in_list=1; next }
  in_list && /^[[:space:]]+- / { sub(/^[[:space:]]+- */,""); print; next }
  in_list && /^- / { exit }
')

if [[ -z "$expected" ]]; then
  emit_fail "$CHECK_NAME" "expected_env_vars empty for $ENV_NAME"
  exit 1
fi

# Run the project's env_list_command. Anything on stdout is treated as the env's keyspace.
# Accepts either NAME=VALUE or bare NAME per line; we normalize to NAME.
actual_raw=$(cd "$REPO_ROOT" && eval "$env_list_command" 2>/dev/null)
rc=$?
if [[ $rc -ne 0 ]]; then
  emit_fail "$CHECK_NAME" "env_list_command failed (exit $rc): $env_list_command"
  exit 1
fi

actual=$(printf '%s\n' "$actual_raw" | sed 's/=.*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | sort -u)

missing=()
while IFS= read -r var; do
  [[ -z "$var" ]] && continue
  if ! grep -qx "$var" <<< "$actual"; then
    missing+=("$var")
  fi
done <<< "$expected"

if [[ ${#missing[@]} -gt 0 ]]; then
  emit_fail "$CHECK_NAME" "missing in $ENV_NAME: ${missing[*]}"
  exit 1
fi

printf '{"check":"%s","ok":true,"env":"%s","expected_count":%d}\n' \
  "$CHECK_NAME" "$ENV_NAME" "$(printf '%s\n' "$expected" | wc -l | tr -d ' ')"
exit 0
