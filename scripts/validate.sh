#!/bin/bash
# coding-agent plugin validation script
# Runs structural, frontmatter, cross-reference, and schema checks
# Exit 0 = all pass, Exit 1 = failures found

set -uo pipefail

PLUGIN_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
ERRORS=0
WARNINGS=0

red() { printf "\033[0;31m%s\033[0m\n" "$1"; }
yellow() { printf "\033[0;33m%s\033[0m\n" "$1"; }
green() { printf "\033[0;32m%s\033[0m\n" "$1"; }
dim() { printf "\033[0;90m%s\033[0m\n" "$1"; }

error() { red "  ✘ $1"; ERRORS=$((ERRORS + 1)); }
warn() { yellow "  ⚠ $1"; WARNINGS=$((WARNINGS + 1)); }
pass() { green "  ✔ $1"; }

echo ""
echo "═══════════════════════════════════════════"
echo "  coding-agent plugin validation"
echo "═══════════════════════════════════════════"
echo ""

# ─── 1. Structure checks ────────────────────────────────────────────
echo "▸ Structure"

for dir in .claude-plugin agents skills; do
  if [ -d "$PLUGIN_ROOT/$dir" ]; then
    pass "$dir/ exists"
  else
    error "$dir/ missing"
  fi
done

for file in .claude-plugin/plugin.json settings.json .mcp.json hooks/hooks.json; do
  if [ -f "$PLUGIN_ROOT/$file" ]; then
    pass "$file exists"
  else
    error "$file missing"
  fi
done

echo ""

# ─── 2. JSON validation ─────────────────────────────────────────────
echo "▸ JSON validity"

for file in .claude-plugin/plugin.json settings.json .mcp.json hooks/hooks.json; do
  filepath="$PLUGIN_ROOT/$file"
  if [ -f "$filepath" ]; then
    if python3 -m json.tool "$filepath" > /dev/null 2>&1; then
      pass "$file is valid JSON"
    else
      error "$file has invalid JSON"
    fi
  fi
done

echo ""

# ─── 3. Agent frontmatter checks ────────────────────────────────────
echo "▸ Agent frontmatter"

while IFS= read -r agent_file; do
  rel_path="${agent_file#$PLUGIN_ROOT/}"

  first_line=$(head -1 "$agent_file")
  if [ "$first_line" != "---" ]; then
    error "$rel_path: missing frontmatter (no opening ---)"
    continue
  fi

  name=$(sed -n '/^---$/,/^---$/p' "$agent_file" | grep "^name:" | head -1 | sed 's/name: *//')
  description=$(sed -n '/^---$/,/^---$/p' "$agent_file" | grep "^description:" | head -1)
  model=$(sed -n '/^---$/,/^---$/p' "$agent_file" | grep "^model:" | head -1 | sed 's/model: *//')

  if [ -z "$name" ]; then
    error "$rel_path: missing 'name' in frontmatter"
  fi
  if [ -z "$description" ]; then
    error "$rel_path: missing 'description' in frontmatter"
  fi
  if [ -z "$model" ]; then
    error "$rel_path: missing 'model' in frontmatter"
  elif [[ "$model" != "opus" && "$model" != "sonnet" && "$model" != "haiku" && "$model" != "fable" && "$model" != "inherit" && ! "$model" =~ ^claude-(opus|sonnet|haiku|fable)-[0-9]+ ]]; then
    error "$rel_path: invalid model '$model' (must be opus/sonnet/haiku/fable/inherit, or a full model ID like claude-opus-4-8 or claude-fable-5)"
  fi

  if [ -n "$name" ] && [ -n "$model" ]; then
    pass "$rel_path (name=$name, model=$model)"
  fi
done < <(find "$PLUGIN_ROOT/agents" -name "*.md" | sort)

echo ""

# ─── 4. Skill frontmatter checks ────────────────────────────────────
echo "▸ Skill frontmatter"

