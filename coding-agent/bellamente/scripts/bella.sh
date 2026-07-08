#!/usr/bin/env bash
# Bellamente daily-driver CLI for any coding agent (Codex, Claude Code, Cursor, ...).
# Wraps the localhost HTTP API so an agent calls one script instead of
# re-deriving curl shapes every session, and manages the local server
# lifecycle (start/stop/restart) since there is no host supervisor.
# Base URL: http://127.0.0.1:8080 (loopback, no auth on localhost)
set -euo pipefail
BASE="${BELLA_BASE:-http://127.0.0.1:8080}"
JQ="python3 -m json.tool"
TAG="${BELLA_TAG:-default}"
DIR="${BELLA_HOME:-$HOME/.bellamente}"
BIN="$DIR/bella-linux-x64"
KEYFILE="$DIR/.upstream-key"
URLFILE="$DIR/.upstream-url"
MODELFILE="$DIR/.upstream-model"
LOG="$DIR/logs/bella.log"

usage() { cat <<EOF
bella.sh <cmd> [args]
  start                           start the local server if it is not already up
  stop                            stop the local server
  restart                         stop then start (use after proxy enable/disable)
  health                          service health
  recall "<q>" [limit]            semantic+fulltext memory search (default limit 5)
  asof  "<q>" "<iso>" [limit]     what was believed then (ISO8601 w/ tz, or YYYY-MM-DD)
  remember "<content>" [tag] [dynamic]   write one memory (static by default; "dynamic" flips it)
  supersede "<id>" "<content>"    content-edit a memory -> new version (chain kept)
  forget "<id>"                   soft-forget a chain
  unforgot "<id>"                 reverse soft-forget
  chain "<id>"                    full version chain (forgotten versions included)
  list [tag]                      latest non-forgotten memories
  inspect [traceId]               recent traces, or one trace receipt
  profile                         get profile (static+dynamic facts)
  export [tag]                    full portable export (no embeddings)
  proxy status                    show base vs proxy mode + configured upstream
  proxy enable <deepseek|openrouter|custom>   stage upstream key+url from env (opt-in)
  proxy disable                   remove upstream config, return to base memory mode
EOF
}

json() { python3 -c "import json,sys;print(json.dumps(sys.argv[1]))" "$1"; }

start_server() {
  if curl -sf "$BASE/health" >/dev/null 2>&1; then
    echo "ALREADY_UP: $BASE"; return 0
  fi
  if [ ! -x "$BIN" ]; then
    echo "NO_BINARY: $BIN not found. Run bootstrap.sh first."; return 1
  fi
  mkdir -p "$DIR/logs"
  if [ -s "$KEYFILE" ]; then
    export BELLA_UPSTREAM_API_KEY; BELLA_UPSTREAM_API_KEY="$(cat "$KEYFILE")"
    export BELLA_UPSTREAM_BASE_URL; BELLA_UPSTREAM_BASE_URL="$(cat "$URLFILE" 2>/dev/null || true)"
    if [ -s "$MODELFILE" ]; then export BELLA_UPSTREAM_MODEL; BELLA_UPSTREAM_MODEL="$(cat "$MODELFILE")"; fi
  fi
  if command -v setsid >/dev/null 2>&1; then
    ( cd "$DIR" && setsid "$BIN" >"$LOG" 2>&1 </dev/null & )
  else
    ( cd "$DIR" && nohup "$BIN" >"$LOG" 2>&1 </dev/null & )
  fi
  for _ in $(seq 1 60); do
    if curl -sf "$BASE/health" >/dev/null 2>&1; then echo "UP: $BASE"; return 0; fi
    sleep 0.5
  done
  echo "TIMEOUT: server did not report healthy. Check $LOG"; return 1
}

