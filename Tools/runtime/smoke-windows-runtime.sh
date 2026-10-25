#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: smoke-windows-runtime.sh <runtime-root>" >&2
    exit 2
fi

RUNTIME_ROOT="$(cd "$1" && pwd)"
WINE_LOADER=""
if [[ -x "$RUNTIME_ROOT/bin/wine64" ]]; then
    WINE_LOADER="$RUNTIME_ROOT/bin/wine64"
elif [[ -x "$RUNTIME_ROOT/bin/wine" ]]; then
    WINE_LOADER="$RUNTIME_ROOT/bin/wine"
else
    echo "error: runtime has no Wine loader" >&2
    exit 1
fi

command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1 || {
    echo "error: x86_64-w64-mingw32-gcc is required" >&2
    exit 1
}
arch -x86_64 /usr/bin/true >/dev/null 2>&1 || {
    echo "error: Rosetta is required" >&2
    exit 1
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/outrage-smoke.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/smoke.c" <<'EOF'
#include <stdio.h>
int main(void) {
    puts("OUTRAGE_RUNTIME_OK");
    return 0;
}
EOF

x86_64-w64-mingw32-gcc -O2 -s -o "$WORK/smoke.exe" "$WORK/smoke.c"

OUTPUT="$(
    WINEPREFIX="$WORK/prefix" \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES=mscoree,mshtml= \
    arch -x86_64 "$WINE_LOADER" "$WORK/smoke.exe" 2>&1
)"

if [[ "$OUTPUT" != *"OUTRAGE_RUNTIME_OK"* ]]; then
    printf '%s\n' "$OUTPUT" >&2
    echo "error: packaged runtime did not execute the Windows smoke target" >&2
    exit 1
fi

printf '%s\n' "$OUTPUT"
