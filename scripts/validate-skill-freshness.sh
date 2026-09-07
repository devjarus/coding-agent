#!/usr/bin/env bash
# Validate the maintenance contract for version-sensitive skills.
# A skill opts in with a `## Version-sensitive guidance` section and must then
# have a dated, sourced registry entry that has not passed its recheck date.
set -uo pipefail

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
REGISTRY="$ROOT/skills/freshness.json"
errors=()

[[ -f "$REGISTRY" ]] || errors+=("skills/freshness.json is missing")
command -v jq >/dev/null 2>&1 || errors+=("jq is required")
command -v python3 >/dev/null 2>&1 || errors+=("python3 is required")

if [[ ${#errors[@]} -eq 0 ]]; then
  jq -e '.schema_version == 1
    and (.skills | type == "array")
    and all(.skills[];
      (.path | type == "string") and
      (.verified_on | type == "string") and
      (.recheck_by | type == "string") and
      (.version_scope | type == "string") and
      (.sources | type == "array")
    )' "$REGISTRY" >/dev/null 2>&1 \
    || errors+=("freshness registry has an invalid schema")
fi

today="$(date -u +%F)"
registered=()
if [[ ${#errors[@]} -eq 0 ]]; then
  date_errors="$(python3 - "$REGISTRY" "$today" <<'PY'
import datetime as dt
import json
import sys

registry, today_text = sys.argv[1:]
today = dt.date.fromisoformat(today_text)
items = json.load(open(registry, encoding="utf-8"))["skills"]
paths = [item["path"] for item in items]
for path in sorted({path for path in paths if paths.count(path) > 1}):
    print(f"duplicate registry path: {path}")
for item in items:
    path = item["path"]
    try:
        verified = dt.date.fromisoformat(item["verified_on"])
    except ValueError:
        print(f"{path} has invalid verified_on: {item['verified_on']}")
        continue
    try:
        recheck = dt.date.fromisoformat(item["recheck_by"])
    except ValueError:
        print(f"{path} has invalid recheck_by: {item['recheck_by']}")
        continue
    if verified > today:
        print(f"{path} verified_on is in the future: {verified}")
    if verified > recheck:
        print(f"{path} verified_on is after recheck_by")
    if today > recheck:
        print(f"{path} freshness expired on {recheck}")
PY
)"
  while IFS= read -r message; do
    [[ -n "$message" ]] && errors+=("$message")
  done <<< "$date_errors"

  while IFS=$'\t' read -r path verified recheck scope source_count sources_valid; do
    registered+=("$path")
    skill="$ROOT/skills/$path/SKILL.md"
    [[ -f "$skill" ]] || { errors+=("registered skill missing: $path/SKILL.md"); continue; }
    [[ "$verified" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] \
      || errors+=("$path has invalid verified_on: $verified")
    [[ "$recheck" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] \
      || errors+=("$path has invalid recheck_by: $recheck")
    [[ -n "$scope" ]] || errors+=("$path has empty version_scope")
    [[ "$source_count" -ge 1 && "$sources_valid" == true ]] \
      || errors+=("$path needs at least one HTTPS upstream source")
    grep -q '^## Version-sensitive guidance$' "$skill" \
      || errors+=("$path is registered but lacks a Version-sensitive guidance section")
    grep -Fq "Verified $verified" "$skill" \
      || errors+=("$path body does not match registry verified_on: $verified")
    grep -Fq "Re-check by $recheck" "$skill" \
      || errors+=("$path body does not match registry recheck_by: $recheck")
    while IFS= read -r source; do
      grep -Fq "$source" "$skill" \
        || errors+=("$path body is missing registered source: $source")
    done < <(jq -r --arg path "$path" '.skills[] | select(.path == $path) | .sources[]' "$REGISTRY")
  done < <(jq -r '.skills[] | [
      .path,
      .verified_on,
      .recheck_by,
      .version_scope,
      (.sources | length | tostring),
      ([.sources[] | startswith("https://")] | all | tostring)
    ] | @tsv' "$REGISTRY" 2>/dev/null)

  while IFS= read -r skill; do
    rel="${skill#$ROOT/skills/}"; rel="${rel%/SKILL.md}"
    found=0
    for path in "${registered[@]}"; do [[ "$path" == "$rel" ]] && found=1; done
    [[ "$found" -eq 1 ]] || errors+=("$rel declares version-sensitive guidance but is not registered")
  done < <(grep -rl '^## Version-sensitive guidance$' "$ROOT/skills" --include=SKILL.md | sort)

  # Obvious framework/SDK major claims must opt into the freshness contract.
  # Keep this deliberately narrow to avoid mistaking product phrases such as
  # "version 0" for library guidance.
  while IFS= read -r skill; do
    grep -q '^## Version-sensitive guidance$' "$skill" || {
      rel="${skill#$ROOT/skills/}"; rel="${rel%/SKILL.md}"
      errors+=("$rel contains an explicit framework/SDK version but is not freshness-managed")
    }
  done < <(grep -REil '(^|[^[:alnum:]_])(React|Next(\.js)?|Tailwind|iOS|Xcode|Swift)[[:space:]]*(v?[0-9]+|[0-9]+\+)' "$ROOT/skills" --include=SKILL.md | sort)
fi

if [[ ${#errors[@]} -gt 0 ]]; then
  message="$(printf '%s; ' "${errors[@]}")"; message="${message%; }"
  printf '{"ok":false,"check":"skill-freshness","reason":%s}\n' "$(printf '%s' "$message" | jq -Rs .)"
  exit 1
fi

count="$(jq '.skills | length' "$REGISTRY")"
printf '{"ok":true,"check":"skill-freshness","registered":%s,"checked_on":"%s"}\n' "$count" "$today"
