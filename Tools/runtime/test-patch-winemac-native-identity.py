#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile

PATCHER = Path(__file__).with_name("patch-winemac-native-identity.py")


def load_patcher():
    spec = importlib.util.spec_from_file_location("outrage_winemac_patch", PATCHER)
    if spec is None or spec.loader is None:
        raise RuntimeError("unable to load patcher")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def fixture() -> str:
    return """- (void) transformProcessToForeground:(BOOL)activateIfTransformed
{
    NSMenu* submenu;
    NSString* bundleName;
    NSMenuItem* item;
    submenu = [[[NSMenu alloc] initWithTitle:WineLocalizedString(STRING_MENU_WINE)] autorelease];
    bundleName = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleNameKey];
    item = [[[NSMenuItem alloc] init] autorelease];
    [item setTitle:WineLocalizedString(STRING_MENU_WINE)];
    [item setSubmenu:submenu];
}
"""


def main() -> int:
    patcher = load_patcher()
    with tempfile.TemporaryDirectory(prefix="outrage-winemac-test-") as raw:
        root = Path(raw)
        source = root / "dlls" / "winemac.drv" / "cocoa_app.m"
        source.parent.mkdir(parents=True)
        source.write_text(fixture(), encoding="utf-8")

        first = patcher.patch(root)
        once = first.read_text(encoding="utf-8")
        assert once.count("OUTRAGE_APP_NAME") == 1
        assert "setProcessName:outRageName" in once
        assert "[submenu setTitle:outRageName]" in once
        assert "[item setTitle:[bundleName length] ? bundleName : WineLocalizedString(STRING_MENU_WINE)]" in once

        second = patcher.patch(root)
        twice = second.read_text(encoding="utf-8")
        assert twice == once, "patch must be idempotent"

        broken = root / "broken"
        broken_source = broken / "dlls" / "winemac.drv" / "cocoa_app.m"
        broken_source.parent.mkdir(parents=True)
        broken_source.write_text("no expected anchors\n", encoding="utf-8")
        try:
            patcher.patch(broken)
        except RuntimeError as error:
            assert "anchor" in str(error)
        else:
            raise AssertionError("patch must fail closed when upstream anchors move")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
