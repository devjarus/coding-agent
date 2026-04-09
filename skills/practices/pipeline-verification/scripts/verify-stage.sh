#!/bin/bash
# verify-stage.sh — Deterministic checks the orchestrator runs before advancing the pipeline.
# Usage: ./scripts/verify-stage.sh <stage> [project-root]
#
# Stages:
#   spec     — validate spec.md has required sections
#   plan     — validate plan.md has required sections
#   build    — verify the project builds (auto-detects stack)
#   tests    — verify tests pass (auto-detects test runner)
#   review   — validate review.md has required sections
#
# Exit codes:
#   0 = PASS
#   1 = FAIL (with details on stderr)

set -uo pipefail

STAGE="${1:-}"
PROJECT_ROOT="${2:-.}"
CODING_AGENT="$PROJECT_ROOT/.coding-agent"

fail() { echo "FAIL: $1" >&2; exit 1; }
warn() { echo "WARN: $1" >&2; }
pass() { echo "PASS: $1"; exit 0; }

# ─── SPEC VALIDATION ─────────────────────────────────────────────
verify_spec() {
  local f="$CODING_AGENT/spec.md"
  [ -f "$f" ] || fail "spec.md does not exist"

  grep -qi "## overview\|## Overview" "$f" || fail "spec.md missing Overview section"
  grep -qiE "FR-[0-9]+" "$f" || fail "spec.md missing requirements (no FR-* found)"
  grep -qi "## non.goal\|## Non.Goal" "$f" || fail "spec.md missing Non-Goals section"
  grep -qi "## technical risk\|## Technical Risk" "$f" && true || warn "spec.md missing Technical Risks section (recommended)"

  pass "spec.md has Overview, Requirements, Non-Goals"
}

# ─── PLAN VALIDATION ─────────────────────────────────────────────
verify_plan() {
  local f="$CODING_AGENT/plan.md"
  [ -f "$f" ] || fail "plan.md does not exist"

  grep -qiE "T-[0-9]+|Task.?[0-9]+" "$f" || fail "plan.md missing task definitions (no T-* or Task-* found)"
  grep -qi "wave\|Wave" "$f" || fail "plan.md missing wave structure"
  grep -qi "evaluation.criter\|Evaluation.Criter" "$f" || fail "plan.md missing evaluation criteria"

  pass "plan.md has Tasks, Waves, Evaluation Criteria"
}

# ─── BUILD VERIFICATION ──────────────────────────────────────────
verify_build() {
  cd "$PROJECT_ROOT" || fail "Cannot cd to $PROJECT_ROOT"

  # Detect stack and build
  if [ -f "package.json" ]; then
    # Node.js project — check if it has workspaces or subdirs
    if [ -f "server/package.json" ] && [ -f "client/package.json" ]; then
      # Monorepo with server + client
      (cd server && npm install --silent 2>&1) || fail "server npm install failed"
      (cd client && npm install --silent 2>&1) || fail "client npm install failed"
      if grep -q '"build"' client/package.json; then
        (cd client && npm run build 2>&1) || fail "client build failed"
      fi
    else
      npm install --silent 2>&1 || fail "npm install failed"
      if grep -q '"build"' package.json; then
        npm run build 2>&1 || fail "npm run build failed"
      fi
    fi
    pass "Node.js project builds successfully"

  elif [ -f "*.xcodeproj/project.pbxproj" ] || [ -f "Package.swift" ]; then
    # iOS/Swift project
    if [ -f "Package.swift" ]; then
      swift build 2>&1 || fail "swift build failed"
    else
      SCHEME=$(xcodebuild -list 2>/dev/null | sed -n '/Schemes:/,/^$/p' | head -2 | tail -1 | xargs)
      xcodebuild -scheme "$SCHEME" -sdk iphonesimulator build 2>&1 | tail -5
      [ ${PIPESTATUS[0]} -eq 0 ] || fail "xcodebuild failed"
    fi
    pass "iOS project builds successfully"

  elif [ -f "go.mod" ]; then
    go build ./... 2>&1 || fail "go build failed"
    pass "Go project builds successfully"

  elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    python3 -m py_compile $(find . -name "*.py" -not -path "*/node_modules/*" -not -path "*/.venv/*" | head -20) 2>&1 || fail "Python syntax check failed"
    pass "Python files compile successfully"

  else
    warn "Unknown project type — skipping build verification"
    exit 0
  fi
}

# ─── TEST VERIFICATION ────────────────────────────────────────────
verify_tests() {
  cd "$PROJECT_ROOT" || fail "Cannot cd to $PROJECT_ROOT"

  local ran_tests=0

  # Node.js tests
  if [ -f "package.json" ]; then
    if [ -f "server/package.json" ]; then
      (cd server && npm test 2>&1) || fail "server tests failed"
      ran_tests=1
    fi
    if [ -f "client/package.json" ]; then
      (cd client && npm test -- --run 2>&1) || fail "client tests failed"
      ran_tests=1
    fi
    if [ $ran_tests -eq 0 ] && grep -q '"test"' package.json; then
      npm test 2>&1 || fail "tests failed"
      ran_tests=1
    fi
  fi

  # Swift tests
  if [ -f "Package.swift" ]; then
    swift test 2>&1 || fail "swift test failed"
    ran_tests=1
  fi

  # Go tests
  if [ -f "go.mod" ]; then
    go test ./... 2>&1 || fail "go test failed"
    ran_tests=1
  fi

  # Python tests
  if [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] || [ -d "tests" ]; then
    python3 -m pytest 2>&1 || fail "pytest failed"
    ran_tests=1
  fi

  if [ $ran_tests -eq 0 ]; then
    warn "No test runner detected — skipping test verification"
    exit 0
  fi

  pass "All tests passed"
}

# ─── REVIEW VALIDATION ────────────────────────────────────────────
verify_review() {
  local f="$CODING_AGENT/review.md"
  [ -f "$f" ] || fail "review.md does not exist"

  grep -qi "## status\|## Status" "$f" || fail "review.md missing Status section"
  grep -qiE "PASS|FAIL" "$f" || fail "review.md missing PASS/FAIL status"
  grep -qi "## findings\|## Findings" "$f" || fail "review.md missing Findings section"
  grep -qi "## build result\|## Build Result\|## test result\|## Test Result" "$f" || warn "review.md missing Build/Test Result section"
  grep -qi "## runtime\|## Runtime" "$f" || warn "review.md missing Runtime Verification section"

  pass "review.md has Status, Findings"
}

# ─── DISPATCH ─────────────────────────────────────────────────────
case "$STAGE" in
  spec)   verify_spec ;;
  plan)   verify_plan ;;
  build)  verify_build ;;
  tests)  verify_tests ;;
  review) verify_review ;;
  *)      fail "Unknown stage: $STAGE. Use: spec, plan, build, tests, review" ;;
esac
