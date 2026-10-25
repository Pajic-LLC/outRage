#!/usr/bin/env python3
"""Package a developer-only Wine .app experiment for Rockstar window identity.

This intentionally duplicates the engine layout for diagnosis. It is not the
release runtime layout, and does not establish visible authentication support.
"""
from pathlib import Path
import argparse
import json
import plistlib
import shutil
import struct
import subprocess
import tempfile

BUNDLE_ID = "com.pajic.outrage.rockstar-launcher-test"
NAME = "Rockstar Games Launcher"


def patch_loader_identity(path: Path) -> None:
    data = bytearray(path.read_bytes())
    if len(data) < 32 or struct.unpack_from("<II", data) != (0xFEEDFACF, 0x01000007):
        raise ValueError("expected a thin x86-64 Wine Mach-O loader")
    pos = 32
    found = False
    for _ in range(struct.unpack_from("<I", data, 16)[0]):
        cmd, size = struct.unpack_from("<II", data, pos)
        if size < 8 or pos + size > len(data):
            raise ValueError("invalid Mach-O load command")
        if cmd == 0x19:
            for i in range(struct.unpack_from("<I", data, pos + 64)[0]):
                section = pos + 72 + 80 * i
                if section + 80 > pos + size:
                    raise ValueError("invalid Mach-O section table")
                if data[section:section + 16].split(b"\0")[0] != b"__info_plist":
                    continue
                length = struct.unpack_from("<Q", data, section + 40)[0]
                offset = struct.unpack_from("<I", data, section + 48)[0]
                if offset + length > len(data):
                    raise ValueError("invalid embedded plist range")
                info = plistlib.loads(bytes(data[offset:offset + length]).rstrip(b"\0"))
                if info.get("NSPrincipalClass") != "WineApplication":
                    raise ValueError("embedded plist is not the expected Wine application")
                info.update(CFBundleExecutable="wine", CFBundleIdentifier=BUNDLE_ID,
                            CFBundleName=NAME, LSUIElement=False)
                info.pop("CFBundleSignature", None)
                blob = plistlib.dumps(info)
                if len(blob) > length:
                    raise ValueError("identity exceeds the existing embedded plist section")
                data[offset:offset + length] = blob + b" " * (length - len(blob))
                found = True
        pos += size
    if not found:
        raise ValueError("Wine loader has no embedded application plist")
    path.write_bytes(data)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base_runtime", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    source = args.base_runtime.resolve()
    output = args.output.resolve()
    descriptor = json.loads((source / "runtime.json").read_text())
    if descriptor["id"] != "outrage-metal-context-test":
        raise ValueError("use the separately verified upstream context-test runtime")
    repo = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix="outRage-window-runtime-") as scratch:
        root = Path(scratch) / "runtime"
        shutil.copytree(source, root, symlinks=True)
        app = root / "bin" / (NAME + ".app")
        contents = app / "Contents"
        mac = contents / "MacOS"
        mac.mkdir(parents=True)
        for name in ("lib", "share", "bin"):
            shutil.copytree(source / name, contents / name, symlinks=True)
        # Wine execs this inner loader, not the front loader in bin/wine.
        inner = contents / "lib/wine/x86_64-unix/wine"
        shutil.copy2(inner, mac / "wine")
        inner.unlink()
        inner.symlink_to("../../../MacOS/wine")
        (mac / "ntdll.so").symlink_to("../lib/wine/x86_64-unix/ntdll.so")
        patch_loader_identity(mac / "wine")
        (contents / "Info.plist").write_bytes(plistlib.dumps({
            "CFBundleExecutable": "wine", "CFBundleIdentifier": BUNDLE_ID,
            "CFBundleName": NAME, "CFBundleDisplayName": NAME,
            "CFBundlePackageType": "APPL", "CFBundleVersion": "1",
            "NSHighResolutionCapable": True,
        }))
        subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", str(app)], check=True)
        subprocess.run(["/usr/bin/codesign", "--verify", "--strict", str(app)], check=True)
        subprocess.run(["/usr/bin/arch", "-x86_64", str(mac / "wine"), "--version"], check=True)
        descriptor["id"] = "outrage-metal-window-test"
        descriptor["executable"] = "bin/" + NAME + ".app/Contents/MacOS/wine"
        (root / "runtime.json").write_text(json.dumps(descriptor, indent=2) + "\n")
        subprocess.run(["swift", "run", "-c", "release", "outrage", "runtime-pack", str(root),
                        "26.3.0+dxmt.a148782-window-test.4", str(output)], cwd=repo, check=True)


if __name__ == "__main__":
    main()
