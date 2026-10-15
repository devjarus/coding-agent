#!/usr/bin/env bash
# Validate the published plugin shape and its load-bearing runtime contracts.
set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
errors=0
warnings=0

pass() { printf '  ✓ %s\n' "$1"; }
warn() { printf '  ! %s\n' "$1"; warnings=$((warnings + 1)); }
error() { printf '  ✗ %s\n' "$1"; errors=$((errors + 1)); }

frontmatter() { sed -n '1,/^---$/p' "$1" | sed '1d;$d'; }

echo "coding-agent validator"

echo "▸ required structure"
required_files="
.claude-plugin/plugin.json
.codex-plugin/plugin.json
.agents/plugins/marketplace.json
.claude-plugin/marketplace.json
.mcp.json
settings.json
hooks/hooks.json
principles.md
README.md
ARCHITECTURE.md
AGENTS.md
CONTRIBUTING.md
CHANGELOG.md
"
for rel in $required_files; do
  [ -f "$PLUGIN_ROOT/$rel" ] || error "missing $rel"
done
for rel in agents gates hooks lib skills templates scripts evals docs/concepts; do
  [ -d "$PLUGIN_ROOT/$rel" ] || error "missing directory: $rel/"
done
for retired in v5 protocols checks; do
  [ ! -e "$PLUGIN_ROOT/$retired" ] || error "retired runtime path still exists: $retired/"
done
[ "$errors" -eq 0 ] && pass "canonical root layout present; retired runtime absent"

echo "▸ JSON + manifests"
json_ok=1
for rel in .claude-plugin/plugin.json .codex-plugin/plugin.json .agents/plugins/marketplace.json .claude-plugin/marketplace.json .mcp.json settings.json hooks/hooks.json skills/freshness.json; do
  python3 -m json.tool "$PLUGIN_ROOT/$rel" >/dev/null 2>&1 \
    || { error "$rel is not valid JSON"; json_ok=0; }
done
[ "$json_ok" -eq 1 ] && pass "JSON files parse"

claude_version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || true)"
codex_version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"].split("+")[0])' "$PLUGIN_ROOT/.codex-plugin/plugin.json" 2>/dev/null || true)"
[ -n "$claude_version" ] && [ "$claude_version" = "$codex_version" ] \
  && pass "Claude/Codex semantic versions agree ($claude_version)" \
  || error "manifest version mismatch: Claude=$claude_version Codex=$codex_version"

manifest_ok=1
for role in conductor planner developer diagnostician designer deployer; do
  python3 - "$PLUGIN_ROOT/.claude-plugin/plugin.json" "./agents/$role.md" <<'PY' >/dev/null 2>&1 || manifest_ok=0
import json,sys
raise SystemExit(0 if sys.argv[2] in json.load(open(sys.argv[1]))["agents"] else 1)
PY
done
manifest_count="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["agents"]))' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo 0)"
[ "$manifest_ok" -eq 1 ] && [ "$manifest_count" -eq 6 ] \
  && pass "Claude manifest registers only the six canonical roles" \
  || error "Claude manifest agent list is not the canonical six-role set"

python3 - "$PLUGIN_ROOT/.claude-plugin/plugin.json" <<'PY' >/dev/null 2>&1 || error "Claude manifest must register only ./hooks/hooks.json"
import json,sys
raise SystemExit(0 if json.load(open(sys.argv[1])).get("hooks") == ["./hooks/hooks.json"] else 1)
PY
python3 - "$PLUGIN_ROOT/settings.json" <<'PY' >/dev/null 2>&1 || error "settings.json must select coding-agent:conductor"
import json,sys
raise SystemExit(0 if json.load(open(sys.argv[1])).get("agent") == "coding-agent:conductor" else 1)
PY

agent_count="$(find "$PLUGIN_ROOT/agents" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
skill_count="$(find "$PLUGIN_ROOT/skills" -name SKILL.md | wc -l | tr -d ' ')"
gate_count="$(find "$PLUGIN_ROOT/gates" -maxdepth 1 -name '*.sh' ! -name lib.sh | wc -l | tr -d ' ')"
template_count="$(find "$PLUGIN_ROOT/templates" -maxdepth 1 -type f | wc -l | tr -d ' ')"
mcp_count="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["mcpServers"]))' "$PLUGIN_ROOT/.mcp.json" 2>/dev/null || echo 0)"
printf '  inventory: %s agents · %s skills · %s gates · %s templates · %s MCP servers\n' \
  "$agent_count" "$skill_count" "$gate_count" "$template_count" "$mcp_count"
