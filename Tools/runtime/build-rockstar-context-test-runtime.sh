#!/usr/bin/env bash
# Developer proof lane for Rockstar's SwapDeviceContextState startup requirement.
# Uses an exact upstream CI artifact; this is not a durable release dependency.
set -euo pipefail

[[ $# -eq 3 ]] || {
    echo "usage: $0 <verified-launcher-engine-root> <work-directory> <output-directory>" >&2
    exit 2
}
ENGINE_ROOT="$(cd "$1" && pwd)"
mkdir -p "$2" "$3"
WORK="$(cd "$2" && pwd)"
OUTPUT="$(cd "$3" && pwd)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DXMT_COMMIT=a148782d431249405acdb1531dbb0c7e737bbece
DXMT_RUN=39904585849
DXMT_SHA256=37c33b07a3dc6dc1703736ffe462ca2673612985e3da5fc3bcffd918de1de120
ARCHIVE="$WORK/artifact/dxmt-$DXMT_COMMIT.tar.gz"

command -v gh >/dev/null || { echo 'error: authenticated gh CLI required to download upstream CI artifacts' >&2; exit 1; }
[[ -f "$ENGINE_ROOT/share/outrage/dependencies.lock" ]] || {
    echo 'error: use the verified dependency-integrated launcher engine, not the stripped foundation' >&2
    exit 1
}
bash "$REPO_ROOT/Tools/runtime/audit-runtime-dylibs.sh" "$ENGINE_ROOT"
ACTUAL_COMMIT="$(gh api "repos/3Shain/dxmt/actions/runs/$DXMT_RUN" --jq '.head_sha')"
[[ "$ACTUAL_COMMIT" == "$DXMT_COMMIT" ]] || { echo 'error: unexpected upstream build commit' >&2; exit 1; }
if [[ ! -f "$ARCHIVE" ]]; then
    gh run download "$DXMT_RUN" --repo 3Shain/dxmt \
        --name "dxmt-$DXMT_COMMIT" --dir "$WORK/artifact"
fi
ACTUAL_SHA256="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
[[ "$ACTUAL_SHA256" == "$DXMT_SHA256" ]] || { echo 'error: upstream DXMT artifact checksum mismatch' >&2; exit 1; }
mkdir -p "$WORK/backend"
tar -xzf "$ARCHIVE" -C "$WORK/backend"
cd "$REPO_ROOT"
swift run -c release outrage runtime-build-metal \
    "$ENGINE_ROOT" "$WORK/backend/$DXMT_COMMIT" \
    outrage-metal-context-test '26.3.0+dxmt.a148782-context-test' "$OUTPUT"
