/* Rockstar Launcher startup regression: DXMT v0.80 aborts on this call. */
#define COBJMACROS
#include <windows.h>
#include <d3d11_1.h>
#include <stdio.h>

int main(void) {
    ID3D11Device *device = NULL;
    ID3D11DeviceContext *context = NULL;
    ID3D11DeviceContext1 *context1 = NULL;
    ID3DDeviceContextState *previous = NULL;
    D3D_FEATURE_LEVEL level;
    const D3D_FEATURE_LEVEL levels[] = {D3D_FEATURE_LEVEL_11_0};
    HRESULT hr = D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0,
        levels, 1, D3D11_SDK_VERSION, &device, &level, &context);
    if (FAILED(hr)) {
        fprintf(stderr, "D3D11CreateDevice failed: 0x%08lx\n", (unsigned long)hr);
        return 2;
    }
    hr = ID3D11DeviceContext_QueryInterface(context, &IID_ID3D11DeviceContext1, (void **)&context1);
    if (FAILED(hr)) {
        fprintf(stderr, "ID3D11DeviceContext1 unavailable: 0x%08lx\n", (unsigned long)hr);
        ID3D11DeviceContext_Release(context);
        ID3D11Device_Release(device);
        return 3;
    }
    ID3D11DeviceContext1_SwapDeviceContextState(context1, NULL, &previous);
    if (previous) ID3DDeviceContextState_Release(previous);
    ID3D11DeviceContext1_Release(context1);
    ID3D11DeviceContext_Release(context);
    ID3D11Device_Release(device);
    puts("OUTRAGE_CONTEXT_SWAP_OK");
    return 0;
}