[ "$agent_count" -eq 6 ] || error "expected 6 agents, found $agent_count"
[ "$skill_count" -eq 60 ] || error "expected 60 skills, found $skill_count"
[ "$gate_count" -eq 8 ] || error "expected 8 gates, found $gate_count"
[ "$template_count" -eq 12 ] || error "expected 12 templates, found $template_count"
[ "$mcp_count" -eq 5 ] || error "expected 5 MCP servers, found $mcp_count"

echo "▸ agent prompts"
agent_ok=1
for file in "$PLUGIN_ROOT"/agents/*.md; do
  rel="${file#$PLUGIN_ROOT/}"
  [ "$(head -1 "$file")" = "---" ] || { error "$rel has no frontmatter"; agent_ok=0; continue; }
  fm="$(awk 'NR==1{next} /^---$/{exit} {print}' "$file")"
  for key in name description model effort tools; do
    echo "$fm" | grep -qE "^$key:" || { error "$rel missing frontmatter '$key'"; agent_ok=0; }
  done
  base="$(basename "$file" .md)"
  name="$(echo "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1)"
  [ "$name" = "$base" ] || { error "$rel declares name '$name'"; agent_ok=0; }
  model="$(echo "$fm" | sed -n 's/^model:[[:space:]]*//p' | head -1)"
  echo "$model" | grep -qE '^(opus|sonnet|haiku|inherit|claude-(opus|sonnet|haiku)-[0-9]+)' \
    || { error "$rel has unsupported model '$model'"; agent_ok=0; }
  effort="$(echo "$fm" | sed -n 's/^effort:[[:space:]]*//p' | head -1)"
  echo "$effort" | grep -qE '^(low|medium|high|xhigh|max)$' \
    || { error "$rel has unsupported effort '$effort'"; agent_ok=0; }
  lines="$(wc -l < "$file" | tr -d ' ')"; limit=300
  [ "$base" = conductor ] && limit=350
  [ "$lines" -le "$limit" ] || { error "$rel is $lines lines (limit $limit)"; agent_ok=0; }
done
[ "$agent_ok" -eq 1 ] && pass "agent frontmatter, names, models, effort, and size valid"

echo "▸ skills"
skill_ok=1
names_file="$(mktemp)"
while IFS= read -r file; do
  rel="${file#$PLUGIN_ROOT/}"
  [ "$(head -1 "$file")" = "---" ] || { error "$rel has no frontmatter"; skill_ok=0; continue; }
  fm="$(awk 'NR==1{next} /^---$/{exit} {print}' "$file")"
  name="$(echo "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1)"
  desc="$(echo "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -1)"
  [ -n "$name" ] || { error "$rel missing name"; skill_ok=0; }
  [ -n "$desc" ] || { error "$rel missing description"; skill_ok=0; }
  [ "${#desc}" -le 250 ] || { error "$rel description exceeds 250 characters"; skill_ok=0; }
  lines="$(wc -l < "$file" | tr -d ' ')"
  [ "$lines" -le 500 ] || { error "$rel is $lines lines (limit 500)"; skill_ok=0; }
  printf '%s\n' "$name" >> "$names_file"
done < <(find "$PLUGIN_ROOT/skills" -name SKILL.md | sort)
dupes="$(sort "$names_file" | uniq -d)"
[ -z "$dupes" ] || { error "duplicate skill names: $(echo "$dupes" | tr '\n' ' ')"; skill_ok=0; }
rm "$names_file"
[ "$skill_ok" -eq 1 ] && pass "skill frontmatter, descriptions, uniqueness, and size valid"

echo "▸ shell + runtime paths"
shell_ok=1
while IFS= read -r file; do
  rel="${file#$PLUGIN_ROOT/}"
  [ -x "$file" ] || { error "$rel is not executable"; shell_ok=0; }
  bash -n "$file" 2>/dev/null || { error "$rel has a Bash syntax error"; shell_ok=0; }
