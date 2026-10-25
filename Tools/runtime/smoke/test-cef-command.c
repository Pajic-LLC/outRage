#include <assert.h>
#include <stdio.h>
#include "cef-command.h"
int main(void) {
    wchar_t out[1024];
    const wchar_t *real = L"C:\\Program Files\\Rockstar\\SocialClubHelper.outrage-original.exe";
    const wchar_t *raw = L"\"C:\\Program Files\\SocialClubHelper.exe\"\t--rgsc-ipc-channel-name=fixture --path=\"a b\\\\\" --handle=4294967295";
    const wchar_t *expected = L"\"C:\\Program Files\\Rockstar\\SocialClubHelper.outrage-original.exe\"\t--rgsc-ipc-channel-name=fixture --path=\"a b\\\\\" --handle=4294967295";
    assert(outrage_cef_command(raw, real, L"passthrough", out, 1024));
    assert(!wcscmp(out, expected));
    assert(outrage_cef_command(raw, real, L"software", out, 1024));
    assert(!wcsncmp(out, expected, wcslen(expected)));
    assert(!wcscmp(out + wcslen(expected), L" --disable-gpu --disable-gpu-compositing"));
    assert(outrage_cef_command(L"helper.exe --type=renderer", L"real.exe", L"swiftshader", out, 1024));
    assert(!wcscmp(out, L"\"real.exe\" --type=renderer --use-gl=angle --use-angle=swiftshader"));
    assert(!outrage_cef_command(raw, real, L"software", out, 10));
    assert(!outrage_cef_command(raw, real, L"unknown", out, 1024));
    assert(!outrage_cef_command(L"\"unterminated", real, L"software", out, 1024));
    assert(!outrage_cef_command(raw, L"bad\"path", L"software", out, 1024));
    puts("OUTRAGE_CEF_COMMAND_OK");
    return 0;
}