while IFS= read -r skill_file; do
  rel_path="${skill_file#$PLUGIN_ROOT/}"

  first_line=$(head -1 "$skill_file")
  if [ "$first_line" != "---" ]; then
    error "$rel_path: missing frontmatter (no opening ---)"
    continue
  fi

  name=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep "^name:" | head -1 | sed 's/name: *//')
  description=$(sed -n '/^---$/,/^---$/p' "$skill_file" | grep "^description:" | head -1)

  if [ -z "$name" ]; then
    error "$rel_path: missing 'name' in frontmatter"
  fi
  if [ -z "$description" ]; then
    error "$rel_path: missing 'description' in frontmatter"
  fi

  if [ -n "$name" ]; then
    pass "$rel_path (name=$name)"
  fi
done < <(find "$PLUGIN_ROOT/skills" -name "SKILL.md" | sort)

echo ""

# ─── 5. Cross-reference checks ──────────────────────────────────────
echo "▸ Cross-references"

# Check that specialist skills referenced in leads exist
for lead_file in "$PLUGIN_ROOT"/agents/domain-lead.md; do
  [ -f "$lead_file" ] || continue
  lead_name=$(basename "$lead_file" .md)

  while IFS= read -r skill_ref; do
    skill_name="${skill_ref%-specialist}"
    # Check if the specialist skill exists anywhere under skills/
    found=$(find "$PLUGIN_ROOT/skills" -path "*/${skill_ref}/SKILL.md" -o -path "*/${skill_ref}-specialist/SKILL.md" 2>/dev/null | head -1)
    if [ -n "$found" ]; then
      pass "$lead_name references skill $skill_ref (exists)"
    fi
  done < <(grep -oE '[a-z]+-specialist' "$lead_file" 2>/dev/null | sort -u || true)
done

pass "skill references checked"

# Check that every check named in a protocol "## Checks fired" table or the
# orchestrator critical-checks list resolves to a checks/<name>.sh script.
referenced_checks=$(
  {
    for pf in "$PLUGIN_ROOT"/protocols/*.md; do
      awk '/^## Checks fired/{s=1;next} s&&/^#/{s=0} s&&/^\|/{print}' "$pf"
    done
    awk '/Critical checks/{s=1;next} s&&/^##/{s=0} s&&/^- `/{print}' "$PLUGIN_ROOT/agents/orchestrator.md"
  } | sed -nE 's/^[^`]*`([a-z][a-z0-9-]+).*/\1/p' | sort -u
)
check_refs_missing=""
for ref in $referenced_checks; do
  [ -f "$PLUGIN_ROOT/checks/$ref.sh" ] || check_refs_missing="$check_refs_missing $ref"
done
if [ -z "$check_refs_missing" ]; then
  pass "all referenced checks resolve to scripts"
else
  # Warn (not error): some names are conceptual sub-conditions covered by a
  # composite check (e.g. close-out-complete) or action-log events, not drift.
  # Surfaced for triage so genuinely-missing scripts get caught early.
  for m in $check_refs_missing; do
    warn "referenced check '$m' has no checks/$m.sh (composite-covered, event, or drift — triage)"
  done
fi

echo ""

# ─── 6. Artifact path checks ────────────────────────────────────────
echo "▸ Artifact paths"

bad_refs=$(grep -rl "docs/agents/" "$PLUGIN_ROOT/agents/" "$PLUGIN_ROOT/hooks/" "$PLUGIN_ROOT/README.md" 2>/dev/null || true)
if [ -z "$bad_refs" ]; then
  pass "no stale docs/agents/ references found"
else
  for bad_file in $bad_refs; do
    error "${bad_file#$PLUGIN_ROOT/} still references docs/agents/ (should be .coding-agent/)"
  done
fi

coord_refs=$(grep -rl "\.coding-agent/" "$PLUGIN_ROOT/agents/" 2>/dev/null | wc -l | tr -d ' ')
if [ "$coord_refs" -gt 0 ]; then
  pass "phase agents reference .coding-agent/ for artifact coordination"
else
  warn "no phase agents reference .coding-agent/ — coordination may be broken"
fi

echo ""

# ─── 7. Model tier checks ───────────────────────────────────────────
echo "▸ Model tier conventions"

for agent_file in "$PLUGIN_ROOT"/agents/*.md; do
  [ -f "$agent_file" ] || continue
  name=$(basename "$agent_file" .md)
  model=$(sed -n '/^---$/,/^---$/p' "$agent_file" | grep "^model:" | head -1 | sed 's/model: *//')

  case "$name" in
    orchestrator|brainstormer|planner|reviewer)
      case "$model" in
        opus|claude-opus-*|fable|claude-fable-*)
          pass "$name uses $model (opus/fable tier — correct for decision-making agent)" ;;
        *)
          warn "$name uses $model (expected opus or fable for decision-making agent)" ;;
      esac
      ;;
    domain-lead)
      ;; # checked separately below
  esac
