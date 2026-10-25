#!/usr/bin/env python3
"""Compose an isolated, existing-prefix developer runtime; never edit its engine.

Usage: build-mullion-test-runtime.py ENGINE VERIFIED_ARCHIVE NEW_STAGE
Package NEW_STAGE with outrage runtime-pack after its dependency audit passes.
"""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile

ARCHIVE_SHA = "3109e3f15561eda659f04049f2e2cfb187d634cfb9fff96dac6ff1b02ae9932e"
SOURCE_COMMIT = "7bcdcb4437f745ba9d5b6b876c9521008388296c"
DLLS = ("d3d10core.dll", "d3d11.dll", "dxgi.dll", "d3d12.dll", "d3d12core.dll", "winemetal.dll")


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    engine, archive, stage = map(lambda p: Path(p).resolve(), sys.argv[1:])
    if stage.exists() or stage.is_symlink():
        raise SystemExit("Stage already exists; choose a new directory")
    if engine == stage or engine in stage.parents or stage in engine.parents:
        raise SystemExit("Engine and stage must be independent directories")
    if not (engine / "share/outrage/dependencies.lock").is_file():
        raise SystemExit("Use a dependency-integrated engine")
    if hashlib.sha256(archive.read_bytes()).hexdigest() != ARCHIVE_SHA:
        raise SystemExit("Mullion release checksum mismatch")
    # Extract only the known release payload. Do not execute its install script.
    with tempfile.TemporaryDirectory(prefix="outrage-mullion-") as temporary:
        extracted = Path(temporary)
        with tarfile.open(archive) as tar:
            for member in tar.getmembers():
                relative = Path(member.name)
                if relative.is_absolute() or ".." in relative.parts or not (member.isfile() or member.isdir()):
                    raise SystemExit("Unexpected archive member")
            tar.extractall(extracted)
        backend = extracted / "mullion-v0.4"
        for name in DLLS:
            module = backend / "x86_64-windows" / name
            if b"Wine builtin DLL\0" not in module.read_bytes()[:128]:
                raise SystemExit(f"Not a builtin Wine module: {name}")
        subprocess.run(["/usr/bin/ditto", str(engine), str(stage)], check=True)
        for name in DLLS:
            destination = stage / "lib/wine/x86_64-windows" / name
            if destination.exists() or destination.is_symlink():
                destination.unlink()
            shutil.copy2(backend / "x86_64-windows" / name, destination)
        native = stage / "lib/wine/x86_64-unix/winemetal.so"
        native.unlink()
        shutil.copy2(backend / "x86_64-unix/winemetal.so", native)
        subprocess.run(["/usr/bin/lipo", str(native), "-verify_arch", "x86_64"], check=True)
        subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", "--timestamp=none", str(native)], check=True)
        subprocess.run(["/usr/bin/codesign", "--verify", "--strict", str(native)], check=True)
        licenses = stage / "share/licenses/mullion-v0.4"
        licenses.mkdir(parents=True)
        for name in ("LICENSE", "LICENSE.OLD", "LICENSE-LLVM.txt", "COPYING.LIB", "README.md"):
            shutil.copy2(backend / name, licenses / name)
    descriptor_path = stage / "runtime.json"
    descriptor = json.loads(descriptor_path.read_text())
    descriptor["id"] = "outrage-metal-mullion-test"
    descriptor["supportedGraphicsBackends"] = ["mullion"]
    descriptor.pop("prefixInitializer", None)  # Existing-prefix trial; not fresh-machine proof.
    descriptor["environment"].pop("DXMT_LOG_PATH", None)
    descriptor["environment"]["MULLION_LOG_PATH"] = "${CACHE_ROOT}/mullion-logs"
    descriptor["environment"]["DXMT_SHADER_CACHE_PATH"] = "${CACHE_ROOT}/mullion-shaders"
    descriptor["graphicsConfigurations"] = {"mullion": {"fileMappings": [{
        "source": "lib/wine/x86_64-windows/winemetal.dll", "destinationScope": "prefix",
        "destination": "drive_c/windows/system32/winemetal.dll", "mode": "symlink"}]}}
    descriptor_path.write_text(json.dumps(descriptor, indent=2) + "\n")
    provenance = {"project": "https://github.com/dttdrv/mullion", "tag": "v0.4",
        "commit": SOURCE_COMMIT, "archiveSHA256": ARCHIVE_SHA,
        "asset": "https://github.com/dttdrv/mullion/releases/download/v0.4/mullion-v0.4.tar.gz",
        "baseRuntime": json.loads((engine / "runtime.json").read_text())["id"],
        "scope": "existing-prefix developer trial; gameplay unproven"}
    (stage / "share/outrage/mullion-test.json").write_text(json.dumps(provenance, indent=2) + "\n")
    print(stage)


if __name__ == "__main__":
    main()
