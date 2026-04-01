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
  elif [[ "$model" != "opus" && "$model" != "sonnet" && "$model" != "haiku" && "$model" != "inherit" ]]; then
    error "$rel_path: invalid model '$model' (must be opus, sonnet, haiku, or inherit)"
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
      if [ "$model" = "opus" ]; then
        pass "$name uses opus (correct for decision-making agent)"
      else
        warn "$name uses $model (expected opus for decision-making agent)"
      fi
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

# ─── 9. Inventory ───────────────────────────────────────────────────
echo "▸ Inventory"

agent_count=$(find "$PLUGIN_ROOT/agents" -name "*.md" | wc -l | tr -d ' ')
skill_count=$(find "$PLUGIN_ROOT/skills" -name "SKILL.md" | wc -l | tr -d ' ')
dim "  Agents:      $agent_count"
dim "  Skills:      $skill_count"

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
