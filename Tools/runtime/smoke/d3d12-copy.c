#define COBJMACROS
#include <windows.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <stdio.h>
#include <string.h>

#define CHECK(call) do { HRESULT hr_ = (call); if (FAILED(hr_)) { \
    fprintf(stderr, "%s failed: 0x%08lx\n", #call, (unsigned long)hr_); return 1; } } while (0)

int main(void) {
    IDXGIFactory4 *factory = NULL;
    IDXGIAdapter1 *adapter = NULL;
    ID3D12Device *device = NULL;
    CHECK(CreateDXGIFactory1(&IID_IDXGIFactory4, (void **)&factory));
    for (UINT i = 0; IDXGIFactory4_EnumAdapters1(factory, i, &adapter) != DXGI_ERROR_NOT_FOUND; ++i) {
        DXGI_ADAPTER_DESC1 desc;
        CHECK(IDXGIAdapter1_GetDesc1(adapter, &desc));
        if (!(desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) &&
            SUCCEEDED(D3D12CreateDevice((IUnknown *)adapter, D3D_FEATURE_LEVEL_12_0,
                                       &IID_ID3D12Device, (void **)&device))) {
            printf("hardware adapter vendor=0x%04x device=0x%04x feature=12_0\n", desc.VendorId, desc.DeviceId);
            break;
        }
        IDXGIAdapter1_Release(adapter);
        adapter = NULL;
    }
    if (!device) { fprintf(stderr, "No hardware D3D12 feature-level-12_0 device\n"); return 2; }
    ID3D12CommandQueue *queue = NULL;
    D3D12_COMMAND_QUEUE_DESC qd = {0};
    qd.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
    CHECK(ID3D12Device_CreateCommandQueue(device, &qd, &IID_ID3D12CommandQueue, (void **)&queue));
    ID3D12CommandAllocator *allocator = NULL;
    CHECK(ID3D12Device_CreateCommandAllocator(device, qd.Type, &IID_ID3D12CommandAllocator, (void **)&allocator));
    ID3D12GraphicsCommandList *list = NULL;
    CHECK(ID3D12Device_CreateCommandList(device, 0, qd.Type, allocator, NULL,
                                        &IID_ID3D12GraphicsCommandList, (void **)&list));
    D3D12_RESOURCE_DESC rd = {0};
    rd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    rd.Width = 4096; rd.Height = 1; rd.DepthOrArraySize = 1;
    rd.MipLevels = 1; rd.SampleDesc.Count = 1; rd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    D3D12_HEAP_PROPERTIES hp = {0};
    hp.Type = D3D12_HEAP_TYPE_UPLOAD;
    ID3D12Resource *upload = NULL, *readback = NULL;
    CHECK(ID3D12Device_CreateCommittedResource(device, &hp, D3D12_HEAP_FLAG_NONE, &rd,
          D3D12_RESOURCE_STATE_GENERIC_READ, NULL, &IID_ID3D12Resource, (void **)&upload));
    hp.Type = D3D12_HEAP_TYPE_READBACK;
    CHECK(ID3D12Device_CreateCommittedResource(device, &hp, D3D12_HEAP_FLAG_NONE, &rd,
          D3D12_RESOURCE_STATE_COPY_DEST, NULL, &IID_ID3D12Resource, (void **)&readback));
    unsigned char expected[4096];
    for (unsigned i = 0; i < sizeof(expected); ++i) expected[i] = (unsigned char)(i * 37 + 11);
    void *mapped = NULL;
    D3D12_RANGE empty = {0, 0}, full = {0, sizeof(expected)};
    CHECK(ID3D12Resource_Map(upload, 0, &empty, &mapped));
    memcpy(mapped, expected, sizeof(expected));
    ID3D12Resource_Unmap(upload, 0, &full);
    ID3D12GraphicsCommandList_CopyBufferRegion(list, readback, 0, upload, 0, sizeof(expected));
    CHECK(ID3D12GraphicsCommandList_Close(list));
    ID3D12CommandList *submitted = (ID3D12CommandList *)list;
    ID3D12CommandQueue_ExecuteCommandLists(queue, 1, &submitted);
    ID3D12Fence *fence = NULL;
    CHECK(ID3D12Device_CreateFence(device, 0, D3D12_FENCE_FLAG_NONE, &IID_ID3D12Fence, (void **)&fence));
    HANDLE event = CreateEventW(NULL, FALSE, FALSE, NULL);
    if (!event) return 3;
    CHECK(ID3D12Fence_SetEventOnCompletion(fence, 1, event));
    CHECK(ID3D12CommandQueue_Signal(queue, fence, 1));
    if (WaitForSingleObject(event, 30000) != WAIT_OBJECT_0) { fprintf(stderr, "GPU fence timed out\n"); return 4; }
    CHECK(ID3D12Resource_Map(readback, 0, &full, &mapped));
    int equal = memcmp(mapped, expected, sizeof(expected)) == 0;
    ID3D12Resource_Unmap(readback, 0, &empty);
    CHECK(ID3D12Device_GetDeviceRemovedReason(device));
    CloseHandle(event);
    ID3D12Fence_Release(fence); ID3D12Resource_Release(readback); ID3D12Resource_Release(upload);
    ID3D12GraphicsCommandList_Release(list); ID3D12CommandAllocator_Release(allocator);
    ID3D12CommandQueue_Release(queue); ID3D12Device_Release(device);
    IDXGIAdapter1_Release(adapter); IDXGIFactory4_Release(factory);
    if (!equal) { fprintf(stderr, "GPU readback differs\n"); return 5; }
    puts("OUTRAGE_D3D12_COPY_OK bytes=4096 fence=1 hardware=1");
    return 0;
}
