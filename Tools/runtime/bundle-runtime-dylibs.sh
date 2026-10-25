#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: $0 <dependency-prefix> <runtime-root>" >&2
    exit 2
fi

DEPS_PREFIX="$(cd "$1" && pwd)"
RUNTIME_ROOT="$(cd "$2" && pwd)"
DESTINATION="$RUNTIME_ROOT/lib/outrage"

[[ "$(uname -s)" == "Darwin" ]] || {
    echo "error: runtime dylib bundling requires macOS" >&2
    exit 1
}
[[ -d "$DEPS_PREFIX/lib" ]] || {
    echo "error: dependency lib directory not found: $DEPS_PREFIX/lib" >&2
    exit 1
}

rm -rf "$DESTINATION"
mkdir -p "$DESTINATION"

# Keep versioned libraries and their normal linker-name symlinks together.
while IFS= read -r -d '' source; do
    cp -P "$source" "$DESTINATION/"
done < <(find "$DEPS_PREFIX/lib" -maxdepth 1 \( -type f -o -type l \) -name '*.dylib' -print0)

is_macho() {
    file -b "$1" 2>/dev/null | grep -q 'Mach-O'
}

add_rpath_if_missing() {
    local file="$1" rpath="$2"
    if otool -l "$file" 2>/dev/null | awk '
        $1 == "cmd" && $2 == "LC_RPATH" { in_rpath = 1; next }
        in_rpath && $1 == "path" { print $2; in_rpath = 0 }
    ' | grep -Fxq "$rpath"; then
        return
    fi
    install_name_tool -add_rpath "$rpath" "$file"
}

# Give bundled libraries relocatable IDs first.
while IFS= read -r -d '' dylib; do
    is_macho "$dylib" || continue
    install_name_tool -id "@rpath/$(basename "$dylib")" "$dylib"
done < <(find "$DESTINATION" -type f -name '*.dylib' -print0)

# Rewrite all dependency-prefix references inside the complete runtime tree.
while IFS= read -r -d '' candidate; do
    is_macho "$candidate" || continue

    while IFS= read -r dependency; do
        [[ -n "$dependency" ]] || continue
        case "$dependency" in
            "$DEPS_PREFIX"/lib/*.dylib)
                install_name_tool \
                    -change "$dependency" \
                    "@rpath/$(basename "$dependency")" \
                    "$candidate"
                ;;
        esac
    done < <(
        otool -L "$candidate" 2>/dev/null |
            tail -n +2 |
            sed -E 's/^[[:space:]]*([^[:space:]]+).*/\1/'
    )

    case "$candidate" in
        "$RUNTIME_ROOT"/bin/*)
            add_rpath_if_missing "$candidate" '@loader_path/../lib/outrage'
            ;;
        "$RUNTIME_ROOT"/lib/wine/x86_64-unix/*)
            add_rpath_if_missing "$candidate" '@loader_path/../../outrage'
            ;;
        "$DESTINATION"/*)
            add_rpath_if_missing "$candidate" '@loader_path'
            ;;
        "$RUNTIME_ROOT"/lib/*)
            add_rpath_if_missing "$candidate" '@loader_path/outrage'
            ;;
    esac

    codesign --force --sign - "$candidate" >/dev/null 2>&1
done < <(find "$RUNTIME_ROOT" -type f -print0)

# Fail closed if any build-prefix references survived relocation.
if grep -R -a -l -F "$DEPS_PREFIX" "$RUNTIME_ROOT/bin" "$RUNTIME_ROOT/lib" 2>/dev/null | head -n 1 | grep -q .; then
    echo "error: dependency build-prefix references remain in bundled runtime" >&2
    grep -R -a -l -F "$DEPS_PREFIX" "$RUNTIME_ROOT/bin" "$RUNTIME_ROOT/lib" 2>/dev/null | head -20 >&2 || true
    exit 1
fi

echo "bundled runtime dylibs: $DESTINATION"
