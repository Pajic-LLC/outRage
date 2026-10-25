#define WIN32_LEAN_AND_MEAN
#include <windows.h>

int WINAPI WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command_line, int show_command)
{
    (void)instance;
    (void)previous;
    (void)command_line;
    (void)show_command;

    LARGE_INTEGER counter;
    if (!QueryPerformanceCounter(&counter)) return 2;

    SYSTEM_INFO info;
    GetNativeSystemInfo(&info);
    if (!info.dwNumberOfProcessors) return 3;

    return 0;
}
