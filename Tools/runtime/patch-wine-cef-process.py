#!/usr/bin/env python3
"""Opt-in Social Club rendering compatibility in the pinned FOSS process loader.

Preserves the original executable, arguments, handles, auth and entitlement
checks. Only the browser process receives CEF's supported rendering switches.
"""
import argparse
from pathlib import Path

MARKER = "OUTRAGE_CEF_RENDERER"
ANCHOR = "    /* Warn if unsupported features are used */\n"
BLOCK = r'''    /* outRage: opt-in CEF rendering within the browser process. winemac
     * cannot present a swapchain owned by another Windows process. Do not
     * modify renderer/utility children or log any vendor arguments. */
    {
        WCHAR mode[32];
        const WCHAR *exe = wcsrchr( app_name, '\\' );
        static const WCHAR cef_flags[] = L" --in-process-gpu --use-gl=angle --use-angle=swiftshader";

        exe = exe ? exe + 1 : app_name;
        if (!wcsicmp( exe, L"SocialClubHelper.exe" ) &&
            GetEnvironmentVariableW( L"OUTRAGE_CEF_RENDERER", mode, ARRAY_SIZE(mode) ) == 9 &&
            !wcscmp( mode, L"inprocess" ) && !wcsstr( tidy_cmdline, L"--type=" ) &&
            !wcsstr( tidy_cmdline, L"--in-process-gpu" ))
        {
            SIZE_T count = lstrlenW( tidy_cmdline ) + ARRAY_SIZE(cef_flags);
            WCHAR *replacement;

            if (count > 32767) { status = STATUS_INVALID_PARAMETER; goto done; }
            replacement = RtlAllocateHeap( GetProcessHeap(), 0, count * sizeof(WCHAR) );
            if (!replacement) { status = STATUS_NO_MEMORY; goto done; }
            lstrcpyW( replacement, tidy_cmdline );
            lstrcatW( replacement, cef_flags );
            if (tidy_cmdline != cmd_line) HeapFree( GetProcessHeap(), 0, tidy_cmdline );
            tidy_cmdline = replacement;
            WARN( "outRage Social Club browser rendering enabled\n" );
        }
    }

'''


def patch(root: Path) -> Path:
    p = root / "dlls/kernelbase/process.c"
    s = p.read_text()
    if MARKER in s:
        return p
    if s.count(ANCHOR) != 1:
        raise ValueError("pinned CreateProcessInternalW anchor changed")
    p.write_text(s.replace(ANCHOR, BLOCK + ANCHOR, 1))
    return p


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_root", type=Path)
    args = parser.parse_args()
    print(patch(args.source_root))
