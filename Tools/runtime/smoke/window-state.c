/* Read-only runtime diagnostics: no window text, pixels, or input are captured. */
#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>
#include <string.h>

static unsigned int count;
static void process_name(DWORD pid, char *name, size_t size) {
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    PROCESSENTRY32 entry;
    entry.dwSize = sizeof(entry);
    name[0] = 0;
    if (snapshot == INVALID_HANDLE_VALUE) return;
    if (Process32First(snapshot, &entry)) do {
        if (entry.th32ProcessID == pid) {
            strncpy(name, entry.szExeFile, size - 1);
            name[size - 1] = 0;
            break;
        }
    } while (Process32Next(snapshot, &entry));
    CloseHandle(snapshot);
}
static BOOL CALLBACK window_state(HWND window, LPARAM unused) {
    DWORD pid;
    RECT rect;
    char name[128] = {0}, class_name[128] = {0};
    (void)unused;
    GetWindowThreadProcessId(window, &pid);
    process_name(pid, name, sizeof(name));
    if (!strstr(name, "Launcher") && !strstr(name, "SocialClub") && !strstr(name, "explorer")) return TRUE;
    GetClassNameA(window, class_name, sizeof(class_name));
    if (!GetWindowRect(window, &rect)) return TRUE;
    printf("pid=%lu exe=%s class=%s visible=%d minimized=%d rect=%ld,%ld,%ld,%ld style=0x%llx exstyle=0x%llx\n",
        (unsigned long)pid, name, class_name, IsWindowVisible(window), IsIconic(window),
        rect.left, rect.top, rect.right, rect.bottom,
        (unsigned long long)(ULONG_PTR)GetWindowLongPtrA(window, GWL_STYLE),
        (unsigned long long)(ULONG_PTR)GetWindowLongPtrA(window, GWL_EXSTYLE));
    count++;
    return TRUE;
}
int main(void) {
    printf("desktop=%d,%d,%d,%d\n", GetSystemMetrics(SM_XVIRTUALSCREEN), GetSystemMetrics(SM_YVIRTUALSCREEN),
        GetSystemMetrics(SM_CXVIRTUALSCREEN), GetSystemMetrics(SM_CYVIRTUALSCREEN));
    if (!EnumWindows(window_state, 0)) return 2;
    printf("OUTRAGE_WINDOW_STATE_OK count=%u\n", count);
    return 0;
}
