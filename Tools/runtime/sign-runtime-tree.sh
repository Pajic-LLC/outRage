#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: sign-runtime-tree.sh <runtime-root>" >&2
    exit 2
fi

ROOT="$(cd "$1" && pwd)"
command -v codesign >/dev/null 2>&1 || {
    echo "error: codesign is required" >&2
    exit 1
}
command -v file >/dev/null 2>&1 || {
    echo "error: file is required" >&2
    exit 1
}

SIGNED=0
while IFS= read -r -d '' candidate; do
    if file -b "$candidate" | grep -q 'Mach-O'; then
        codesign --force --sign - --timestamp=none "$candidate"
        SIGNED=$((SIGNED + 1))
    fi
done < <(find "$ROOT" -type f -print0)

printf 'signed-mach-o: %d\n' "$SIGNED"
