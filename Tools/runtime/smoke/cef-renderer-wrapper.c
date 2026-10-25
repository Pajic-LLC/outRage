/* Developer-only renderer experiment, built from outRage source.
 * The original signed Rockstar helper is retained byte-for-byte beside this
 * executable. No auth/entitlement/security switches are added or removed.
 * CEF IPC handles and the raw vendor command line must survive the trampoline.
 */
#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#include <windows.h>
#include <wchar.h>
#include "cef-command.h"

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, PWSTR ignored, int show) {
    static wchar_t path[32768], command[32768], mode[32];
    const wchar_t *name = L"SocialClubHelper.outrage-original.exe";
    STARTUPINFOW startup;
    PROCESS_INFORMATION child = {0};
    DWORD code = 1;
    (void)instance; (void)previous; (void)ignored; (void)show;
    DWORD n = GetModuleFileNameW(NULL, path, 32768);
    if (!n || n >= 32768) return 120;
    wchar_t *slash = wcsrchr(path, L'\\');
    if (!slash || (size_t)(slash + 1 - path) + wcslen(name) + 1 > 32768) return 121;
    wcscpy(slash + 1, name);
    n = GetEnvironmentVariableW(L"OUTRAGE_CEF_RENDERER", mode, 32);
    if (!n) wcscpy(mode, L"passthrough");
    else if (n >= 32) return 122;
    if (!outrage_cef_command(GetCommandLineW(), path, mode, command, 32768)) return 123;
    GetStartupInfoW(&startup);
    if (!CreateProcessW(path, command, NULL, NULL, TRUE, 0, NULL, NULL, &startup, &child)) return 124;
    DWORD wait = WaitForSingleObject(child.hProcess, INFINITE);
    if (wait != WAIT_OBJECT_0 || !GetExitCodeProcess(child.hProcess, &code)) code = 125;
    CloseHandle(child.hThread);
    CloseHandle(child.hProcess);
    return (int)code;
}
