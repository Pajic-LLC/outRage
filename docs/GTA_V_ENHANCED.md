# GTA V Enhanced — experimental Rockstar path

The owner selected Enhanced as the active target on 2026-10-25. Legacy remains a separate recipe and is no longer the current gameplay milestone. GTA VI is a future research target; shared RAGE/Direct3D work does not establish compatibility with an unreleased PC build.

The owner confirmed the Rockstar library is visible after direct sign-in. The live launcher uses the native activation handoff, scoped Wine graphics fallback, and CEF in-process rendering. Preserve that session during download. Credentials remain in Rockstar's UI.

`Profiles/gta-v-enhanced-rockstar.json` names the locally observed `GTA5_Enhanced.exe`, selects a separately identified Mullion developer runtime, and maps the conventional Enhanced install folder into its own managed target. The original Legacy profile is retained. Profile validation is not a game support claim.

## Candidate backend

[Mullion v0.4](https://github.com/dttdrv/mullion/releases/tag/v0.4) is a pre-release Direct3D 10/11/12 implementation on Metal. Its release explicitly adds M1/M2 support. Upstream reports D3D12 feature level 12_0 and shader model 6.7; GTA V Enhanced has not been verified by outRage. D3D11 video decoding/processing is listed as incomplete.

- Source commit: `7bcdcb4437f745ba9d5b6b876c9521008388296c`.
- Official release asset: `mullion-v0.4.tar.gz`.
- Asset SHA-256: `3109e3f15561eda659f04049f2e2cfb187d634cfb9fff96dac6ff1b02ae9932e`.
- Runtime ID: `outrage-metal-mullion-test`.
- License: LGPL 2.1 or later, with included upstream notices and LLVM license.

The developer composer verifies that exact asset, checks archive paths/types and Wine builtin module markers, copies the existing engine into a new directory, installs six backend DLLs plus `winemetal.so`, signs/verifies the new Mach-O library, and carries license/provenance files. It never executes the downloaded install script or edits its input engine. The resulting package is for an already initialized prefix and deliberately omits a prefix initializer. Fresh-prefix product setup remains a separate acceptance gate.

```sh
python3 Tools/runtime/build-mullion-test-runtime.py \
  /path/to/verified-engine /path/to/mullion-v0.4.tar.gz /path/to/new-stage
bash Tools/runtime/audit-runtime-dylibs.sh /path/to/new-stage
.build/release/outrage runtime-pack /path/to/new-stage \
  '26.3.0+mullion.0.4-test.1' /path/to/packages
```

The new `mullion` backend is explicitly selectable and eligible for D3D12 auto resolution only when the runtime advertises it. A DXMT-only runtime remains ineligible for D3D12. Mullion uses a separate shader/log cache and does not receive the D3D11-specific DXMT frame-pacing/MetalFX policy.

## Proof gates

`Tools/runtime/smoke/d3d12-copy.c` enumerates a hardware adapter, requires feature level 12_0, submits a patterned 4096-byte buffer copy, waits on a bounded GPU fence, compares readback, and checks device removal. A successful result establishes that operation only; shaders, presentation, and game workloads need additional proof.

Before switching the signed-in title prefix, pass the portability audit and this probe in a separate scratch prefix. Keep the working launcher untouched while downloading. The first partial download was Enhanced in the original test prefix; do not move active download files into the new target path. Migrate or map them only after the download is stopped and the source/destination state is verified.

Use Rockstar's documented Story Mode BattlEye option for offline Story Mode testing. No anti-cheat, ownership, or authentication bypass is part of this recipe. Keep arguments empty until the actual vendor launch path is observed.

Remaining acceptance: complete official download/verification, backend shader and presentation proof, legitimate game launch, first Story Mode frame, input/audio/saves, clean quit, repeat launch, and production runtime/packaging provenance.
