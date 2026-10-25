#!/usr/bin/env bash
set -euo pipefail

GMP_VERSION="6.3.0"
GMP_SHA256="a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898"
NETTLE_VERSION="4.0"
NETTLE_SHA256="3addbc00da01846b232fb3bc453538ea5468da43033f21bb345cb1e9073f5094"
GNUTLS_VERSION="3.8.13"
GNUTLS_SHA256="ffed8ec1bf09c2426d4f14aae377de4753b53e537d685e604e99a8b16ca9c97e"
GNUTLS_PATCH_URL="https://gitlab.com/gnutls/gnutls/-/commit/29c2027c963cf559817d0da37c1fc2efd0c1bd6a.diff"
GNUTLS_PATCH_SHA256="c0bfc0164ff131c9d2e1c4d0367430f8b767b64c9c21e0f408bd634d21fb0302"
FREETYPE_VERSION="2.15.0"
FREETYPE_SHA256="93cd47eb719c325107f2d3cf087d06299e944c3b48a40b55537302304dea1dd5"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$REPO_ROOT/.build/runtime-deps-x86_64"
PREFIX="$WORK/prefix"
JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"

usage() {
    cat <<'EOF'
Usage: Tools/runtime/build-x86_64-runtime-deps.sh [options]

Options:
  --work <dir>       Build/download workspace.
  --prefix <dir>     Installation prefix for x86_64 runtime dependencies.
  --jobs <count>     Parallel build jobs.
  -h, --help         Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --work) WORK="${2:?missing --work value}"; shift 2 ;;
        --prefix) PREFIX="${2:?missing --prefix value}"; shift 2 ;;
        --jobs) JOBS="${2:?missing --jobs value}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

log() { printf '\n==> %s\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }
sha256() { shasum -a 256 "$1" | awk '{print $1}'; }

[[ "$(uname -s)" == "Darwin" ]] || die "dependency builds require macOS"
arch -x86_64 /usr/bin/true >/dev/null 2>&1 || die "Rosetta is required"
command -v curl >/dev/null || die "curl is required"
command -v patch >/dev/null || die "patch is required"

DOWNLOADS="$WORK/downloads"
SOURCES="$WORK/sources"
mkdir -p "$DOWNLOADS" "$SOURCES" "$PREFIX"

GMP_ARCHIVE="$DOWNLOADS/gmp-$GMP_VERSION.tar.xz"
NETTLE_ARCHIVE="$DOWNLOADS/nettle-$NETTLE_VERSION.tar.gz"
GNUTLS_ARCHIVE="$DOWNLOADS/gnutls-$GNUTLS_VERSION.tar.xz"
GNUTLS_PATCH="$DOWNLOADS/gnutls-$GNUTLS_VERSION-homebrew.diff"
FREETYPE_ARCHIVE="$DOWNLOADS/freetype-$FREETYPE_VERSION.tar.xz"

GMP_URL="https://ftpmirror.gnu.org/gmp/gmp-$GMP_VERSION.tar.xz"
NETTLE_URL="https://ftpmirror.gnu.org/nettle/nettle-$NETTLE_VERSION.tar.gz"
GNUTLS_URL="https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-$GNUTLS_VERSION.tar.xz"
FREETYPE_URL="https://downloads.sourceforge.net/project/freetype/freetype2/$FREETYPE_VERSION/freetype-$FREETYPE_VERSION.tar.xz"

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

log "Fetching pinned x86_64 dependency sources"
download_verified "$GMP_URL" "$GMP_ARCHIVE" "$GMP_SHA256"
download_verified "$NETTLE_URL" "$NETTLE_ARCHIVE" "$NETTLE_SHA256"
download_verified "$GNUTLS_URL" "$GNUTLS_ARCHIVE" "$GNUTLS_SHA256"
download_verified "$GNUTLS_PATCH_URL" "$GNUTLS_PATCH" "$GNUTLS_PATCH_SHA256"
download_verified "$FREETYPE_URL" "$FREETYPE_ARCHIVE" "$FREETYPE_SHA256"

rm -rf "$SOURCES"
mkdir -p "$SOURCES"
tar -xJf "$GMP_ARCHIVE" -C "$SOURCES"
tar -xzf "$NETTLE_ARCHIVE" -C "$SOURCES"
tar -xJf "$GNUTLS_ARCHIVE" -C "$SOURCES"
tar -xJf "$FREETYPE_ARCHIVE" -C "$SOURCES"

# Search only the pinned x86_64 prefix; Homebrew pkg-config defaults can
# otherwise select ARM libraries during the install-time libtool relink.
COMMON_ENV="export MACOSX_DEPLOYMENT_TARGET=14.0; export CC='clang -arch x86_64'; export CXX='clang++ -arch x86_64'; export CFLAGS='-O2 -mmacosx-version-min=14.0'; export CXXFLAGS='-O2 -mmacosx-version-min=14.0'; export CPPFLAGS='-I$PREFIX/include'; export LDFLAGS='-arch x86_64 -mmacosx-version-min=14.0 -L$PREFIX/lib -Wl,-headerpad_max_install_names'; export PKG_CONFIG_PATH=; export PKG_CONFIG_LIBDIR='$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig'"

build_autoconf() {
    local name="$1" source="$2" configure_args="$3"
    log "Building $name for x86_64"
    arch -x86_64 /bin/bash -c "$COMMON_ENV
        cd '$source'
        ./configure --prefix='$PREFIX' --disable-static --enable-shared $configure_args
        make -j'$JOBS'
        make install" > "$WORK/$name.log" 2>&1 || {
            tail -80 "$WORK/$name.log" >&2 || true
            die "$name build failed"
        }
}

rm -rf "$PREFIX"
mkdir -p "$PREFIX"

build_autoconf \
    "gmp" \
    "$SOURCES/gmp-$GMP_VERSION" \
    "--enable-cxx=no"

build_autoconf \
    "nettle" \
    "$SOURCES/nettle-$NETTLE_VERSION" \
    "--disable-openssl --disable-documentation"

build_autoconf \
    "freetype" \
    "$SOURCES/freetype-$FREETYPE_VERSION" \
    "--without-harfbuzz --without-brotli --without-png"

log "Applying pinned GnuTLS backport"
(
    cd "$SOURCES/gnutls-$GNUTLS_VERSION"
    patch -p1 < "$GNUTLS_PATCH"
)

build_autoconf \
    "gnutls" \
    "$SOURCES/gnutls-$GNUTLS_VERSION" \
    "--disable-doc --disable-tools --disable-cxx --disable-tests --disable-full-test-suite --disable-valgrind-tests --disable-rpath --disable-libdane --with-system-priority-file=/dev/null --without-p11-kit --without-tpm --without-zlib --without-brotli --without-zstd --without-idn --without-libidn2 --with-included-libtasn1 --with-included-unistring"

log "Verifying x86_64 dependency outputs"
for pattern in libgmp libnettle libhogweed libfreetype libgnutls; do
    dylib="$(find "$PREFIX/lib" -maxdepth 1 -type f -name "$pattern*.dylib" -print -quit)"
    [[ -n "$dylib" ]] || die "missing $pattern dylib"
    file "$dylib" | grep -q 'x86_64' || die "$dylib is not x86_64"
done

cat > "$PREFIX/outrage-deps.lock" <<EOF
architecture=x86_64
macos_deployment_target=14.0
gmp=$GMP_VERSION
nettle=$NETTLE_VERSION
gnutls=$GNUTLS_VERSION
freetype=$FREETYPE_VERSION
EOF

log "x86_64 runtime dependencies ready at $PREFIX"
