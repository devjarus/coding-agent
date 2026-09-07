#!/usr/bin/env bash
# design-review — start/stop the local design-review surface for a feature.
#
# The surface renders ledger.md / design.html from the feature dir in
# a browser with inline commenting, and writes the user's output back to the
# feature dir as design-comments.json + design-verdict.json (sha-bound; see
# design-review-server.py). The conductor reads those files after the user
# returns to the chat — comments route to the planner, and an approved verdict
# clears the `designed?` gate.
#
# Usage:
#   design-review.sh start <feature_dir> [--port N] [--round N]   # background + opens browser
#   design-review.sh stop  <feature_dir>
#   design-review.sh status <feature_dir>
#   design-review.sh verify <feature_dir>   # exit 0 iff an approved, sha-current verdict exists
#
# `verify` is the machine-checkable gate: it exits 0 only when the user has
# approved on the surface (design-verdict.json verdict=approved) AND the
# artifacts are byte-identical to what was approved. The designer records it
# via record.sh so `designed?` reads real evidence, not a prose claim.
#
# State: <feature_dir>/design-review.pid while running.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

CMD="${1:-}"
DIR="${2:-}"
[[ -z "$CMD" || -z "$DIR" ]] && { echo '{"ok":false,"error":"usage: design-review.sh start|stop|status|verify <feature_dir> [--port N] [--round N]"}'; exit 1; }
[[ -d "$DIR" ]] || { echo "{\"ok\":false,\"error\":\"feature dir not found: $DIR\"}"; exit 1; }
shift 2

PORT=7341
ROUND=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)  PORT="${2:-7341}"; shift 2 ;;
    --round) ROUND="${2:-1}"; shift 2 ;;
    *) shift ;;
  esac
done

PIDFILE="$DIR/design-review.pid"

is_running() {
  [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null
}

case "$CMD" in
  start)
    command -v python3 >/dev/null 2>&1 || { echo '{"ok":false,"error":"python3 not found — design review needs the stdlib http server"}'; exit 1; }
    [[ -f "$DIR/ledger.md" || -f "$DIR/design.html" ]] \
      || { echo "{\"ok\":false,\"error\":\"nothing to review in $DIR (no ledger.md / design.html)\"}"; exit 1; }
    if is_running; then
      echo "{\"ok\":true,\"already_running\":true,\"url\":\"http://127.0.0.1:$PORT\"}"
      exit 0
    fi
    # archive the previous round's comments so each round's record survives
    if [[ -f "$DIR/design-comments.json" ]]; then
      prev=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('round',0))" "$DIR/design-comments.json" 2>/dev/null || echo 0)
      [[ "$prev" =~ ^[0-9]+$ && "$prev" -gt 0 && "$prev" -lt "$ROUND" ]] && mv "$DIR/design-comments.json" "$DIR/design-comments.round-$prev.json"
    fi
    nohup python3 "$SCRIPT_DIR/design-review-server.py" "$DIR" \
      --port "$PORT" --round "$ROUND" --app "$SCRIPT_DIR/design-review.html" \
      >"$DIR/design-review.log" 2>&1 &
    echo $! > "$PIDFILE"
    sleep 0.4
    if ! is_running; then
      rm -f "$PIDFILE"
      echo "{\"ok\":false,\"error\":\"server failed to start — see $DIR/design-review.log (port $PORT in use?)\"}"
      exit 1
    fi
    URL="http://127.0.0.1:$PORT"
    if command -v open >/dev/null 2>&1; then open "$URL"
    elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL" >/dev/null 2>&1
    fi
    echo "{\"ok\":true,\"url\":\"$URL\",\"pid\":$(cat "$PIDFILE"),\"round\":$ROUND}"
    ;;
  stop)
    if is_running; then
      kill "$(cat "$PIDFILE")" 2>/dev/null
      rm -f "$PIDFILE"
      echo '{"ok":true,"stopped":true}'
    else
      rm -f "$PIDFILE"
      echo '{"ok":true,"stopped":false,"note":"was not running"}'
    fi
    ;;
  status)
    if is_running; then
      echo "{\"ok\":true,\"running\":true,\"pid\":$(cat "$PIDFILE")}"
    else
      echo '{"ok":true,"running":false}'
    fi
    ;;
  verify)
    vfile="$DIR/design-verdict.json"
    [[ -f "$vfile" ]] || { echo "{\"ok\":false,\"error\":\"no design-verdict.json in $DIR — drive the surface to approval\"}"; exit 1; }
    verdict=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('verdict',''))" "$vfile" 2>/dev/null || echo "")
    if [[ "$verdict" != "approved" ]]; then
      echo "{\"ok\":false,\"error\":\"verdict is '$verdict', not approved\"}"; exit 1
    fi
    # sha-binding: a present verdict is strict. Missing helper/parser/hash data
    # fails closed; every reviewed artifact must match the approved bytes.
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/../gates/lib.sh" 2>/dev/null \
      || { echo '{"ok":false,"error":"strict verdict verifier unavailable"}'; exit 1; }
    declare -f verify_design_verdict >/dev/null 2>&1 \
      || { echo '{"ok":false,"error":"strict verdict verifier missing"}'; exit 1; }
    found=0
    for pair in "design.html:design_sha" "ledger.md:ledger_sha"; do
      art="${pair%:*}"; key="${pair##*:}"
      [[ -f "$DIR/$art" ]] || continue
      found=1
      reason="$(verify_design_verdict "$DIR" "$art" "$key")"
      if [[ -n "$reason" ]]; then
        echo "{\"ok\":false,\"error\":\"$reason\"}"; exit 1
      fi
    done
    [[ "$found" -eq 1 ]] || { echo '{"ok":false,"error":"no reviewed artifacts remain"}'; exit 1; }
    echo '{"ok":true,"approved":true}'
    ;;
  *)
    echo "{\"ok\":false,\"error\":\"unknown command: $CMD\"}"
    exit 1
    ;;
esac
