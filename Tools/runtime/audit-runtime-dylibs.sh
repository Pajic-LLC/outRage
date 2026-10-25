#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <runtime-root>" >&2
  exit 2
fi

ROOT="$(cd "$1" && pwd)"
[[ "$(uname -s)" == "Darwin" ]] || {
  echo "error: Mach-O runtime audit requires macOS" >&2
  exit 1
}

failures=0
scanned=0

is_allowed_absolute() {
  case "$1" in
    /System/Library/*|/usr/lib/*) return 0 ;;
    *) return 1 ;;
  esac
}

is_forbidden_build_path() {
  case "$1" in
    /opt/homebrew/*|/usr/local/*|/opt/local/*|/Users/*|/private/tmp/*|/tmp/*) return 0 ;;
    *) return 1 ;;
  esac
}

while IFS= read -r -d '' candidate; do
  if ! file -b "$candidate" | grep -q 'Mach-O'; then
    continue
  fi
  scanned=$((scanned + 1))

  while IFS= read -r dependency; do
    [[ -n "$dependency" ]] || continue
    case "$dependency" in
      @rpath/*|@loader_path/*|@executable_path/*) ;;
      /*)
        if ! is_allowed_absolute "$dependency"; then
          echo "error: non-system absolute dylib reference" >&2
          echo "  file: $candidate" >&2
          echo "  ref:  $dependency" >&2
          failures=$((failures + 1))
        fi
        ;;
    esac
  done < <(
    otool -L "$candidate" 2>/dev/null |
      tail -n +2 |
      sed -E 's/^[[:space:]]+//; s/ \(compatibility version.*$//'
  )

  while IFS= read -r rpath; do
    [[ -n "$rpath" ]] || continue
    if is_forbidden_build_path "$rpath"; then
      echo "error: host-specific LC_RPATH" >&2
      echo "  file:  $candidate" >&2
      echo "  rpath: $rpath" >&2
      failures=$((failures + 1))
    fi
  done < <(
    otool -l "$candidate" 2>/dev/null |
      awk '
        $1 == "cmd" && $2 == "LC_RPATH" { in_rpath = 1; next }
        in_rpath && $1 == "path" { print $2; in_rpath = 0 }
      '
  )
done < <(find "$ROOT" -type f -print0)

if (( scanned == 0 )); then
  echo "error: no Mach-O files found under $ROOT" >&2
  exit 1
fi

if (( failures != 0 )); then
  echo "runtime dylib audit failed: $failures issue(s) across $scanned Mach-O file(s)" >&2
  exit 1
fi

echo "runtime dylib audit passed: $scanned Mach-O file(s)"
