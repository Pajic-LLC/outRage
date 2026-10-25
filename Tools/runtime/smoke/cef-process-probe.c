/* Exercise the FOSS process patch without Rockstar code or account data. */
#ifndef UNICODE
#define UNICODE
#endif
#include <windows.h>
#include <stdio.h>
#include <wchar.h>
#include <stdint.h>
#include <stdlib.h>

static unsigned int occurrences(const wchar_t *text, const wchar_t *needle) {
    unsigned int n = 0;
    while ((text = wcsstr(text, needle))) { n++; text += wcslen(needle); }
    return n;
}

static int child(int argc, wchar_t **argv) {
    HANDLE event = NULL;
    int marker = 0;
    for (int i = 2; i < argc; i++) {
        if (!wcsncmp(argv[i], L"--event=", 8))
            event = (HANDLE)(uintptr_t)wcstoull(argv[i] + 8, NULL, 10);
        if (!wcscmp(argv[i], L"--marker=two words \x96e8")) marker = 1;
    }
    if (!marker || !event || !SetEvent(event)) return 90;
    const wchar_t *cmd = GetCommandLineW();
    unsigned int a = occurrences(cmd, L"--in-process-gpu");
    unsigned int b = occurrences(cmd, L"--use-gl=angle");
    unsigned int c = occurrences(cmd, L"--use-angle=swiftshader");
    if (a > 1 || b > 1 || c > 1) return 91;
    return (a ? 1 : 0) | (b ? 2 : 0) | (c ? 4 : 0);
}

static int run_case(const wchar_t *path, const wchar_t *extra, const wchar_t *mode,
                    DWORD expected, const char *label) {
    SECURITY_ATTRIBUTES sa = {sizeof(sa), NULL, TRUE};
    HANDLE event = CreateEventW(&sa, TRUE, FALSE, NULL);
    STARTUPINFOW startup = {0};
    PROCESS_INFORMATION process = {0};
    wchar_t command[32768];
    DWORD code = 92;
    startup.cb = sizeof(startup);
    if (!event) return 1;
    SetEnvironmentVariableW(L"OUTRAGE_CEF_RENDERER", mode);
    int n = swprintf(command, 32768, L"\"%ls\" --child --event=%llu --marker=\"two words \x96e8\" %ls",
        path, (unsigned long long)(uintptr_t)event, extra);
    if (n < 0 || n >= 32768 || !CreateProcessW(path, command, NULL, NULL, TRUE, 0, NULL, NULL, &startup, &process)) {
        CloseHandle(event); return 2;
    }
    DWORD wait = WaitForSingleObject(process.hProcess, 15000);
    if (wait == WAIT_TIMEOUT) TerminateProcess(process.hProcess, 93);
    GetExitCodeProcess(process.hProcess, &code);
    int signalled = WaitForSingleObject(event, 0) == WAIT_OBJECT_0;
    CloseHandle(process.hThread); CloseHandle(process.hProcess); CloseHandle(event);
    if (wait != WAIT_OBJECT_0 || code != expected || !signalled) {
        printf("CEF_PROCESS_CASE_FAIL name=%s exit=%lu expected=%lu inherited_event=%d\n",
            label, (unsigned long)code, (unsigned long)expected, signalled);
        return 3;
    }
    printf("CEF_PROCESS_CASE_OK name=%s flags=%lu inherited_event=1 unicode_marker=1\n", label, (unsigned long)code);
    return 0;
}

int wmain(int argc, wchar_t **argv) {
    if (argc > 1 && !wcscmp(argv[1], L"--child")) return child(argc, argv);
    wchar_t self[32768], helper[32768], other[32768];
    DWORD n = GetModuleFileNameW(NULL, self, 32768);
    if (!n || n >= 32768) return 10;
    wchar_t *slash = wcsrchr(self, L'\\');
    if (!slash || wcsstr(self, L"Rockstar Games")) return 11;
    size_t prefix = (size_t)(slash + 1 - self);
    if (prefix + 32 >= 32768) return 12;
    wmemcpy(helper, self, prefix); wcscpy(helper + prefix, L"SocialClubHelper.exe");
    wmemcpy(other, self, prefix); wcscpy(other + prefix, L"UnrelatedHelper.exe");
    if (!CopyFileW(self, helper, FALSE) || !CopyFileW(self, other, FALSE)) return 13;
    if (run_case(helper, L"", L"inprocess", 7, "browser-opt-in")) return 20;
    if (run_case(helper, L"", NULL, 0, "default-unmodified")) return 21;
    if (run_case(other, L"", L"inprocess", 0, "unrelated-unmodified")) return 22;
    if (run_case(helper, L"--type=renderer", L"inprocess", 0, "renderer-unmodified")) return 23;
    if (run_case(helper, L"--in-process-gpu --use-gl=angle --use-angle=swiftshader", L"inprocess", 7, "no-duplicates")) return 24;
    puts("OUTRAGE_CEF_PROCESS_OK");
    return 0;
}
