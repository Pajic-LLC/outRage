#!/usr/bin/env bash
set -euo pipefail

CROSSOVER_VERSION="26.3.0"
CROSSOVER_SHA256="ac99c8ca4b3848f3e81784135f023df266b61c2345726ea55a50b3e030dd6872"
DXMT_VERSION="v0.80"
DXMT_SHA256="8f260e36b5739e68f3bad613381441385c4dc7b85b78ba8de653d5a6a264529d"
RUNTIME_ID="outrage-metal-x86_64"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$REPO_ROOT/.build/runtime-foss"
OUTPUT="$REPO_ROOT/.build/runtime-packages"
JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
INSTALL_DEPS=false
SKIP_ENGINE_BUILD=false

usage() {
    cat <<'EOF'
Usage: Tools/runtime/build-foss-metal-runtime.sh [options]

Options:
  --work <dir>          Build/download workspace.
  --output <dir>        Runtime package output directory.
  --jobs <count>        Parallel build jobs.
  --install-deps        Install missing Homebrew build dependencies.
  --skip-engine-build   Reuse an existing engine build in the workspace.
  -h, --help            Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --work) WORK="${2:?missing --work value}"; shift 2 ;;
        --output) OUTPUT="${2:?missing --output value}"; shift 2 ;;
        --jobs) JOBS="${2:?missing --jobs value}"; shift 2 ;;
        --install-deps) INSTALL_DEPS=true; shift ;;
        --skip-engine-build) SKIP_ENGINE_BUILD=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

log() { printf '\n==> %s\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "runtime builds require macOS"
xcode-select -p >/dev/null 2>&1 || die "Xcode Command Line Tools are required"
arch -x86_64 /usr/bin/true >/dev/null 2>&1 || die "Rosetta is required for the x86_64 engine build"
command -v brew >/dev/null 2>&1 || die "Homebrew is required for build dependencies"

for formula in bison flex mingw-w64; do
    if ! brew list --formula "$formula" >/dev/null 2>&1; then
        if [[ "$INSTALL_DEPS" == true ]]; then
            brew install "$formula"
        else
            die "missing Homebrew formula '$formula' (rerun with --install-deps)"
        fi
    fi
done

BREW_PREFIX="$(brew --prefix)"
BISON_BIN="$(brew --prefix bison)/bin"
FLEX_BIN="$(brew --prefix flex)/bin"
TOOL_PATH="$BISON_BIN:$FLEX_BIN:$BREW_PREFIX/bin:/usr/bin:/bin:/usr/sbin:/sbin"
MINGW_STRIP="$BREW_PREFIX/bin/x86_64-w64-mingw32-strip"
[[ -x "$BREW_PREFIX/bin/x86_64-w64-mingw32-gcc" ]] || die "x86_64 mingw-w64 compiler is unavailable"

DOWNLOADS="$WORK/downloads"
SOURCE_ROOT="$WORK/source"
WINE_SOURCE="$SOURCE_ROOT/sources/wine"
BUILD_ROOT="$WORK/build"
INSTALL_ROOT="$WORK/install"
ENGINE_ROOT="$WORK/engine"
DXMT_ROOT="$WORK/dxmt"
mkdir -p "$DOWNLOADS" "$OUTPUT"

CROSSOVER_ARCHIVE="$DOWNLOADS/crossover-sources-$CROSSOVER_VERSION.tar.gz"
DXMT_ARCHIVE="$DOWNLOADS/dxmt-$DXMT_VERSION-builtin.tar.gz"
CROSSOVER_URL="https://media.codeweavers.com/pub/crossover/source/crossover-sources-$CROSSOVER_VERSION.tar.gz"
DXMT_URL="https://github.com/3Shain/dxmt/releases/download/$DXMT_VERSION/dxmt-$DXMT_VERSION-builtin.tar.gz"

sha256() { shasum -a 256 "$1" | awk '{print $1}'; }

download_verified() {
    local url="$1" destination="$2" expected="$3"
    if [[ -f "$destination" ]] && [[ "$(sha256 "$destination")" == "$expected" ]]; then
        echo "using cached $(basename "$destination")"
        return
    fi

    rm -f "$destination.part"
    curl --fail --location --retry 3 --output "$destination.part" "$url"
    local actual
    actual="$(sha256 "$destination.part")"
    [[ "$actual" == "$expected" ]] || die "checksum mismatch for $url (expected $expected, got $actual)"
    mv "$destination.part" "$destination"
}

log "Fetching pinned sources"
download_verified "$CROSSOVER_URL" "$CROSSOVER_ARCHIVE" "$CROSSOVER_SHA256"
download_verified "$DXMT_URL" "$DXMT_ARCHIVE" "$DXMT_SHA256"

if [[ "$SKIP_ENGINE_BUILD" != true ]]; then
    log "Extracting engine source"
    rm -rf "$SOURCE_ROOT" "$BUILD_ROOT" "$INSTALL_ROOT"
    mkdir -p "$SOURCE_ROOT" "$BUILD_ROOT"
    tar -xzf "$CROSSOVER_ARCHIVE" -C "$SOURCE_ROOT" sources/wine
    [[ -x "$WINE_SOURCE/configure" ]] || die "source archive does not contain sources/wine/configure"

    # The FOSS source archive can omit this generated crash-dialog header.
    if [[ ! -f "$WINE_SOURCE/programs/winedbg/distversion.h" ]]; then
        cat > "$WINE_SOURCE/programs/winedbg/distversion.h" <<'EOF'
#define WINDEBUG_WHAT_HAPPENED_MESSAGE "The program encountered an error."
#define WINDEBUG_USER_SUGGESTION_MESSAGE "Save the diagnostic details when reporting a compatibility issue."
EOF
    fi

    # A Vulkan SONAME is referenced by this source generation even in a Vulkan-disabled build.
    VULKAN_C="$WINE_SOURCE/dlls/win32u/vulkan.c"
    if [[ -f "$VULKAN_C" ]] && grep -q 'libvulkan = SONAME_LIBVULKAN;' "$VULKAN_C" && ! grep -q 'OUTRAGE_NO_MOLTENVK' "$VULKAN_C"; then
        perl -0pi -e 's/(static void vulkan_init_once\(void\))/#ifndef SONAME_LIBVULKAN \/\* OUTRAGE_NO_MOLTENVK *\/\n#define SONAME_LIBVULKAN "libMoltenVK.dylib"\n#endif\n\n$1/' "$VULKAN_C"
    fi

    BUILD_ENV="export PATH='$TOOL_PATH'; export PKG_CONFIG_LIBDIR=/nonexistent; export MACOSX_DEPLOYMENT_TARGET=14.0; export CC='clang -arch x86_64'; export CXX='clang++ -arch x86_64'; export OBJC='clang -arch x86_64'"

    log "Configuring x86_64 engine"
    arch -x86_64 /bin/bash -c "$BUILD_ENV
        cd '$BUILD_ROOT'
        '$WINE_SOURCE/configure' \
            --prefix='$INSTALL_ROOT' \
            --enable-archs=x86_64 \
            --disable-tests \
            --without-x \
            --without-vulkan \
            --without-gstreamer \
            --without-gnutls \
            --without-freetype \
            --without-sdl \
            --without-krb5 \
            --without-cups \
            --without-usb \
            --without-pcap \
            --without-pcsclite \
            --without-dbus \
            --without-capi \
            --without-gphoto \
            --without-sane \
            --without-netapi \
            --without-v4l2 \
            --without-inotify \
            --without-unwind" > "$WORK/configure.log" 2>&1 || {
                tail -60 "$WORK/configure.log" >&2
                die "engine configure failed"
            }

    log "Building x86_64 engine ($JOBS jobs)"
    arch -x86_64 /bin/bash -c "$BUILD_ENV
        cd '$BUILD_ROOT'
        make -j'$JOBS'
        make install" > "$WORK/make.log" 2>&1 || {
            grep -i 'error' "$WORK/make.log" | tail -50 >&2 || true
            die "engine build failed; inspect $WORK/make.log"
        }
