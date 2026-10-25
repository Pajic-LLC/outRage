#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: validate-runtime-tree.sh <runtime-root>" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_ROOT="$(cd "$1" && pwd)"

bash "$SCRIPT_DIR/sign-runtime-tree.sh" "$RUNTIME_ROOT"
bash "$SCRIPT_DIR/smoke-windows-runtime.sh" "$RUNTIME_ROOT"

echo "runtime-validation: ok"
