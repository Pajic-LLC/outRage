#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <runtime-id>" >&2
  exit 2
fi

RUNTIME_ID="$1"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORK="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/outrage-runtime-smoke"
rm -rf "$WORK"
mkdir -p "$WORK"

CC="$(command -v x86_64-w64-mingw32-gcc || true)"
[[ -n "$CC" ]] || {
  echo "error: x86_64-w64-mingw32-gcc is required" >&2
  exit 1
}

"$CC" \
  -O2 \
  -s \
  -mwindows \
  "$REPO_ROOT/Tools/runtime/smoke/win32-smoke.c" \
  -o "$WORK/runtime-smoke.exe"

BASE="$(cd "$REPO_ROOT" && swift run -c release outrage paths | tail -n 1)"
TARGET_DIR="$BASE/Targets/runtime-smoke"
mkdir -p "$TARGET_DIR"
cp "$WORK/runtime-smoke.exe" "$TARGET_DIR/runtime-smoke.exe"

cat > "$WORK/profile.json" <<EOF
{
  "arguments": [],
  "bundleIdentifier": "com.pajic.outrage.runtime-smoke",
  "cpu": "rosetta",
  "displayName": "Runtime Smoke",
  "environment": {},
  "executable": "runtime-smoke.exe",
  "graphics": "dxmt",
  "id": "runtime-smoke",
  "launcher": "direct",
  "runtime": "compatibility",
  "runtimeIdentifier": "$RUNTIME_ID",
  "schemaVersion": 1
}
EOF

cd "$REPO_ROOT"
swift run -c release outrage validate "$WORK/profile.json"
swift run -c release outrage prepare "$WORK/profile.json"
swift run -c release outrage launch "$WORK/profile.json" --wait
