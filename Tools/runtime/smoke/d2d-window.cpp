/* Own test window: verify Direct2D hardware target creation and EndDraw.
 * Does not read the desktop, other windows, or any vendor application data.
 */
#include <windows.h>
#include <d2d1.h>
#include <stdio.h>

int main() {
    WNDCLASSW wc = {};
    wc.lpfnWndProc = DefWindowProcW;
    wc.hInstance = GetModuleHandleW(NULL);
    wc.lpszClassName = L"outRageDirect2DProbe";
    if (!RegisterClassW(&wc)) return 2;
    HWND window = CreateWindowW(wc.lpszClassName, L"outRage Direct2D presentation probe",
        WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 500, 320,
        NULL, NULL, wc.hInstance, NULL);
    if (!window) return 3;
    ShowWindow(window, SW_SHOW);
    ID2D1Factory *factory = NULL;
    ID2D1HwndRenderTarget *target = NULL;
    HRESULT hr = D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, &factory);
    if (FAILED(hr)) { printf("D2D_FACTORY_FAIL hr=0x%08lx\n", (unsigned long)hr); return 4; }
    RECT r;
    GetClientRect(window, &r);
    hr = factory->CreateHwndRenderTarget(
        D2D1::RenderTargetProperties(D2D1_RENDER_TARGET_TYPE_HARDWARE),
        D2D1::HwndRenderTargetProperties(window, D2D1::SizeU(r.right, r.bottom)), &target);
    if (FAILED(hr)) { printf("D2D_TARGET_FAIL hr=0x%08lx\n", (unsigned long)hr); return 5; }
    target->BeginDraw();
    target->Clear(D2D1::ColorF(1.0f, 0.4f, 0.1f));
    hr = target->EndDraw();
    printf("OUTRAGE_D2D_END_DRAW hr=0x%08lx\n", (unsigned long)hr);
    DWORD start = GetTickCount();
    MSG msg;
    while (GetTickCount() - start < 3000) {
        while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
            TranslateMessage(&msg); DispatchMessageW(&msg);
        }
        Sleep(10);
    }
    target->Release(); factory->Release(); DestroyWindow(window);
    UnregisterClassW(wc.lpszClassName, wc.hInstance);
    if (FAILED(hr)) return 6;
    puts("OUTRAGE_D2D_WINDOW_OK");
    return 0;
}
