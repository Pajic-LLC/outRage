#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 1 ]] || { echo "usage: $0 <dependency-prefix>" >&2; exit 2; }
PREFIX="$(cd "$1" && pwd)"
[[ -f "$PREFIX/outrage-deps.lock" ]] || { echo "error: dependency prefix has no outRage lock" >&2; exit 1; }
grep -Fxq 'architecture=x86_64' "$PREFIX/outrage-deps.lock" || { echo "error: dependency prefix is not x86_64" >&2; exit 1; }
for library in libgmp libnettle libhogweed libfreetype libgnutls; do
    dylib="$(find "$PREFIX/lib" -maxdepth 1 -type f -name "$library*.dylib" -print -quit)"
    [[ -n "$dylib" ]] || { echo "error: dependency prefix is missing $library" >&2; exit 1; }
    lipo "$dylib" -verify_arch x86_64 || { echo "error: dependency is not x86_64: $dylib" >&2; exit 1; }
done
echo "verified x86_64 dependency prefix: $PREFIX"
