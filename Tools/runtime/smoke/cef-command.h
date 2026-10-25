/* Developer-only CEF rendering probe. Preserve the vendor's raw arguments. */
#ifndef OUTRAGE_CEF_COMMAND_H
#define OUTRAGE_CEF_COMMAND_H
#include <stddef.h>
#include <wchar.h>

static int outrage_cef_command(const wchar_t *original, const wchar_t *real,
                               const wchar_t *mode, wchar_t *out, size_t capacity) {
    const wchar_t *args = original;
    const wchar_t *flags;
    if (!wcscmp(mode, L"software"))
        flags = L" --disable-gpu --disable-gpu-compositing";
    else if (!wcscmp(mode, L"inprocess"))
        flags = L" --in-process-gpu";
    else if (!wcscmp(mode, L"swiftshader"))
        flags = L" --use-gl=angle --use-angle=swiftshader";
    else if (!wcscmp(mode, L"passthrough"))
        flags = L"";
    else return 0;
    while (*args == L' ' || *args == L'\t') args++;
    if (*args == L'\"') {
        args++;
        while (*args && *args != L'\"') args++;
        if (!*args) return 0;
        args++;
    } else {
        while (*args && *args != L' ' && *args != L'\t') args++;
    }
    /* Quotes in an executable path cannot be represented by this wrapper. */
    if (wcschr(real, L'\"')) return 0;
    size_t nr = wcslen(real), na = wcslen(args), nf = wcslen(flags);
    if (nr + na + nf + 3 > capacity) return 0;
    out[0] = L'\"';
    wmemcpy(out + 1, real, nr);
    out[nr + 1] = L'\"';
    wmemcpy(out + nr + 2, args, na);
    wmemcpy(out + nr + 2 + na, flags, nf + 1);
    return 1;
}
#endif