done

# Check domain-lead uses sonnet
for agent_file in "$PLUGIN_ROOT"/agents/domain-lead.md; do
  [ -f "$agent_file" ] || continue
  name=$(basename "$agent_file" .md)
  model=$(sed -n '/^---$/,/^---$/p' "$agent_file" | grep "^model:" | head -1 | sed 's/model: *//')
  if [ "$model" = "sonnet" ]; then
    pass "$name uses sonnet (correct for domain lead)"
  else
    warn "$name uses $model (expected sonnet for domain lead)"
  fi
done

echo ""

# ─── 8. Content quality checks ──────────────────────────────────────
echo "▸ Content quality"

while IFS= read -r agent_file; do
  rel_path="${agent_file#$PLUGIN_ROOT/}"
  line_count=$(wc -l < "$agent_file" | tr -d ' ')
  if [ "$line_count" -lt 20 ]; then
    warn "$rel_path has only $line_count lines (may be a stub)"
  fi
done < <(find "$PLUGIN_ROOT/agents" -name "*.md")

while IFS= read -r skill_file; do
  rel_path="${skill_file#$PLUGIN_ROOT/}"
  line_count=$(wc -l < "$skill_file" | tr -d ' ')
  if [ "$line_count" -lt 10 ]; then
    warn "$rel_path has only $line_count lines (may be a stub)"
  fi
done < <(find "$PLUGIN_ROOT/skills" -name "SKILL.md")

pass "content quality checked"

echo ""