cmd="${1:-}"; shift || true
case "$cmd" in
  start) start_server ;;
  stop)
    if pkill -f "$BIN" 2>/dev/null; then echo "STOPPED"; else echo "NOT_RUNNING"; fi ;;
  restart)
    pkill -f "$BIN" 2>/dev/null || true; sleep 1; start_server ;;
  health) curl -sf "$BASE/health" | $JQ ;;
  recall)
    q="${1:?need query}"; n="${2:-5}"
    curl -sf "$BASE/search" -H 'content-type: application/json' \
      -d "{\"q\":$(json "$q"),\"searchMode\":\"memories\",\"limit\":$n}" | $JQ ;;
  asof)
    q="${1:?need query}"; iso="${2:?need ISO instant}"; n="${3:-5}"
    curl -sf "$BASE/search" -H 'content-type: application/json' \
      -d "{\"q\":$(json "$q"),\"searchMode\":\"memories\",\"limit\":$n,\"asOf\":\"$iso\"}" | $JQ ;;
  remember)
    c="${1:?need content}"; t="${2:-$TAG}"
    if [ "${3:-}" = "dynamic" ]; then static=false; else static=true; fi
    curl -sf "$BASE/memories" -H 'content-type: application/json' \
      -d "{\"containerTag\":\"$t\",\"memories\":[{\"content\":$(json "$c"),\"isStatic\":$static}]}" | $JQ ;;
  supersede)
    id="${1:?need id}"; c="${2:?need new content}"
    curl -sf -X PATCH "$BASE/memories/$id" -H 'content-type: application/json' \
      -d "{\"content\":$(json "$c")}" | $JQ ;;
  forget)
    id="${1:?need id}"; curl -sf -X POST "$BASE/memories/$id/forget" -H 'content-type: application/json' -d '{}' | $JQ ;;
  unforgot)
    id="${1:?need id}"; curl -sf -X POST "$BASE/memories/$id/forget" -H 'content-type: application/json' -d '{"undo":true}' | $JQ ;;
  chain)
    id="${1:?need id}"; curl -sf "$BASE/memories/$id" | $JQ ;;
  list)
    t="${1:-}"
    url="$BASE/memories"; [ -n "$t" ] && url="$BASE/memories?containerTag=$t"
    curl -sf "$url" | $JQ ;;
  inspect)
    id="${1:-}"
    if [ -n "$id" ]; then curl -sf "$BASE/inspect/$id" | $JQ
    else curl -sf "$BASE/inspect" | $JQ; fi ;;
  profile) curl -sf "$BASE/profile" | $JQ ;;
  export) t="${1:-}"; url="$BASE/export"; [ -n "$t" ] && url="$BASE/export?containerTag=$t"; curl -sf "$url" | $JQ ;;
  proxy)
    sub="${1:-status}"; shift || true
    case "$sub" in
      status)
        if [ -s "$KEYFILE" ]; then
          echo "MODE: proxy"
          echo "UPSTREAM_URL: $(cat "$URLFILE" 2>/dev/null || echo '(unset)')"
          echo "UPSTREAM_MODEL: $(cat "$MODELFILE" 2>/dev/null || echo '(unset)')"
          echo "KEY: staged in $KEYFILE (owner-only, 600)"
        else
          echo "MODE: base (no upstream, proxy off)"
          echo "The memory API (/memories, /search, /inspect, /export) works without any key."
          echo "Run 'bella.sh proxy enable <provider>' to opt into proxy mode."
        fi ;;
      enable)
        prov="${1:?need provider: deepseek|openrouter|custom}"
        case "$prov" in
          deepseek)
            key="${DEEPSEEK_API_KEY:?DEEPSEEK_API_KEY is not set in this environment}"
            url="https://api.deepseek.com/v1"; model="deepseek-v4-flash" ;;
          openrouter)
            key="${OPENROUTER_API_KEY:?OPENROUTER_API_KEY is not set in this environment}"
            url="https://openrouter.ai/api/v1"; model="" ;;
          custom)
            key="${BELLA_UPSTREAM_API_KEY:?BELLA_UPSTREAM_API_KEY is not set}"
            url="${BELLA_UPSTREAM_BASE_URL:?BELLA_UPSTREAM_BASE_URL is not set}"
            model="${BELLA_UPSTREAM_MODEL:-}" ;;
          *) echo "unknown provider: $prov"; exit 1 ;;
        esac
        umask 077
        printf '%s' "$key" > "$KEYFILE"; chmod 600 "$KEYFILE"
        printf '%s' "$url" > "$URLFILE"
        if [ -n "$model" ]; then printf '%s' "$model" > "$MODELFILE"; else rm -f "$MODELFILE"; fi
        echo "STAGED: $prov upstream ($url)"
        echo "Key written to $KEYFILE (600, owner-only). This duplicates the source secret; see references/proxy-setup.md."
        echo ""
        echo "NEXT STEP: run 'bella.sh restart' so the server picks up proxy mode." ;;
      disable)
        rm -f "$KEYFILE" "$URLFILE" "$MODELFILE"
        echo "DISABLED: upstream config removed. Server runs in base memory mode after restart."
        echo ""
        echo "NEXT STEP: run 'bella.sh restart'." ;;
      *) echo "unknown proxy subcmd: $sub"; exit 1 ;;
    esac ;;
  ""|-h|--help) usage ;;
  *) echo "unknown cmd: $cmd"; usage; exit 1 ;;
esac
