#!/usr/bin/env bash
# Seed the JSON store the feature must migrate.
set -uo pipefail
cat > data.json <<'J'
[{"id": 1, "note": "first"}, {"id": 2, "note": "second"}]
J
git add -A && git commit -qm "seed json store"
