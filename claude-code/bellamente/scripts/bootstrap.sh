#!/usr/bin/env bash
# Bellamente bootstrap for Claude Code and general agents:
# check platform, download, verify sha256, make executable, doctor, start.
# Run once on a fresh machine. There is no host supervisor, so this script
# also starts the local server via bella.sh.
# Usage: bash bootstrap.sh [version]
set -euo pipefail

VERSION="${1:-v0.1.0}"
DEST_DIR="${BELLA_HOME:-$HOME/.bellamente}"
BINARY="$DEST_DIR/bella-linux-x64"
EXPECTED_SHA="d618b1819412d1269405e3bb99f4a2951cc6cbf936f2adb24cb72b58f8e9b58d"
URL="https://github.com/The-Little-AI-Company/bellamente/releases/download/${VERSION}/bella-linux-x64"
HERE="$(cd "$(dirname "$0")" && pwd)"

OS="$(uname -s)"; ARCH="$(uname -m)"
if [ "$OS" != "Linux" ] || { [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "amd64" ]; }; then
  cat <<EOF
UNSUPPORTED_PLATFORM: this release ships a linux-x86_64 binary only (detected $OS/$ARCH).
Check https://github.com/The-Little-AI-Company/bellamente/releases for a build for your
platform, or run Bellamente in a linux-x86_64 container and point Claude Code at it.
EOF
  exit 3
fi

mkdir -p "$DEST_DIR/logs"

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

echo "Starting the local server..."
bash "$HERE/bella.sh" start

cat <<EOF

NEXT_STEP (agent action): confirm health, then finish install.
  1. bash "$HERE/bella.sh" health   should return {"ok":true,...}
  2. Optionally run the feature check: python3 "$HERE/test-matrix.py"
  3. Edit this skill's SKILL.md and DELETE the "## Bootstrap" block (keep steady-state).
Note: there is no host supervisor. The server does not survive a machine reboot on its own.
The skill's session-start step runs 'bella.sh start' to recover it. For always-on, see references/proxy-setup.md.
EOF
