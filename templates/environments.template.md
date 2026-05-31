---
artifact: environments
feature: global
writer: orchestrator
mutability: per-section-mutable    # each H2 env block is overwritten in place; no append log
state: active
---

# Environments

<!--
One H2 section per environment (production, staging, preview, etc).
Project declares HOW to deploy / verify / list env vars; the plugin runs whatever's declared.
No platform adapters in the plugin — the indirection lives here.

Required fields per env:
  platform              human-readable, free-form (railway, fly, vercel, ecs, ssh, ...)
  commit_running        last commit deployed; updated after each successful deploy
  last_verified         ISO timestamp of last successful verify
  expected_env_vars     YAML list of required env-var NAMES (not values)
  deploy_command        shell command run from project root
  env_list_command      shell command that prints set vars to stdout (one per line, NAME=VALUE or NAME)
  verify_urls           YAML list of URLs that must return 2xx after deploy
  pre_smoke_command     OPTIONAL — runs before deploy_command; abort if non-zero
-->

## production
- platform: <e.g. railway>
- commit_running: <git sha or "none">
- last_verified: <ISO timestamp or "never">
- expected_env_vars:
  - DATABASE_URL
  - PUBLIC_WEB_BASE_URL
  - JWT_SECRET
- deploy_command: <e.g. railway up --service api>
- env_list_command: <e.g. railway variables --service api --json | jq -r 'keys[]'>
- verify_urls:
  - https://app.example.com/api/health
- pre_smoke_command: <optional, e.g. npm run smoke:prod>