else
    [[ -x "$INSTALL_ROOT/bin/wine" || -x "$INSTALL_ROOT/bin/wine64" ]] || die "--skip-engine-build needs a completed install at $INSTALL_ROOT"
fi

log "Staging engine tree"
rm -rf "$ENGINE_ROOT"
mkdir -p "$ENGINE_ROOT/bin" "$ENGINE_ROOT/lib" "$ENGINE_ROOT/share"

for executable in wine wine64 wineserver; do
    if [[ -e "$INSTALL_ROOT/bin/$executable" ]]; then
        cp -P "$INSTALL_ROOT/bin/$executable" "$ENGINE_ROOT/bin/"
    fi
done

# Preserve Wine's runtime layout but leave static archives and debug-only files behind.
rsync -a --exclude='*.a' --exclude='*.la' "$INSTALL_ROOT/lib/" "$ENGINE_ROOT/lib/"
if [[ -d "$INSTALL_ROOT/share/wine" ]]; then
    mkdir -p "$ENGINE_ROOT/share/wine"
    rsync -a "$INSTALL_ROOT/share/wine/" "$ENGINE_ROOT/share/wine/"
fi

[[ -x "$ENGINE_ROOT/bin/wine" || -x "$ENGINE_ROOT/bin/wine64" ]] || die "staged engine has no Wine loader"

# Strip only local symbols so macOS driver exports required by Metal translation survive.
find "$ENGINE_ROOT/bin" "$ENGINE_ROOT/lib/wine" -type f \( -name '*.so' -o -perm -u+x \) -exec strip -x {} + 2>/dev/null || true
if [[ -x "$MINGW_STRIP" && -d "$ENGINE_ROOT/lib/wine/x86_64-windows" ]]; then
    find "$ENGINE_ROOT/lib/wine/x86_64-windows" -type f -print0 |
        xargs -0 -n 64 "$MINGW_STRIP" --strip-debug 2>/dev/null || true
fi

MACDRV="$ENGINE_ROOT/lib/wine/x86_64-unix/winemac.so"
if [[ -f "$MACDRV" ]]; then
    nm -gU "$MACDRV" | grep -q ' _macdrv_functions$' || die "staged macOS driver is missing the required exported driver table"
fi

log "Extracting Metal backend"
rm -rf "$DXMT_ROOT"
mkdir -p "$DXMT_ROOT"
tar -xzf "$DXMT_ARCHIVE" -C "$DXMT_ROOT"

log "Composing and packaging runtime"
cd "$REPO_ROOT"
swift run -c release outrage runtime-build-metal \
    "$ENGINE_ROOT" \
    "$DXMT_ROOT" \
    "$RUNTIME_ID" \
    "$CROSSOVER_VERSION+$DXMT_VERSION" \
    "$OUTPUT"

log "Runtime package complete"
