#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: smoke-d3d11-runtime.sh <runtime-root>" >&2
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

WORK="$(mktemp -d "${TMPDIR:-/tmp}/outrage-d3d11-smoke.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/d3d11-smoke.c" <<'EOF'
#define COBJMACROS
#include <windows.h>
#include <d3d11.h>
#include <stdio.h>

int main(void) {
    ID3D11Device *device = NULL;
    ID3D11DeviceContext *context = NULL;
    D3D_FEATURE_LEVEL level = 0;
    const D3D_FEATURE_LEVEL levels[] = {
        D3D_FEATURE_LEVEL_11_0,
        D3D_FEATURE_LEVEL_10_1,
        D3D_FEATURE_LEVEL_10_0
    };

    HRESULT hr = D3D11CreateDevice(
        NULL,
        D3D_DRIVER_TYPE_HARDWARE,
        NULL,
        0,
        levels,
        sizeof(levels) / sizeof(levels[0]),
        D3D11_SDK_VERSION,
        &device,
        &level,
        &context
    );

    if (FAILED(hr)) {
        fprintf(stderr, "D3D11CreateDevice failed: 0x%08lx\n", (unsigned long)hr);
        return 2;
    }

    if (context) ID3D11DeviceContext_Release(context);
    if (device) ID3D11Device_Release(device);
    printf("OUTRAGE_D3D11_OK feature_level=0x%x\n", (unsigned int)level);
    return 0;
}
EOF

x86_64-w64-mingw32-gcc \
    -O2 -s \
    -o "$WORK/d3d11-smoke.exe" \
    "$WORK/d3d11-smoke.c" \
    -ld3d11 -ldxgi -ldxguid -lole32 -luuid

mkdir -p "$WORK/prefix/drive_c/windows/system32"
if [[ -f "$RUNTIME_ROOT/lib/wine/x86_64-windows/winemetal.dll" ]]; then
    ln -sf "$RUNTIME_ROOT/lib/wine/x86_64-windows/winemetal.dll" \
        "$WORK/prefix/drive_c/windows/system32/winemetal.dll"
fi

OUTPUT="$(
    WINEPREFIX="$WORK/prefix" \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES=mscoree,mshtml= \
    DXMT_SHADER_CACHE_PATH="$WORK/shaders" \
    DXMT_LOG_PATH="$WORK/logs" \
    DXMT_LOG_LEVEL=info \
    arch -x86_64 "$WINE_LOADER" "$WORK/d3d11-smoke.exe" 2>&1
)" || {
    printf '%s\n' "$OUTPUT" >&2
    if [[ -d "$WORK/logs" ]]; then
        find "$WORK/logs" -type f -maxdepth 2 -print -exec tail -100 {} \; >&2 || true
    fi
    exit 1
}

if [[ "$OUTPUT" != *"OUTRAGE_D3D11_OK"* ]]; then
    printf '%s\n' "$OUTPUT" >&2
    echo "error: DXMT D3D11 smoke target did not initialize" >&2
    exit 1
fi

printf '%s\n' "$OUTPUT"
