#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORK="$REPO_ROOT/.build/runtime-foss-validated"
OUTPUT="$REPO_ROOT/.build/runtime-packages"
JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
INSTALL_DEPS=false

usage() {
    cat <<'EOF'
Usage: Tools/runtime/build-validated-foss-metal-runtime.sh [options]

Options:
  --work <dir>      Build workspace.
  --output <dir>    Final package output directory.
  --jobs <count>    Parallel engine build jobs.
  --install-deps    Install missing Homebrew build dependencies.
  -h, --help        Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --work) WORK="${2:?missing --work value}"; shift 2 ;;
        --output) OUTPUT="${2:?missing --output value}"; shift 2 ;;
        --jobs) JOBS="${2:?missing --jobs value}"; shift 2 ;;
        --install-deps) INSTALL_DEPS=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

ARGS=(--work "$WORK" --output "$OUTPUT" --jobs "$JOBS")
if [[ "$INSTALL_DEPS" == true ]]; then
    ARGS+=(--install-deps)
fi

bash "$SCRIPT_DIR/build-foss-metal-runtime.sh" "${ARGS[@]}"

ENGINE_ROOT="$WORK/engine"
DXMT_ROOT="$WORK/dxmt"
[[ -d "$ENGINE_ROOT" ]] || { echo "error: staged engine missing" >&2; exit 1; }
[[ -d "$DXMT_ROOT" ]] || { echo "error: staged Metal backend missing" >&2; exit 1; }

# Signing happens after stripping/staging. The backend contains native Mach-O
# components too, so validate both source trees before final composition.
bash "$SCRIPT_DIR/sign-runtime-tree.sh" "$ENGINE_ROOT"
bash "$SCRIPT_DIR/sign-runtime-tree.sh" "$DXMT_ROOT"
bash "$SCRIPT_DIR/smoke-windows-runtime.sh" "$ENGINE_ROOT"

rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"

cd "$REPO_ROOT"
swift run -c release outrage runtime-build-metal \
    "$ENGINE_ROOT" \
    "$DXMT_ROOT" \
    "outrage-metal-x86_64" \
    "26.3.0+v0.80" \
    "$OUTPUT"

printf 'validated-runtime-package: %s\n' "$OUTPUT"