done < <(find "$PLUGIN_ROOT/gates" "$PLUGIN_ROOT/lib" "$PLUGIN_ROOT/hooks" \
  "$PLUGIN_ROOT/scripts" "$PLUGIN_ROOT/evals" "$PLUGIN_ROOT/bench" \
  -path "$PLUGIN_ROOT/evals/results" -prune -o -name '*.sh' -print | sort)
[ "$shell_ok" -eq 1 ] && pass "shell scripts executable and syntax-clean"

path_ok=1
while IFS= read -r ref; do
  rel="${ref#\$\{CLAUDE_PLUGIN_ROOT\}/}"
  [ -e "$PLUGIN_ROOT/$rel" ] || { error "missing plugin path referenced as $ref"; path_ok=0; }
done < <(grep -rhoE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9_./-]+' \
  "$PLUGIN_ROOT/agents" "$PLUGIN_ROOT/hooks" "$PLUGIN_ROOT/lib" \
  "$PLUGIN_ROOT/skills" "$PLUGIN_ROOT/scripts" "$PLUGIN_ROOT/docs" 2>/dev/null | sort -u)
[ "$path_ok" -eq 1 ] && pass "literal plugin-root references resolve"

echo "▸ gates + evidence contracts"
gate_ok=1
for file in "$PLUGIN_ROOT"/gates/*.sh; do
  [ "$(basename "$file")" = lib.sh ] && continue
  rel="${file#$PLUGIN_ROOT/}"
  grep -q 'gates/lib.sh\|/lib.sh"' "$file" || { error "$rel does not source the gate library"; gate_ok=0; }
  grep -q '^GATE_NAME=' "$file" || { error "$rel has no GATE_NAME"; gate_ok=0; }
  grep -q 'gate_result' "$file" || { error "$rel never emits a gate result"; gate_ok=0; }
done
grep -q 'declared_test_command' "$PLUGIN_ROOT/lib/record.sh" || { error "record.sh does not bind test commands"; gate_ok=0; }
grep -q 'lockdir="${ev}.lock"' "$PLUGIN_ROOT/lib/record.sh" || { error "record.sh has no append lock"; gate_ok=0; }
grep -q 'delivery plan is empty' "$PLUGIN_ROOT/gates/framed.sh" || { error "framed? does not require a delivery plan"; gate_ok=0; }
grep -q 'comments_open' "$PLUGIN_ROOT/gates/lib.sh" || { error "design verdict validation does not require zero open comments"; gate_ok=0; }
grep -q 'verify_design_verdict' "$PLUGIN_ROOT/gates/designed.sh" || { error "designed? does not re-verify the human verdict"; gate_ok=0; }
grep -q 'coding-agent/' "$PLUGIN_ROOT/gates/clean.sh" || { error "clean? does not block staged coordinator state"; gate_ok=0; }
grep -q 'ca_install_commit_gate' "$PLUGIN_ROOT/lib/ledger.sh" || { error "ledger.sh init does not install the pre-commit gate"; gate_ok=0; }
[ -x "$PLUGIN_ROOT/hooks/pre-commit.sh" ] || { error "hooks/pre-commit.sh missing or not executable"; gate_ok=0; }
grep -q 'git add -- <explicit changed_paths' "$PLUGIN_ROOT/agents/conductor.md" || { error "conductor lacks explicit attributable staging"; gate_ok=0; }
grep -q 'aggregate: false' "$PLUGIN_ROOT/agents/conductor.md" || { error "parallel review isolation contract missing"; gate_ok=0; }
if grep -qE 'browser_(click|evaluate|fill_form)' "$PLUGIN_ROOT/agents/designer.md"; then
  error "designer exposes approval-capable browser tools"; gate_ok=0
fi
[ "$gate_ok" -eq 1 ] && pass "gate, evidence, design, and shared-workspace invariants present"

echo "▸ principles + referenced skills"
principle_ok=1
for anchor in operating frame architect build prove diagnose review design ship; do
  grep -qE "^## $anchor([[:space:]]|$)" "$PLUGIN_ROOT/principles.md" \
    || { error "principles.md missing '$anchor' tier"; principle_ok=0; }
done
[ "$principle_ok" -eq 1 ] && pass "principle tier exists for every dispatch kind"

agent_skill_ok=1
while IFS= read -r name; do
  [ -z "$name" ] && continue
  find "$PLUGIN_ROOT/skills" -name SKILL.md -exec grep -qE "^name:[[:space:]]*$name$" {} \; -print | grep -q . \
    || { error "agent preloads missing skill '$name'"; agent_skill_ok=0; }
done < <(awk '/^skills:/{s=1;next} s&&/^  - /{sub(/^  - /,"");print;next} s{exit}' "$PLUGIN_ROOT"/agents/*.md)
[ "$agent_skill_ok" -eq 1 ] && pass "preloaded agent skills exist"

echo "▸ documentation + retired terminology"
docs_ok=1
python3 - "$PLUGIN_ROOT" <<'PY' || docs_ok=0
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
files = [root / n for n in ("README.md", "ARCHITECTURE.md", "AGENTS.md", "CONTRIBUTING.md")]
files += sorted((root / "docs").rglob("*.md"))
bad = []
for path in files:
    text = path.read_text(encoding="utf-8")
    for target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", text):
        if target.startswith(("http://", "https://", "#")) or "<" in target:
            continue
        dest = target.split("#", 1)[0]
        if dest and not (path.parent / dest).resolve().exists():
            bad.append(f"{path.relative_to(root)} -> {target}")
if bad:
    print("broken relative Markdown links:", file=sys.stderr)
    for item in bad:
        print("  " + item, file=sys.stderr)
    raise SystemExit(1)
PY
[ "$docs_ok" -eq 1 ] || error "canonical docs contain broken relative links"

if rg -n 'coding-agent v[45]|\bv[45] runtime\b|/v5/|`v5/|protocols/|checks/' \
  "$PLUGIN_ROOT/README.md" "$PLUGIN_ROOT/ARCHITECTURE.md" "$PLUGIN_ROOT/AGENTS.md" \
  "$PLUGIN_ROOT/CONTRIBUTING.md" "$PLUGIN_ROOT/docs" >/dev/null 2>&1; then
  error "canonical docs still reference a retired runtime or path"; docs_ok=0
fi
[ "$docs_ok" -eq 1 ] && pass "canonical docs link cleanly and present only the current runtime"

echo "▸ source hygiene"
stale_ok=1
if rg -n '\$\{CLAUDE_PLUGIN_ROOT\}/v5/|\$EV_PLUGIN_ROOT/v5/|\{\{PLUGIN_ROOT\}\}/v5/' \
  "$PLUGIN_ROOT/agents" "$PLUGIN_ROOT/gates" "$PLUGIN_ROOT/hooks" "$PLUGIN_ROOT/lib" \
  "$PLUGIN_ROOT/skills" "$PLUGIN_ROOT/evals" "$PLUGIN_ROOT/scripts" -g '!validate.sh' >/dev/null 2>&1; then
  error "source contains a retired /v5/ runtime path"; stale_ok=0
fi
if rg -n '\$\{CLAUDE_PLUGIN_ROOT\}/(protocols|checks)/' \
  "$PLUGIN_ROOT/agents" "$PLUGIN_ROOT/gates" "$PLUGIN_ROOT/hooks" "$PLUGIN_ROOT/lib" \
  "$PLUGIN_ROOT/skills" "$PLUGIN_ROOT/evals" "$PLUGIN_ROOT/scripts" -g '!validate.sh' >/dev/null 2>&1; then
  error "source references retired protocols/ or checks/ paths"; stale_ok=0
fi
[ "$stale_ok" -eq 1 ] && pass "no retired runtime path remains in executable sources"

echo "▸ design surface + skill freshness"
python3 -m py_compile "$PLUGIN_ROOT/scripts/design-review-server.py" 2>/dev/null \
  && pass "design-review server compiles" \
  || error "design-review server does not compile"
if "$PLUGIN_ROOT/scripts/validate-skill-freshness.sh" >/dev/null; then
  pass "version-sensitive skill guidance is current"
else
  error "version-sensitive skill guidance is stale"
fi

echo
if [ "$errors" -eq 0 ]; then
  printf 'PASSED (%s warning%s)\n' "$warnings" "$([ "$warnings" -eq 1 ] && echo '' || echo 's')"
  exit 0
fi
printf 'FAILED (%s error%s, %s warning%s)\n' "$errors" "$([ "$errors" -eq 1 ] && echo '' || echo 's')" "$warnings" "$([ "$warnings" -eq 1 ] && echo '' || echo 's')"
exit 1
