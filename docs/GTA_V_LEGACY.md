# GTA V Legacy — Rockstar reference path

This is an **experimental engineering recipe**, not a supported game release. The first target is Story Mode from Rockstar ownership. Online/anti-cheat compatibility is unproven; do not bypass vendor authentication, entitlement, or anti-cheat checks.

`Profiles/gta-v-legacy-rockstar.json` selects the Rosetta CPU path, DXMT graphics, the real Rockstar Games Launcher, `GTA5.exe` process adoption, and isolated managed storage. It maps the launcher's conventional `C:\Program Files\Rockstar Games\Grand Theft Auto V` directory to the title target root. No undocumented product launch switches or unverified bootstrap executable are configured.

## Installer provenance

- Official download: <https://gamedownloads.rockstargames.com/public/installer/Rockstar-Games-Launcher.exe>
- Retrieved: 2026-10-25.
- Observed architecture: PE32+, x86-64.
- SHA-256: `321886457b7e4ab727a27671c17a815684a3943579eedf7e2248a3b9f0973746`.
- The vendor binary is **not** included in the repository or generated app.

The official installer contains `Rockstar Games\Launcher`, `Launcher.exe`, and `Rockstar Games\Grand Theft Auto V` strings. These inform the recipe; actual installation paths and game process behavior still require live verification. Rockstar documents the default launcher directory in its [clean-install instructions](https://support.rockstargames.com/articles/R7owe3DsZk292LuFj8OaX/how-to-perform-a-clean-install-of-the-rockstar-games-launcher).

A changed installer download must fail checksum validation until a maintainer deliberately verifies and updates the pin. Credentials must be entered directly into Rockstar's UI, never into outRage configuration or diagnostics.

## Story Mode vendor setting

Rockstar documents a BattlEye option in the Rockstar Games Launcher for Story Mode. Use that vendor setting during the Story Mode proof; do not patch the anti-cheat or attempt to enter GTA Online without its required protection. The recipe leaves game launch arguments empty until the actual launch path is verified.

Sources: [Rockstar's BattlEye FAQ](https://support.rockstargames.com/articles/1nenwhZlVrJY6CTFeSS2Fx/grand-theft-auto-online-battleye-faq), [Title Update 1.69 notes](https://support.rockstargames.com/articles/eUgRHVRSN2V9gimBT32YX/gtav-title-update-1-69-notes-ps5-ps4-xbox-series-x-s-xbox-one-pc). Rockstar also documents the conventional GTA V installation directory in its [current troubleshooting instructions](https://support.rockstargames.com/articles/ocorZr1KpQE8WvoHE3gBG/battleye-troubleshooting-for-grand-theft-auto-v).

## Required runtime and proof

Install the exact `26.3.0+v0.80-launcher.1` package that passes the dependency-integrated build, portability audit, DXMT module-load, D3D11 device-creation, and Windows-execution gates. The reference profile currently selects by runtime ID; it does not enforce package-version ranges. Do not use a previously installed stripped foundation runtime for this test. No release runtime download is configured in this developer profile.

That package passed all gates in [runtime run 40187466116](https://github.com/Pajic-LLC/outRage/actions/runs/40187466116) at `659a9fa`. Its ZIP SHA-256 is `768d08841981dbcb793a355e37ef027172928a205ea526d798be3263053b744b`. The same downloaded ZIP installed and passed the 37-file Mach-O audit, builtin DXMT check, and hardware D3D11 feature-level-11.0 probe on the physical M2 Pro (16 GiB, macOS 27.0.1). The canonical probe was compiled independently in [probe run 40188001903](https://github.com/Pajic-LLC/outRage/actions/runs/40188001903); the local run used an environment cleared of inherited Wine/DYLD overrides and Homebrew PATH.

Fresh prefix initialization logged a missing `syswow64/rundll32.exe` warning. The x86-64 graphics probe still passed; 32-bit compatibility is not established. The native development app started the official installer, whose log reports version `1.0.109.3031` and reaches its language page. At that initial checkpoint, installation, login, and gameplay were not yet proven; subsequent live findings follow below.

## Live launcher findings

The owner completed the visible installer. `Launcher.exe`, `LauncherPatcher.exe`, and `RockstarService.exe` are installed as x86-64 PE files. The original native host then hung while capturing a large process list: it waited for `ps` before draining its output pipe. Process discovery now drains before waiting; a 20,000-row child-process regression and the live 1,029-process host check pass. CI passes all 80 Swift tests.

The profile now supplies `managedLauncherDisplayName: Rockstar Games Launcher` for installer/launcher commands. Target/bootstrap commands keep the game name. This corrects the supplied process/menu identity, but full Dock/window branding remains unproven; the owner observed residual Wine naming.

The stock v0.80 DXMT package **does not run this launcher successfully**: it aborts on `SwapDeviceContextState`. The new `Tools/runtime/smoke/d3d11-context-state.c` reproduces exit code 3. Basic D3D11 device creation alone did not cover this requirement.

Upstream [commit e186434](https://github.com/3Shain/dxmt/commit/e18643447659dc05af9d160781c35c748a162715) implements that function. The developer experiment uses official [DXMT CI run 39904585849](https://github.com/3Shain/dxmt/actions/runs/39904585849), at `a148782d431249405acdb1531dbb0c7e737bbece` (one commit after the fix). Archive SHA-256: `37c33b07a3dc6dc1703736ffe462ca2673612985e3da5fc3bcffd918de1de120`. The independently packaged runtime ID is `outrage-metal-context-test`; the stock runtime remains intact. Its audit, builtin-module probe, D3D11 feature-level-11.0 probe, and context-state regression pass locally. The same context-state EXE fails with the stock v0.80 package and passes with this build.

Reproduce the experimental package with authenticated GitHub CLI access:

```sh
bash Tools/runtime/build-rockstar-context-test-runtime.sh \
  "$HOME/Library/Application Support/outRage/Runtimes/outrage-metal-x86_64" \
  .build/rockstar-context-test .build/rockstar-context-test/packages
```

The helper verifies the upstream run's commit, archive checksum, and base-engine audit. Upstream CI artifacts expire; this developer lane is **not** a durable release source. Promote a fixed source build or release pin before changing the normal runtime recipe.

With that experimental backend, Rockstar's service recovered after retries, downloaded updates, and installed Social Club `2.4.0.240` (vendor installer exit 0). Browser IPC connects and the Social Club log reaches `PAGE_READY` / `START_SIGN_IN` / `FINISHED`, but the owner sees a blank or absent window. Authentication has not been demonstrated. A desktop diagnostic also logs `CreateSwapChain: cross-process swapchain not supported yet`; treat the blank window as an unresolved rendering/presentation issue, not successful sign-in.

Disabling D3D11 only for `SocialClubHelper.exe` did not produce a usable visible window. That temporary registry override was removed. A temporary Wine desktop was diagnostic only and was shut down. [Fallback build 40203374791](https://github.com/Pajic-LLC/outRage/actions/runs/40203374791) compiled the original Wine D3D11/DXGI PE modules from the same pinned engine source. Their artifact checksums pass. For the local experiment, copies of these self-built Wine DLLs have only their DOS-stub `Wine builtin DLL` marker changed to `outRage wine DLL`, allowing Wine to load them app-locally instead of redirecting back to its global builtin DXMT modules. This changes no Rockstar binary. Patched SHA-256 values: d3d11 `1cbdd926ac85a860b9fb380555fecbcb69ba3882d4f75c3afa57472bd720503b`, dxgi `784dfda2a89a49afe1f978509df257a3624c7acb32cf966a49ec55d70d7f2f27`.

The native-only load probe verifies both app-local module paths and succeeds at D3D feature level 10.1 through Wine's OpenGL backend. The copies were then placed alongside `SocialClubHelper.exe` (neither filename previously existed there), with `d3d11=native` and `dxgi=native` scoped to that executable under Wine AppDefaults. The game/global renderer policy is not changed. This was a developer experiment, not adopted profile policy; it was rolled back after visible UI confirmation failed (see the presentation diagnostic below). During the trial the browser GPU process mapped `opengl32.so`, and its log reaches page-ready without a new cross-process DXMT error. Internal page-ready still does not establish visible authentication.

Developer checks:

```sh
swift run outrage validate Profiles/gta-v-legacy-rockstar.json
swift run outrage acquisition-plan Profiles/gta-v-legacy-rockstar.json
swift run outrage bundle Profiles/gta-v-legacy-rockstar.json
```

The generated `Grand Theft Auto V.app` contains the native host and profile. Development ad-hoc signing verifies bundle structure; it is not Developer ID signing or notarization. Title artwork and release packaging remain unfinished.

Before claiming gameplay, record the exact package checksum/version, game build, host macOS/chip, launcher version, successful login/install/update behavior, first gameplay frame, input/audio/saves, handoff to `GTA5.exe`, clean quit, and repeat launch. Until those are exercised, this profile is a test input rather than a compatibility claim.

## Native presentation diagnostic

The owner reported Dock items but no visible windows. The read-only `window-state.c` probe (built in run 40207712985) records a 2560×1440 Windows desktop and a `Rockstar Games Authentication` window at `(930,307)-(1630,1107)`, visible and not minimized. It records class names and geometry only, without window text, pixels, or input. Thus the Windows window is centered; that does not prove it is presented by macOS.

The developer bundle experiment in `build-rockstar-window-test-runtime.py` moves the actual inner Windows-process loader into a signed `.app`, preserves its library layout, and aligns its embedded Wine application metadata. The front loader alone is insufficient: Wine execs `lib/wine/x86_64-unix/wine`. The inner loader also requires adjacent `ntdll.so`. The metadata change preserves the existing Mach-O section size and re-signs the resulting app. This makes macOS list `Rockstar Games Launcher` under the experimental bundle identifier, but the owner still sees no window. Registration is proven; visible UI is not.

The script was exercised against the separately verified context-test runtime. The installed `.window-test.4` artifact passes app signature verification and its dependency audit. This deliberately duplicated layout is a diagnostic, not a release layout. The runtime remains separately identified as `outrage-metal-window-test`; the base runtime is intact.

The failed live helper-renderer trial was rolled back: both helper-specific D3D11/DXGI registry values were removed, and only the two checksum-verified, self-built sidecar DLLs were moved out of the Social Club directory. The bundled-loader diagnostic was stopped. The owner subsequently supplied a screenshot confirming the absence of a vendor window. No further screenshot is needed for that baseline. Internal page-ready/Windows-visible flags alone do not establish macOS presentation.


### Native activation and rendering continuation

The current helper does not receive the obsolete `--use-gl=swiftshader` switch reported by some other projects. A developer trampoline instead tests explicit CEF rendering modes while preserving the original helper byte-for-byte under a different filename. `--disable-gpu` alone retained a separate GPU process. `--in-process-gpu --use-gl=angle --use-angle=swiftshader` removed that process and the fresh cross-process swapchain error, but the owner still reported no window. These are Chromium rendering options, not title launch or authentication bypasses.

[Build 40210157370](https://github.com/Pajic-LLC/outRage/actions/runs/40210157370) supplies matching Wine D3D10/D3D10.1/D3D10Core/D3D11/DXGI modules. The live developer trial places plain copies in the prefix's system32, selects them only for the launcher, and disables D3D11/12 for its CEF helper. All five previous prefix files are backed up. An unrelated device probe still loads builtin DXMT at feature level 11.0; the launcher-named probe loads native Wine D3D11/DXGI with builtin wined3d at 10.1. The Direct2D window probe finishes drawing successfully through both paths, so a basic Direct2D API failure has not been demonstrated. This remains an experimental prefix policy.

The original vendor helper SHA-256 is `d3bd835897a97207d26e703969232ded54fd32c4388691c7ebd95709a54f9a6d`. During the trampoline experiment it is preserved as `SocialClubHelper.outrage-original.exe`; the temporary `SocialClubHelper.exe` is built from outRage source. No vendor executable bytes, entitlement checks or credentials are modified. Before restoring the vendor filename, stop the test prefix and verify both files against the recorded hashes.

[Native-driver build 40228921999](https://github.com/Pajic-LLC/outRage/actions/runs/40228921999) instruments the pinned winemac implementation with opt-in window-state logs, without reading titles, pixels, input or other applications. Its separate runtime (`outrage-metal-window-diagnostics`, package SHA-256 `c902ea97a42f4ab2eb40c270422c81ec037a021902c2c61e75796c7bb07dd05b`) passes its 37-file dependency audit. Its initializer is omitted because it is an existing-prefix diagnostic, not a fresh-machine runtime.

The native baseline showed a drawn, opaque Wine window on an inactive Space, fully occluded and inactive. An all-Spaces policy experiment did not solve that state and is not active. A native Cocoa control window established that activation after launch can reach the active Space. The host now cooperatively yields activation to its managed installer/launcher after it registers as a regular app, only while the host is foreground. With that handoff and foreground host input, the real authentication and launcher windows report `activeSpace=1`, `occluded=0`, `drawn=1`, `opaque=1` and `appActive=1`. The previous baseline did not receive the same foreground input, so this is not a controlled attribution of the entire improvement to the host change alone. It is stronger presentation evidence than the earlier Windows flags; the actual sign-in form, authentication and gameplay still require owner confirmation. The active trial is left open for that confirmation.

The process-level CEF patch in `patch-wine-cef-process.py` is opt-in and targets only the original browser helper, preserving the vendor filename and raw process arguments/handles. The manual fallback workflow's `cef-process` lane builds a developer kernelbase module for this test. `cef-process-probe.c` uses only own Windows fixture processes to check browser-only scope, duplicate avoidance, Unicode arguments and an inherited event handle. The unpatched runtime fails the opt-in case as expected (exit 20). The patched module from build 40230561494 passes all five cases on the M2 Pro, with the inherited event and Unicode marker intact. Its separate package (`outrage-metal-cef-process-test`, SHA-256 `fb8ee2b597aa4c99b2023e20064e85f4f4c3c700a2fada669fe540d649c23ead`) passes the 37-file dependency audit, hardware D3D11 feature-level-11.0 probe and context-state-swap regression. It has not yet replaced the live trampoline trial. Neither this patch nor the experimental runtime is promoted into the normal recipe yet.
