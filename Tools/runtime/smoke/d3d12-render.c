#define COBJMACROS
#include <windows.h>
#include <d3d12.h>
#include <d3dcompiler.h>
#include <stdio.h>
#include <string.h>

#define CHECK(call) do { HRESULT hr_ = (call); if (FAILED(hr_)) { \
    fprintf(stderr, "%s failed: 0x%08lx\n", #call, (unsigned long)hr_); return 1; } } while (0)

int main(void) {
    ID3D12Device *device = NULL;
    CHECK(D3D12CreateDevice(NULL, D3D_FEATURE_LEVEL_12_0, &IID_ID3D12Device, (void **)&device));
    const char *vs = "float4 main(uint id:SV_VertexID):SV_Position { float2 p[3]={float2(-1,-1),float2(-1,3),float2(3,-1)}; return float4(p[id],0,1); }";
    const char *ps = "float4 main():SV_Target { return float4(1,0,0,1); }";
    ID3DBlob *vertex = NULL, *pixel = NULL, *serialized = NULL;
    CHECK(D3DCompile(vs, strlen(vs), "own-vs", NULL, NULL, "main", "vs_5_0", 0, 0, &vertex, NULL));
    CHECK(D3DCompile(ps, strlen(ps), "own-ps", NULL, NULL, "main", "ps_5_0", 0, 0, &pixel, NULL));
    D3D12_ROOT_SIGNATURE_DESC rootDesc = {0};
    CHECK(D3D12SerializeRootSignature(&rootDesc, D3D_ROOT_SIGNATURE_VERSION_1, &serialized, NULL));
    ID3D12RootSignature *root = NULL;
    CHECK(ID3D12Device_CreateRootSignature(device, 0, ID3D10Blob_GetBufferPointer(serialized),
          ID3D10Blob_GetBufferSize(serialized), &IID_ID3D12RootSignature, (void **)&root));
    D3D12_GRAPHICS_PIPELINE_STATE_DESC pd = {0};
    pd.pRootSignature = root;
    pd.VS.pShaderBytecode = ID3D10Blob_GetBufferPointer(vertex);
    pd.VS.BytecodeLength = ID3D10Blob_GetBufferSize(vertex);
    pd.PS.pShaderBytecode = ID3D10Blob_GetBufferPointer(pixel);
    pd.PS.BytecodeLength = ID3D10Blob_GetBufferSize(pixel);
    pd.BlendState.RenderTarget[0].RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL;
    pd.SampleMask = ~0u;
    pd.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID;
    pd.RasterizerState.CullMode = D3D12_CULL_MODE_NONE;
    pd.RasterizerState.DepthClipEnable = TRUE;
    pd.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
    pd.NumRenderTargets = 1; pd.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM; pd.SampleDesc.Count = 1;
    ID3D12PipelineState *pipeline = NULL;
    CHECK(ID3D12Device_CreateGraphicsPipelineState(device, &pd, &IID_ID3D12PipelineState, (void **)&pipeline));
    D3D12_RESOURCE_DESC td = {0};
    td.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE2D; td.Width = 16; td.Height = 16;
    td.DepthOrArraySize = 1; td.MipLevels = 1; td.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    td.SampleDesc.Count = 1; td.Flags = D3D12_RESOURCE_FLAG_ALLOW_RENDER_TARGET;
    D3D12_HEAP_PROPERTIES hp = {0}; hp.Type = D3D12_HEAP_TYPE_DEFAULT;
    ID3D12Resource *texture = NULL, *readback = NULL;
    CHECK(ID3D12Device_CreateCommittedResource(device, &hp, D3D12_HEAP_FLAG_NONE, &td,
          D3D12_RESOURCE_STATE_RENDER_TARGET, NULL, &IID_ID3D12Resource, (void **)&texture));
    D3D12_PLACED_SUBRESOURCE_FOOTPRINT footprint;
    UINT64 total = 0;
    ID3D12Device_GetCopyableFootprints(device, &td, 0, 1, 0, &footprint, NULL, NULL, &total);
    D3D12_RESOURCE_DESC bd = {0};
    bd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER; bd.Width = total; bd.Height = 1;
    bd.DepthOrArraySize = 1; bd.MipLevels = 1; bd.SampleDesc.Count = 1; bd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    hp.Type = D3D12_HEAP_TYPE_READBACK;
    CHECK(ID3D12Device_CreateCommittedResource(device, &hp, D3D12_HEAP_FLAG_NONE, &bd,
          D3D12_RESOURCE_STATE_COPY_DEST, NULL, &IID_ID3D12Resource, (void **)&readback));
    D3D12_DESCRIPTOR_HEAP_DESC hd = {0}; hd.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV; hd.NumDescriptors = 1;
    ID3D12DescriptorHeap *heap = NULL;
    CHECK(ID3D12Device_CreateDescriptorHeap(device, &hd, &IID_ID3D12DescriptorHeap, (void **)&heap));
    D3D12_CPU_DESCRIPTOR_HANDLE rtv;
    ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(heap, &rtv);
    ID3D12Device_CreateRenderTargetView(device, texture, NULL, rtv);
    D3D12_COMMAND_QUEUE_DESC qd = {0}; qd.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
    ID3D12CommandQueue *queue = NULL;
    ID3D12CommandAllocator *allocator = NULL;
    ID3D12GraphicsCommandList *list = NULL;
    CHECK(ID3D12Device_CreateCommandQueue(device, &qd, &IID_ID3D12CommandQueue, (void **)&queue));
    CHECK(ID3D12Device_CreateCommandAllocator(device, qd.Type, &IID_ID3D12CommandAllocator, (void **)&allocator));
    CHECK(ID3D12Device_CreateCommandList(device, 0, qd.Type, allocator, pipeline,
          &IID_ID3D12GraphicsCommandList, (void **)&list));
    ID3D12GraphicsCommandList_SetGraphicsRootSignature(list, root);
    D3D12_VIEWPORT viewport = {0, 0, 16, 16, 0, 1};
    D3D12_RECT scissor = {0, 0, 16, 16};
    ID3D12GraphicsCommandList_RSSetViewports(list, 1, &viewport);
    ID3D12GraphicsCommandList_RSSetScissorRects(list, 1, &scissor);
    ID3D12GraphicsCommandList_OMSetRenderTargets(list, 1, &rtv, FALSE, NULL);
    const FLOAT blue[4] = {0, 0, 1, 1};
    ID3D12GraphicsCommandList_ClearRenderTargetView(list, rtv, blue, 0, NULL);
    ID3D12GraphicsCommandList_IASetPrimitiveTopology(list, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    ID3D12GraphicsCommandList_DrawInstanced(list, 3, 1, 0, 0);
    D3D12_RESOURCE_BARRIER barrier = {0}; barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barrier.Transition.pResource = texture; barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
    barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_COPY_SOURCE;
    ID3D12GraphicsCommandList_ResourceBarrier(list, 1, &barrier);
    D3D12_TEXTURE_COPY_LOCATION src = {0}, dst = {0};
    src.pResource = texture; src.Type = D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;
    dst.pResource = readback; dst.Type = D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT; dst.PlacedFootprint = footprint;
    ID3D12GraphicsCommandList_CopyTextureRegion(list, &dst, 0, 0, 0, &src, NULL);
    CHECK(ID3D12GraphicsCommandList_Close(list));
    ID3D12CommandList *submitted = (ID3D12CommandList *)list;
    ID3D12CommandQueue_ExecuteCommandLists(queue, 1, &submitted);
    ID3D12Fence *fence = NULL;
    CHECK(ID3D12Device_CreateFence(device, 0, D3D12_FENCE_FLAG_NONE, &IID_ID3D12Fence, (void **)&fence));
    HANDLE event = CreateEventW(NULL, FALSE, FALSE, NULL); if (!event) return 2;
    CHECK(ID3D12Fence_SetEventOnCompletion(fence, 1, event));
    CHECK(ID3D12CommandQueue_Signal(queue, fence, 1));
    if (WaitForSingleObject(event, 30000) != WAIT_OBJECT_0) return 3;
    BYTE *pixels = NULL; D3D12_RANGE range = {0, (SIZE_T)total}, empty = {0, 0};
    CHECK(ID3D12Resource_Map(readback, 0, &range, (void **)&pixels));
    unsigned matched = 0;
    for (UINT y = 0; y < 16; ++y) for (UINT x = 0; x < 16; ++x) {
        BYTE *p = pixels + footprint.Offset + y * footprint.Footprint.RowPitch + x * 4;
        if (p[0] == 255 && p[1] == 0 && p[2] == 0 && p[3] == 255) ++matched;
    }
    ID3D12Resource_Unmap(readback, 0, &empty);
    CHECK(ID3D12Device_GetDeviceRemovedReason(device));
    CloseHandle(event);
    ID3D12Fence_Release(fence); ID3D12GraphicsCommandList_Release(list); ID3D12CommandAllocator_Release(allocator);
    ID3D12CommandQueue_Release(queue); ID3D12DescriptorHeap_Release(heap);
    ID3D12Resource_Release(readback); ID3D12Resource_Release(texture);
    ID3D12PipelineState_Release(pipeline); ID3D12RootSignature_Release(root);
    ID3D10Blob_Release(serialized); ID3D10Blob_Release(pixel); ID3D10Blob_Release(vertex); ID3D12Device_Release(device);
    if (matched != 256) { fprintf(stderr, "Red shader pixels: %u/256\n", matched); return 4; }
    puts("OUTRAGE_D3D12_RENDER_OK pixels=256 shaders=vs_5_0,ps_5_0 fence=1");
    return 0;
}
