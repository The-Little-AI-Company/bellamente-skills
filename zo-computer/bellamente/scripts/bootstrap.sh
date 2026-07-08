#!/usr/bin/env bash
# Bellamente bootstrap: download, verify, make executable, doctor.
# Run once on a fresh Zo. Does NOT register the Zo service (that is an agent step).
# Usage: bash bootstrap.sh [version]
set -euo pipefail

VERSION="${1:-v0.1.0}"
DEST_DIR="${BELLA_HOME:-/home/workspace/Projects/bellamente}"
BINARY="$DEST_DIR/bella-linux-x64"
EXPECTED_SHA="d618b1819412d1269405e3bb99f4a2951cc6cbf936f2adb24cb72b58f8e9b58d"
URL="https://github.com/The-Little-AI-Company/bellamente/releases/download/${VERSION}/bella-linux-x64"

mkdir -p "$DEST_DIR/data" "$DEST_DIR/cache" "$DEST_DIR/logs"

if [ -x "$BINARY" ] && curl -sf http://127.0.0.1:8080/health >/dev/null 2>&1; then
  echo "ALREADY_UP: Bellamente is healthy at 127.0.0.1:8080"
  exit 0
fi

if [ ! -x "$BINARY" ]; then
  echo "Downloading bellamente ${VERSION}..."
  curl -fSL -o "$BINARY" "$URL"
fi

ACTUAL_SHA=$(sha256sum "$BINARY" | awk '{print $1}')
if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
  echo "SHA_MISMATCH: expected $EXPECTED_SHA got $ACTUAL_SHA"
  echo "If ${VERSION} was re-released, fetch the new sha from the GitHub release assets and update this script."
  rm -f "$BINARY"
  exit 2
fi

chmod +x "$BINARY"
echo "SHA_OK: checksum verified"
echo "Running doctor..."
timeout 60 "$BINARY" doctor 2>&1 | tail -20 || true

cat <<EOF

NEXT_STEP (agent action): register as a Zo process service so it auto-starts and survives restarts.
Call register_user_service with:
  label      = "Bellamente memory"
  mode       = "process"
  entrypoint = "$BINARY"
  workdir    = "$DEST_DIR"
  env_vars   = { PORT: "8080", XDG_DATA_HOME: "$DEST_DIR/data", XDG_CACHE_HOME: "$DEST_DIR/cache" }
Then poll http://127.0.0.1:8080/health until ok (first start caches the e5 model, ~5-15s).
Finally, edit this skill's SKILL.md to DELETE the "## Bootstrap" block (keep steady-state).
EOF
