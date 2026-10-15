#!/usr/bin/env bash
# clean? — the staged diff carries no coordinator state, no obvious secrets, and
# no leftover debugger statements. Applies when a commit is imminent.
#
# Prints are deliberately NOT blocked: `print(` / `console.log` / `fmt.Println`
# are how CLIs produce output, and a regex cannot tell them from debugging. On
# the bench that false positive forced a CLI rewrite and a whole extra review
# round. Stray prints are the reviewer's call; this gate blocks only statements
# that are never correct in a commit.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
GATE_NAME=clean
diff="$(git diff --cached 2>/dev/null || true)"
[ -n "$diff" ] || gate_result n/a "nothing staged"
# .coding-agent/ is gitignored, but `git add -f` or an explicit path still stages
# it. Tracked coordinator state is erased by the next `git reset --hard` /
# `git clean`, taking the ledger and evidence with it — never let it through.
staged_state="$(git diff --cached --name-only 2>/dev/null | grep -E '(^|/)\.coding-agent/' | head -3 | tr '\n' ' ')"
[ -z "$staged_state" ] \
  || gate_result block "coordinator state is staged (${staged_state% }) — git restore --staged .coding-agent"
# Secrets: high-confidence key formats anywhere, plus a secret-named key assigned
# a long string literal outside test files. The old "keyword followed by = or :"
# rule flagged `token = secrets.token_hex(24)` and every login handler; on the
# bench it fired on 3 of 4 complex runs and each false positive cost a rework.
leak="$(git diff --cached -U0 2>/dev/null | python3 -c '
import re, sys
strong = re.compile(r"AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|\bsk-[A-Za-z0-9_-]{20,}|\bgh[pousr]_[A-Za-z0-9]{30,}|\bxox[abpr]-[A-Za-z0-9-]{10,}")
named = re.compile(r"(?i)(api[_-]?key|secret|passw(or)?d|token|private[_-]?key)[\"\x27]?\s*[:=]\s*[\"\x27]([^\"\x27\s]{8,})[\"\x27]")
placeholder = re.compile(r"(?i)(example|changeme|placeholder|dummy|fake|test|xxx|<|\$\{|\{\{|your[_-])")
testfile = re.compile(r"(^|/)(tests?|spec|__tests__|fixtures?)/|(^|/)test_[^/]*$|_test\.[a-z]+$|\.(test|spec)\.[a-z]+$")
path = None
for line in sys.stdin:
    if line.startswith("+++ "):
        path = line[6:].strip() if line.startswith("+++ b/") else None
        continue
    if not line.startswith("+") or line.startswith("+++") or path is None:
        continue
    if strong.search(line):
        print(path); break
    m = named.search(line)
    if m and not testfile.search(path) and not placeholder.search(m.group(3)):
        print(path); break
')"
[ -z "$leak" ] || gate_result block "possible hardcoded secret in staged diff ($leak)"
if echo "$diff" | grep -Eq '^\+[[:space:]]*(debugger;?[[:space:]]*$|binding\.pry|byebug\b|import pdb|pdb\.set_trace\(|breakpoint\(\))'; then
  gate_result block "debugger statement in staged diff"
fi
gate_result pass "no coordinator state, secrets, or debugger statements staged"
