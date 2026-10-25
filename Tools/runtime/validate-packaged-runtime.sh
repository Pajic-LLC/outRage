#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: validate-packaged-runtime.sh <runtime.zip>" >&2
    exit 2
fi

ARCHIVE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
[[ -f "$ARCHIVE" ]] || { echo "error: runtime package not found: $ARCHIVE" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/outrage-package-validation.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

/usr/bin/ditto -x -k "$ARCHIVE" "$WORK/extracted"

RUNTIME_ROOT="$WORK/extracted"
if [[ ! -f "$RUNTIME_ROOT/runtime.json" ]]; then
    mapfile -t DESCRIPTORS < <(find "$RUNTIME_ROOT" -mindepth 2 -maxdepth 2 -name runtime.json -print)
    if [[ ${#DESCRIPTORS[@]} -ne 1 ]]; then
        echo "error: unable to identify packaged runtime root" >&2
        exit 1
    fi
    RUNTIME_ROOT="$(dirname "${DESCRIPTORS[0]}")"
fi

bash "$SCRIPT_DIR/sign-runtime-tree.sh" "$RUNTIME_ROOT"
bash "$SCRIPT_DIR/smoke-windows-runtime.sh" "$RUNTIME_ROOT"
bash "$SCRIPT_DIR/smoke-d3d11-runtime.sh" "$RUNTIME_ROOT"

echo "packaged-runtime-validation: ok"
