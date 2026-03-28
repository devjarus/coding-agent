#!/bin/bash
# Install recommended external skills from the skills.sh ecosystem
# These complement the coding-agent plugin with domain expertise
# Run once per machine: ./scripts/setup-external-skills.sh

set -euo pipefail

green() { printf "\033[0;32m%s\033[0m\n" "$1"; }
dim() { printf "\033[0;90m%s\033[0m\n" "$1"; }
bold() { printf "\033[1m%s\033[0m\n" "$1"; }

echo ""
bold "═══════════════════════════════════════════"
bold "  coding-agent: External Skills Setup"
bold "═══════════════════════════════════════════"
echo ""

# ─── Vercel React & Web Skills ──────────────────────────────────────
bold "▸ Vercel React & Web Skills"
dim "  React best practices, composition patterns, web design guidelines, deployment"
npx skills add vercel-labs/agent-skills --all -g -y -a claude-code 2>&1 | tail -3
green "  ✔ Vercel skills installed"
echo ""

# ─── shadcn/ui ──────────────────────────────────────────────────────
bold "▸ shadcn/ui"
dim "  Component library management, theming, composition"
npx skills add shadcn/ui -g -y -a claude-code 2>&1 | tail -3
green "  ✔ shadcn/ui skill installed"
echo ""

# ─── Vercel Emulate ─────────────────────────────────────────────────
bold "▸ Vercel Emulate"
dim "  Local API emulators for GitHub, Vercel, Google, AWS"
npx skills add vercel-labs/emulate -g -y -a claude-code 2>&1 | tail -3
green "  ✔ Emulate skills installed"
echo ""

# ─── Anthropic Official Skills ──────────────────────────────────────
bold "▸ Anthropic Official Skills"
dim "  Claude API, MCP builder, webapp testing, frontend design"
npx skills add anthropics/skills -g -y -a claude-code 2>&1 | tail -3
green "  ✔ Anthropic skills installed"
echo ""

# ─── Summary ────────────────────────────────────────────────────────
bold "═══════════════════════════════════════════"
green "  All external skills installed!"
echo ""
dim "  Installed to: ~/.claude/skills/"
dim "  These skills are available alongside the coding-agent plugin."
dim "  Agents will automatically use them based on context."
echo ""
dim "  To verify: ask Claude 'What skills are available?'"
bold "═══════════════════════════════════════════"
echo ""