# ─── 9. v5 ──────────────────────────────────────────────────────────
# v5 lives beside v4 and is not registered in the plugin manifest yet. These
# checks lint it on its own terms so a break is caught before it ships.
if [ -d "$PLUGIN_ROOT/v5" ]; then
  echo "▸ v5"

  # 9.1 Agent frontmatter: required keys present, `name` matches the filename.
  v5_agent_ok=1
  while IFS= read -r f; do
    rel="${f#$PLUGIN_ROOT/}"
    base="$(basename "$f" .md)"
    fm=$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f{print}' "$f")
    for key in name description model tools; do
      echo "$fm" | grep -qE "^$key:" || { error "$rel frontmatter missing '$key:'"; v5_agent_ok=0; }
    done
    fm_name=$(echo "$fm" | grep -E '^name:' | head -1 | sed 's/^name:[[:space:]]*//' | tr -d '"'"'"' ')
    if [ -n "$fm_name" ] && [ "$fm_name" != "$base" ]; then
      error "$rel declares name '$fm_name' but the file is '$base.md'"; v5_agent_ok=0
    fi
  done < <(find "$PLUGIN_ROOT/v5/agents" -name "*.md" 2>/dev/null)
  [ "$v5_agent_ok" -eq 1 ] && pass "v5 agent frontmatter valid (name/description/model/tools)"

  # 9.2 Shell scripts: executable and syntactically valid.
  v5_sh_ok=1
  while IFS= read -r f; do
    rel="${f#$PLUGIN_ROOT/}"
    [ -x "$f" ] || { error "$rel is not executable (chmod +x)"; v5_sh_ok=0; }
    bash -n "$f" 2>/dev/null || { error "$rel has a bash syntax error"; v5_sh_ok=0; }
  done < <(find "$PLUGIN_ROOT/v5/gates" "$PLUGIN_ROOT/v5/lib" "$PLUGIN_ROOT/v5/hooks" -name "*.sh" 2>/dev/null)
  [ "$v5_sh_ok" -eq 1 ] && pass "v5 shell scripts executable + syntax-clean"

  # 9.3 Referenced plugin-internal paths resolve (CLAUDE_PLUGIN_ROOT = repo root).
  v5_path_ok=1
  while IFS= read -r ref; do
    target="$PLUGIN_ROOT/${ref#\$\{CLAUDE_PLUGIN_ROOT\}/}"
    [ -e "$target" ] || { error "v5 references a missing path: $ref"; v5_path_ok=0; }
  done < <(grep -rhoE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9_./-]+' \
             "$PLUGIN_ROOT/v5/agents" "$PLUGIN_ROOT/v5/gates" "$PLUGIN_ROOT/v5/lib" 2>/dev/null \
           | sed 's/[.,)]*$//' | sort -u)
  [ "$v5_path_ok" -eq 1 ] && pass "v5 \${CLAUDE_PLUGIN_ROOT} paths all resolve"

  # 9.4 Subcommand contract: every design-review.sh subcommand an agent invokes
  #     must exist in the script's case statement. (A prompt telling an agent to
  #     run a nonexistent subcommand silently blocks its gate forever.)
  drs="$PLUGIN_ROOT/scripts/design-review.sh"
  if [ -f "$drs" ]; then
    known=$(grep -oE '^[[:space:]]+[a-z][a-z|-]*\)' "$drs" | tr -d ' )' | tr '|' '\n' | sort -u)
    v5_cmd_ok=1
    while IFS= read -r sub; do
      [ -z "$sub" ] && continue
      echo "$known" | grep -qx "$sub" \
        || { error "v5 agents invoke 'design-review.sh $sub' but the script has no such subcommand (has: $(echo "$known" | tr '\n' ' '))"; v5_cmd_ok=0; }
    done < <(grep -rhoE 'design-review\.sh[[:space:]]+[a-z][a-z-]*' "$PLUGIN_ROOT/v5/agents" 2>/dev/null \
             | awk '{print $2}' | sort -u)
    [ "$v5_cmd_ok" -eq 1 ] && pass "v5 design-review.sh subcommands all exist"
  fi

  # 9.5 Kind taxonomy: every evidence kind a gate greps for must be recordable —
  #     i.e. some agent prompt instructs `record.sh ... <kind>`.
  v5_kind_ok=1
  # `.*` (not `[^\n]`): grep is line-based so `.` never crosses lines, and a
  # bracket `[^\n]` would treat \n as the literal chars \ and n — breaking on a
  # recorded command that contains backslashes (e.g. the review verdict's \$/\[).
  recorded=$(grep -rhoE 'record\.sh.*"[[:space:]]+[a-z]+' "$PLUGIN_ROOT/v5/agents" 2>/dev/null \
             | awk '{print $NF}' | sort -u)
  while IFS= read -r kind; do
    [ -z "$kind" ] && continue
    echo "$recorded" | grep -qx "$kind" \
      || { error "gates expect evidence kind '$kind' but no v5 agent records it via record.sh"; v5_kind_ok=0; }
  done < <(for gf in "$PLUGIN_ROOT"/v5/gates/*.sh; do grep -vE '^[[:space:]]*#' "$gf"; done 2>/dev/null \
           | grep -oE '"kind":"[a-z]+"|evidence_match[[:space:]]+[a-z]+' \
           | sed -E 's/.*"kind":"([a-z]+)".*/\1/; s/evidence_match[[:space:]]+//' | sort -u)
  [ "$v5_kind_ok" -eq 1 ] && pass "v5 evidence kinds are all recordable by some agent"

  # 9.6 Manifest paths resolve: the agents[]/hooks[] arrays REPLACE default
  #     discovery (per the plugin reference), so a bad path silently drops an
  #     agent/hook instead of erroring at load. Every listed file must exist.
  man_ok=1
  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    [ -e "$PLUGIN_ROOT/${rel#./}" ] || { error "plugin.json lists a missing path: $rel"; man_ok=0; }
  done < <(python3 -c "import json;d=json.load(open('$PLUGIN_ROOT/.claude-plugin/plugin.json'));[print(x) for x in d.get('agents',[])+d.get('hooks',[])]" 2>/dev/null)
  [ "$man_ok" -eq 1 ] && pass "plugin.json agents[]/hooks[] paths all resolve"

  echo ""
fi

# ─── 10. Inventory ──────────────────────────────────────────────────
echo "▸ Inventory"

# Derive real counts from the directories (single source of truth).
agent_count=$(find "$PLUGIN_ROOT/agents" -name "*.md" | wc -l | tr -d ' ')
skill_count=$(find "$PLUGIN_ROOT/skills" -name "SKILL.md" | wc -l | tr -d ' ')
protocol_count=$(find "$PLUGIN_ROOT/protocols" -name "*.md" ! -name "README.md" | wc -l | tr -d ' ')
check_count=$(find "$PLUGIN_ROOT/checks" -name "*.sh" ! -name "lib.sh" | wc -l | tr -d ' ')
template_count=$(find "$PLUGIN_ROOT/templates" -name "*.template.*" | wc -l | tr -d ' ')
mcp_count=$(jq -r '(.mcpServers // {}) | length' "$PLUGIN_ROOT/.mcp.json" 2>/dev/null || echo "?")
dim "  Agents:      $agent_count"
dim "  Skills:      $skill_count"
dim "  Protocols:   $protocol_count"
dim "  Checks:      $check_count"
dim "  Templates:   $template_count"
dim "  MCP servers: $mcp_count"

# Verify AGENTS.md's canonical inventory line matches reality. AGENTS.md is the
# single source of truth (CLAUDE.md redirects to it); when it drifts, fix it +
# the mirrors (ARCHITECTURE.md, docs/README.md, .claude-plugin/marketplace.json).
summary=$(grep -m1 -E '[0-9]+ agents \+ .* [0-9]+ MCP servers' "$PLUGIN_ROOT/AGENTS.md" 2>/dev/null || true)
if [ -z "$summary" ]; then
  warn "AGENTS.md canonical inventory line not found — cannot verify counts"
else
  doc_n() { echo "$summary" | grep -oE "[0-9]+ $1" | grep -oE '^[0-9]+' | head -1; }
  drift=0
  for pair in "agents:$agent_count" "skills:$skill_count" "named protocols:$protocol_count" \
              "deterministic checks:$check_count" "artifact templates:$template_count" "MCP servers:$mcp_count"; do
    label="${pair%:*}"; real="${pair##*:}"; doc=$(doc_n "$label")
    if [ -n "$doc" ] && [ "$doc" != "$real" ]; then
      error "inventory drift: $real $label on disk, AGENTS.md says $doc — sync AGENTS.md + plugin.json + marketplace.json + ARCHITECTURE.md + docs/README.md"
      drift=1
    fi
  done
  [ "$drift" -eq 0 ] && pass "AGENTS.md inventory counts match the directories"
fi

echo ""
echo "═══════════════════════════════════════════"

if [ "$ERRORS" -gt 0 ]; then
  red "  FAILED: $ERRORS errors, $WARNINGS warnings"
  echo "═══════════════════════════════════════════"
  echo ""
  exit 1
elif [ "$WARNINGS" -gt 0 ]; then
  yellow "  PASSED with $WARNINGS warnings"
  echo "═══════════════════════════════════════════"
  echo ""
  exit 0
else
  green "  ALL CHECKS PASSED"
  echo "═══════════════════════════════════════════"
  echo ""
  exit 0
fi
