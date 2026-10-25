#!/usr/bin/env python3
"""Opt-in native window diagnostics for the pinned developer Wine runtime.

Records only geometry/state in Wine's own windows. No titles, pixels, other
applications, credentials or input are read. Does not change window behavior.
"""
import argparse
from pathlib import Path

MARKER = "OUTRAGE_WINDOW_DIAGNOSTICS"
METHOD = r'''
    /* outRage developer diagnostic; this method runs on the Cocoa main thread. */
    - (void) outRageWindowState:(const char*)event
    {
        static unsigned int records;
        const char *enabled = getenv("OUTRAGE_WINDOW_DIAGNOSTICS");
        if (!enabled || strcmp(enabled, "1") || records++ >= 128) return;
        NSRect f = self.frame;
        fprintf(stderr, "OUTRAGE_WINDOW event=%s pid=%ld hwnd=%p number=%ld "
                "frame=%.1f,%.1f,%.1f,%.1f visible=%d mini=%d activeSpace=%d "
                "occluded=%d alpha=%.3f opaque=%d emptyShape=%d drawn=%d "
                "appHidden=%d appActive=%d level=%ld layerHidden=%d\n",
                event, (long)getpid(), self.hwnd, (long)self.windowNumber,
                f.origin.x, f.origin.y, f.size.width, f.size.height,
                self.isVisible, self.isMiniaturized, self.isOnActiveSpace,
                !(self.occlusionState & NSWindowOcclusionStateVisible), self.alphaValue,
                self.isOpaque, self.isEmptyShaped, self.drawnSinceShown,
                NSApp.isHidden, NSApp.isActive, (long)self.level,
                self.contentView.layer.isHidden);
        fflush(stderr);
    }

'''


def patch(root: Path) -> Path:
    p = root / "dlls/winemac.drv/cocoa_window.m"
    s = p.read_text()
    if MARKER in s:
        return p
    replacements = [
        ('#include <dlfcn.h>\n', '#include <dlfcn.h>\n#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n#include <unistd.h>\n'),
        ('@implementation WineWindow\n', '@implementation WineWindow\n' + METHOD),
        ('            NSEnableScreenUpdates();\n\n            /* Cocoa may adjust', '''            NSEnableScreenUpdates();
            [self outRageWindowState:"ordered"];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self outRageWindowState:"ordered-later"];
            });

            /* Cocoa may adjust'''),
        ('            drawnSinceShown = YES;\n', '            drawnSinceShown = YES;\n            [self outRageWindowState:"first-draw"];\n'),
        ('        drawnSinceShown = NO;\n', '        drawnSinceShown = NO;\n        [self outRageWindowState:"ordered-out"];\n'),
    ]
    for old, new in replacements:
        if s.count(old) != 1:
            raise ValueError(f"pinned winemac anchor changed: {old!r}")
        s = s.replace(old, new, 1)
    p.write_text(s)
    return p


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_root", type=Path)
    args = parser.parse_args()
    print(patch(args.source_root))
