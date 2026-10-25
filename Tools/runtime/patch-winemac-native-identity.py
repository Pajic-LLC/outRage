#!/usr/bin/env python3
"""Patch winemac to honor outRage's per-launch native display identity.

The patch is intentionally tiny and generic: the compatibility runtime receives
OUTRAGE_APP_NAME from the host and uses it for the macOS process/menu identity.
The Windows application remains responsible for its own window title and icon.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

NAME_ENV = "OUTRAGE_APP_NAME"


def patch(source_root: Path) -> Path:
    path = source_root / "dlls" / "winemac.drv" / "cocoa_app.m"
    if not path.is_file():
        raise RuntimeError(f"winemac source not found: {path}")

    text = path.read_text(encoding="utf-8")
    if NAME_ENV in text:
        return path

    bundle_anchor = (
        "    bundleName = [[NSBundle mainBundle] "
        "objectForInfoDictionaryKey:(NSString*)kCFBundleNameKey];\n"
    )
    if bundle_anchor not in text:
        raise RuntimeError("winemac bundle-name anchor not found")

    identity_block = bundle_anchor + (
        "    NSString* outRageName = [[[NSProcessInfo processInfo] environment] "
        f"objectForKey:@\"{NAME_ENV}\"];\n"
        "    if ([outRageName length])\n"
        "    {\n"
        "        bundleName = outRageName;\n"
        "        [[NSProcessInfo processInfo] setProcessName:outRageName];\n"
        "        [submenu setTitle:outRageName];\n"
        "    }\n"
    )
    text = text.replace(bundle_anchor, identity_block, 1)

    menu_anchor = "    [item setTitle:WineLocalizedString(STRING_MENU_WINE)];\n"
    if menu_anchor not in text:
        raise RuntimeError("winemac application-menu anchor not found")
    menu_replacement = (
        "    [item setTitle:[bundleName length] ? bundleName : "
        "WineLocalizedString(STRING_MENU_WINE)];\n"
    )
    text = text.replace(menu_anchor, menu_replacement, 1)

    path.write_text(text, encoding="utf-8")
    return path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    args = parser.parse_args()

    try:
        patched = patch(args.source_root.resolve())
    except Exception as exc:  # noqa: BLE001 - command-line boundary
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(patched)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
