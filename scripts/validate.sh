#!/bin/bash
# coding-agent plugin validation script
# Runs structural, frontmatter, cross-reference, and schema checks
# Exit 0 = all pass, Exit 1 = failures found

set -uo pipefail

# Args: an optional plugin root path, and an optional --sync flag.
# --sync rewrites the inventory counts in every mirror file from the
# directory-derived counts (the single source of truth), instead of only
# erroring on drift. Default (no flag) behaviour is unchanged.
SYNC=0
PLUGIN_ROOT=""
for arg in "$@"; do
  case "$arg" in
    --sync) SYNC=1 ;;
    *) PLUGIN_ROOT="$arg" ;;
  esac
done
PLUGIN_ROOT="${PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
ERRORS=0
WARNINGS=0

red() { printf "\033[0;31m%s\033[0m\n" "$1"; }
yellow() { printf "\033[0;33m%s\033[0m\n" "$1"; }
green() { printf "\033[0;32m%s\033[0m\n" "$1"; }
dim() { printf "\033[0;90m%s\033[0m\n" "$1"; }

error() { red "  ✘ $1"; ERRORS=$((ERRORS + 1)); }
warn() { yellow "  ⚠ $1"; WARNINGS=$((WARNINGS + 1)); }
pass() { green "  ✔ $1"; }

# sync_counts <root> <agents> <skills> <protocols> <checks> <templates> <mcp>
# Rewrites the count-bearing lines in every mirror file from the directory-
# derived counts. Each replacement is anchored to a distinctive phrase and is
# idempotent — running it twice is a no-op. Keeps the five mirrors (AGENTS.md,
# plugin.json, marketplace.json, ARCHITECTURE.md, docs/README.md) in lockstep
# so contributors never hand-sync counts across files again.
sync_counts() {
  local root="$1" a="$2" s="$3" p="$4" c="$5" t="$6" m="$7"

  # AGENTS.md canonical inventory line ("N agents + N skills + ... + N MCP servers")
  sed -E -i \
    "s/[0-9]+ agents \+ [0-9]+ skills \+ [0-9]+ named protocols \+ [0-9]+ deterministic checks \+ [0-9]+ artifact templates \+ [0-9]+ MCP servers/${a} agents + ${s} skills + ${p} named protocols + ${c} deterministic checks + ${t} artifact templates + ${m} MCP servers/" \
    "$root/AGENTS.md"

  # plugin.json + marketplace.json description ("N agents, N skills, ...")
  for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
    [ -f "$root/$f" ] || continue
    sed -E -i \
      "s/[0-9]+ agents, [0-9]+ skills, [0-9]+ named protocols, [0-9]+ deterministic checks, [0-9]+ artifact templates/${a} agents, ${s} skills, ${p} named protocols, ${c} deterministic checks, ${t} artifact templates/" \
      "$root/$f"
  done

  # ARCHITECTURE.md + docs/README.md — phrase-anchored single counts (wording varies)
  for f in ARCHITECTURE.md docs/README.md; do
    [ -f "$root/$f" ] || continue
    sed -E -i \
      -e "s/(User \+ )[0-9]+ agents/\1${a} agents/g" \
      -e "s/[0-9]+ (named protocols|named workflows)/${p} \1/g" \
      -e "s/[0-9]+ (deterministic checks|deterministic verification scripts)/${c} \1/g" \
      -e "s/[0-9]+ (artifact templates|artifact frontmatter stubs|artifact frontmatter templates)/${t} \1/g" \
      -e "s/[0-9]+ MCP servers/${m} MCP servers/g" \
      "$root/$f"
  done
}

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
  elif [[ "$model" != "opus" && "$model" != "sonnet" && "$model" != "haiku" && "$model" != "inherit" && ! "$model" =~ ^claude-(opus|sonnet|haiku)-[0-9]+-[0-9]+ ]]; then
    error "$rel_path: invalid model '$model' (must be opus/sonnet/haiku/inherit, or a full model ID like claude-opus-4-7)"
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

# Decision-making agents (orchestrator, architect, evaluator, debugger) run on
# opus; implementor runs on sonnet. Accept bare tier names and full model IDs
# (e.g. orchestrator pins claude-opus-4-8).
is_opus() { [ "$1" = "opus" ] || [[ "$1" =~ ^claude-opus- ]]; }
is_sonnet() { [ "$1" = "sonnet" ] || [[ "$1" =~ ^claude-sonnet- ]]; }

for agent_file in "$PLUGIN_ROOT"/agents/*.md; do
  [ -f "$agent_file" ] || continue
  name=$(basename "$agent_file" .md)
  model=$(sed -n '/^---$/,/^---$/p' "$agent_file" | grep "^model:" | head -1 | sed 's/model: *//')

  case "$name" in
    orchestrator|architect|evaluator|debugger)
      if is_opus "$model"; then
        pass "$name uses opus (correct for decision-making agent)"
      else
        warn "$name uses $model (expected opus for decision-making agent)"
      fi
      ;;
    implementor)
      if is_sonnet "$model"; then
        pass "$name uses sonnet (correct for implementor)"
      else
        warn "$name uses $model (expected sonnet for implementor)"
      fi
      ;;
  esac
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

# Derive real counts from the directories (single source of truth).
agent_count=$(find "$PLUGIN_ROOT/agents" -name "*.md" | wc -l | tr -d ' ')
skill_count=$(find "$PLUGIN_ROOT/skills" -name "SKILL.md" | wc -l | tr -d ' ')
protocol_count=$(find "$PLUGIN_ROOT/protocols" -name "*.md" ! -name "README.md" | wc -l | tr -d ' ')
check_count=$(find "$PLUGIN_ROOT/checks" -name "*.sh" ! -name "lib.sh" | wc -l | tr -d ' ')
template_count=$(find "$PLUGIN_ROOT/templates" -name "*.template.md" | wc -l | tr -d ' ')
mcp_count=$(jq -r '(.mcpServers // {}) | length' "$PLUGIN_ROOT/.mcp.json" 2>/dev/null || echo "?")
dim "  Agents:      $agent_count"
dim "  Skills:      $skill_count"
dim "  Protocols:   $protocol_count"
dim "  Checks:      $check_count"
dim "  Templates:   $template_count"
dim "  MCP servers: $mcp_count"

# --sync: rewrite every mirror from the counts above, then fall through to the
# verification below (which now passes). Without --sync we only verify + report.
if [ "$SYNC" -eq 1 ]; then
  sync_counts "$PLUGIN_ROOT" "$agent_count" "$skill_count" "$protocol_count" \
              "$check_count" "$template_count" "$mcp_count"
  pass "synced inventory counts into AGENTS.md, plugin.json, marketplace.json, ARCHITECTURE.md, docs/README.md"
fi

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
