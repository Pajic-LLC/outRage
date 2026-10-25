# outRage Engineering Handoff

> **Living source of truth for implementation, status, priorities, and completion.**
>
> Snapshot: **2026-10-25** · working branch: `feat/runtime-foundation` · pre-alpha.
>
> This document is intentionally more explicit than the public-facing README. When code, priorities, or acceptance criteria change, update this file in the same workstream so the next session can continue without reconstructing intent from commit history.

## 0. How to read this document

Status markers used below:

- **✅ Proven** — implemented and demonstrated by an automated end-to-end/package gate or equivalent concrete evidence.
- **🟢 Implemented** — code exists and is covered by unit/integration tests, but the complete real-title path is not yet proven.
- **🟡 In progress** — active work is underway or a build/proof lane is still unresolved.
- **⬜ Planned** — required for completion but not implemented yet.
- **⚠️ Risk / unknown** — behavior depends on external software, macOS, a launcher, a game, licensing, or another variable that must be proven rather than assumed.

A unit test is not the same thing as a product milestone. A subsystem is only **Proven** when the acceptance criterion for that subsystem has actually been exercised at the correct level.

### Current primary objective

**Prove GTA V Legacy Story Mode from legitimate ownership to gameplay through `Grand Theft Auto V.app` on Apple Silicon, using an outRage-managed runtime and DXMT/Metal. The immediate infrastructure gate is a self-contained, launcher-capable x86-64 runtime.**

The current runtime already establishes the core package path. The next runtime must also carry the dependencies needed by modern authenticated launchers, remain portable without Homebrew on the end-user Mac, pass the DXMT/Metal smoke gate, and execute a real x86-64 Win32 program through Rosetta/Wine.

---

# 1. Mission

outRage makes **Rockstar RAGE-engine games feel like native Apple Silicon Mac games**. This is a Rockstar/RAGE compatibility platform, not a general-purpose Windows launcher or bottle manager.

The owner-supplied [product vision](docs/PRODUCT_VISION.md) defines scope and title priorities: GTA V Legacy Story Mode first, then GTA IV, Max Payne 3, RDR2, GTA V Enhanced, and future compatible RAGE titles. ENRAGE remains separate modding infrastructure. These are planned targets, not proven support.

The intended end state is not “open a Wine GUI, configure a bottle, launch a launcher, then launch a game.” The intended end state is:

1. The user has a real macOS `.app` for a title.
2. They double-click it like any other Mac game.
3. outRage silently resolves the title profile, host capabilities, runtime, prefix, storage mappings, renderer, caches, and launcher state.
4. If Rosetta is required and missing, the native host offers the legitimate Apple installation flow and resumes afterward.
5. On first run, an authenticated vendor launcher may appear when the user actually needs it for install/login/consent.
6. The title installs into outRage-managed storage while the Windows software sees the path it expects.
7. On later launches, outRage prefers the most direct legitimate title bootstrap path available and keeps compatibility plumbing out of the way.
8. The real game process is detected, adopted, monitored, and presented with the title's identity rather than a generic “Wine” identity where technically possible.
9. Direct3D rendering is translated to Metal through the selected backend, with per-title compatibility/performance policy supplied by data rather than hard-coded game logic.
10. Quitting the game ends the session cleanly. Failures produce useful diagnostics instead of a dead icon or unexplained terminal output.

The compatibility stack is an implementation detail. **The product experience should feel like launching a Mac game.**

---

# 2. Product goals

## G1 — Native-feeling macOS UX

**Goal:** A supported title should be represented by a normal `.app` bundle and launched through a native Swift host.

**Why:** Even perfect Windows compatibility still feels broken if the user sees terminal windows, generic Wine branding, confusing helper apps, manual prefix setup, or unexplained exit states.

**Completion means:**

- Generated app has the title's name, bundle identifier, icon, Games category, Retina/high-resolution behavior, and correct single-instance semantics.
- Development bundles are signable/verifiable; release bundles are Developer ID signed and notarized.
- Rosetta setup, runtime setup, installation state, launch progress, recoverable errors, and diagnostics are native UI states.
- No terminal is required for normal end-user use.
- Dock/menu/process identity uses the title identity where the compatibility engine permits it.
- First-run setup can expose a vendor launcher when necessary; routine launch minimizes that exposure.

**Current status:** 🟢 Core app bundle, ad-hoc signing/verification, Rosetta flow, and title identity plumbing are implemented. Release-quality UX, real-title proof, Developer ID signing, and notarization remain.

## G2 — Self-contained end-user runtime

**Goal:** An end user must not need Homebrew, Xcode, package managers, custom environment variables, or a developer shell.

**Why:** Build-machine dependencies cannot leak into a distributable runtime. A runtime that works only on CI or the developer Mac is not a product runtime.

**Completion means:**

- Runtime package is versioned and checksum verified.
- Package can install into outRage's runtime catalog on a clean Mac.
- All bundled Mach-O dependencies resolve to system libraries or files inside the runtime.
- No Homebrew, MacPorts, developer home, temporary runner, or source-tree path remains in load commands.
- Every modified Mach-O is signed appropriately after relocation.
- Runtime can be removed/reinstalled without corrupting title data.

**Current status:** 🟡 Core runtime packaging/install verification is proven. Self-containment auditing exists. Pinned x86-64 launcher dependency work is active and still needs to be integrated and proven with the complete runtime.

## G3 — Metal-first graphics

**Goal:** Direct3D titles should render through a Metal-oriented path appropriate for Apple Silicon.

**Why:** Graphics translation is the center of game compatibility and performance. outRage should treat renderer selection and configuration as first-class runtime policy, not an accidental DLL drop.

**Completion means:**

- Runtime contains the intended graphics backend in the correct engine layout.
- DXMT can initialize through the packaged compatibility engine.
- `d3d11`, `DXGI`, and `winemetal` resolve through the expected builtin path for the DXMT runtime.
- No incorrect DXVK-style “native” DLL override silently bypasses the intended builtin DXMT path.
- Backend cache/log directories exist before launch.
- Per-title renderer policy can be updated without changing core code.
- Real title renders correctly through the packaged runtime.

**Current status:** 🟢 DXMT composition, overlay installation, backend resolution, cache/log preparation, and smoke-verifier code exist. The stricter packaged-runtime smoke gate is wired into the heavy workflow; the newest complete runtime still needs to finish proving all gates together.

## G4 — Legitimate launcher fidelity

**Goal:** Authenticated launchers should work without outRage bypassing their authentication, entitlement, update, or ownership checks.

**Why:** Modern games often require launchers. Hiding that fact must not mean breaking or circumventing the vendor's security model.

**Completion means:**

- Managed launcher installer is acquired through a validated source.
- Launcher installs in the title's isolated prefix.
- User can authenticate using the launcher's own UI.
- outRage does not collect or embed the user's launcher password.
- Vendor-owned session state can persist naturally inside the prefix.
- Game ownership/entitlement remains enforced by the vendor.
- outRage can hand off from launcher/bootstrap to the actual game process and monitor the game rather than the launcher shell.
- Prefer a profile update for launcher policy changes; use targeted Rockstar/RAGE runtime fixes when a demonstrated failure requires code.

**Current status:** 🟢 Managed-launcher acquisition/bootstrap, target-bootstrap configuration, process baseline/handoff, launcher-PID exclusion, and lifecycle code are implemented/tested. A real authenticated Tier-3 launcher must still be proven end-to-end.

## G5 — Data-driven title compatibility

**Goal:** Game-specific behavior belongs in a versioned profile instead of forks or `if game == ...` branches in the core.

**Why:** Versioned title recipes make Rockstar/RAGE fixes reviewable and maintainable. Shared infrastructure should support those recipes; targeted RAGE-specific code is appropriate when a demonstrated compatibility defect cannot be expressed in data.

**Completion means:**

- Profiles describe executable location/scope, runtime, CPU backend, graphics backend, arguments, environment, path mappings, process match, performance policy, and acquisition strategy.
- Invalid paths and incompatible combinations fail validation before execution.
- Signed profile updates can adjust compatibility policy without rebuilding every `.app`.
- A title profile is reproducible and reviewable as data.
- Prefer profiles for title policy; allow targeted Rockstar/RAGE core fixes backed by concrete failures and regression coverage.

**Current status:** 🟢 Schema, validation, signed envelope/store/update plumbing, and effective-profile resolution exist with tests. Production profile distribution/signing policy still needs release work.

## G6 — Deterministic and verifiable packages/updates

**Goal:** Runtime and profile inputs must be explicit, pinned, verifiable, and recoverable.

**Why:** Silent source drift makes compatibility bugs unreproducible and creates supply-chain risk.

**Completion means:**

- Source/runtime artifacts are pinned by version and hash where applicable.
- Runtime packages carry a manifest and checksum.
- Installer rejects mismatched or malformed packages.
- Profile updates are signed and verified before becoming effective.
- A bad/partial runtime catalog entry cannot brick unrelated titles.
- Update/rollback behavior is testable.

**Current status:** 🟢 Runtime package verification, resilient catalog lookup, signed profile primitives, and verified profile store are implemented. Release update distribution and rollback UX remain.

## G7 — Per-title isolation and safe storage virtualization

**Goal:** Every title gets isolated target files, prefix, caches, and logs while Windows software sees the paths it expects.

**Why:** Shared mutable Wine state causes cross-title regressions. Launchers also often insist on Windows-style install locations that should not dictate the actual macOS storage layout.

**Completion means:**

- Each profile has independent target, prefix, cache, and log roots.
- Path mappings can expose managed target storage at a Windows-prefix location.
- An empty placeholder directory may be safely adopted/replaced by a mapping.
- Non-empty user/launcher data is never silently overwritten by the mapper.
- Removing one title does not destroy another title's state.

**Current status:** 🟢 Isolation paths and path mapping behavior are implemented/tested.

## G8 — Performance that survives game updates

**Goal:** Make translation overhead predictable and preserve useful warm state without letting stale caches poison a new build.

**Why:** Shader/runtime caches strongly affect perceived smoothness, but caches keyed only to a title name become dangerous after an executable update.

**Completion means:**

- Target executable fingerprint contributes to cache identity.
- New game builds get new build-specific state.
- A bounded number of recent build caches are retained for rollback/reuse.
- Typed performance policy exposes safe backend knobs while explicit profile environment values remain authoritative.
- Performance work is measured on repeatable scenes/configurations rather than judged from a single launch.
- Optimization does not reduce correctness or launcher reliability.

**Current status:** 🟢 Build fingerprinting, build-specific cache preparation, retention policy, AVX/runtime defaults, frame-pacing policy, and MetalFX spatial-upscaling policy are implemented/tested. Real-title benchmarking/tuning is still pending.

## G9 — Diagnostics and recoverability

**Goal:** Failures must identify which layer failed: host, Rosetta, runtime install, prefix, mapping, launcher, renderer, process handoff, or target.

**Why:** A compatibility system has many boundaries. Without structured diagnostics every bug becomes “it didn't launch.”

**Completion means:**

- Per-title logs exist in a stable location.
- Launch plan/runtime/backend decisions are inspectable.
- The host can explain missing Rosetta/runtime/target/launcher states.
- Corrupt runtimes can be ignored/reinstalled rather than poisoning catalog discovery.
- A user-facing support bundle can collect relevant versions/logs/configuration while redacting credentials/tokens/private launcher state.
- Diagnostics never include passwords or intentionally scrape authentication data.

**Current status:** 🟢 Logging/diagnostic foundations and developer CLI inspection exist. User-facing diagnostic bundle/redaction and polished recovery UI are still planned.

## G10 — Reproducible CI and release gates

**Goal:** Every expensive artifact should prove more than “the build command exited zero.”

**Why:** A ZIP can be valid while the contained runtime is unusable. The release pipeline must exercise the installed artifact.

**Completion means:**

- Normal CI syntax-checks runtime tooling, runs Swift tests, and builds release tools.
- Dependency CI proves pinned x86-64 dependency architecture.
- Runtime CI builds package, installs its own package, audits portability, initializes DXMT, and executes real x86-64 Windows code.
- Heavy runtime jobs only rerun when runtime-related inputs change or a manual rebuild is requested.
- Release candidate gates run on the exact bytes intended for distribution.

**Current status:** 🟡 Normal CI is green at the snapshot head. The dependency lane and newest heavy runtime lane are active work; the stricter gates are present but must finish together on the final launcher-capable runtime.

## G11 — Release/legal/compliance readiness

**Goal:** A distributable build must be technically and legally releasable, not merely functional on the developer machine.

**Why:** The runtime combines open-source components and macOS executable code. Redistribution obligations and Apple's signing/notarization requirements are part of completion.

**Completion means:**

- Third-party component versions/licenses are inventoried.
- Required notices, source availability/source offer, and attribution are shipped as required by each license.
- We verify redistribution terms for every bundled component and do not ship proprietary vendor game/launcher files unless permitted.
- App/runtime signing strategy is documented.
- Release `.app` is Developer ID signed and notarized.
- Update channel and release downloads use integrity checks.

**Current status:** ⬜ Development signing exists. Formal license audit, release notices, Developer ID signing, notarization, and release update infrastructure remain.

## G12 — Extensible architecture

**Goal:** The first title proves the system; it must not trap the project in one launcher/game/backend.

**Why:** The project is valuable if a new title is primarily a new profile plus measured compatibility work.

**Completion means:**

- CPU/backend types remain replaceable (`rosetta`, future `fex`, graphics backends, etc.).
- Acquisition strategies remain modular (`managedLauncher`, `steam`, `importExisting`).
- A second materially different title can be added without rewriting the host lifecycle.
- Backend/title-specific hacks live behind explicit interfaces or profile data.

**Current status:** 🟢 The model is already generic; multi-title proof remains future validation.

---

# 3. Explicit non-goals and boundaries

outRage is **not** a DRM bypass, crack, credential harvester, or ownership emulator.

The project will not:

- expand into a general-purpose Windows launcher, arbitrary Wine bottle manager, or unrelated storefront frontend;

- bypass a vendor's authentication, license, entitlement, payment, or ownership checks;
- capture/store launcher passwords for convenience;
- patch game binaries for the purpose of bypassing DRM or anti-cheat;
- redistribute commercial games or proprietary launcher payloads without permission;
- claim unsupported online/anti-cheat compatibility until it has been legitimately proven;
- treat brittle pixel/coordinate automation of a launcher UI as the primary architecture;
- require end users to understand Wine prefixes, DLL overrides, Homebrew, Xcode, shell setup, or build tools;
- promise universal Windows-game compatibility during pre-alpha;
- use a Windows VM as the core execution model.

If a title's required anti-cheat, kernel component, DRM, or vendor policy is incompatible with the architecture, that mode/title is **unsupported until there is a legitimate compatible route**.

---

# 4. Definition of complete

outRage reaches the first meaningful “complete” milestone when a release candidate can take a supported, legitimately owned Rockstar/RAGE title from a **fresh supported Apple Silicon Mac** to repeatable gameplay through a signed/notarized title app without developer tooling.

For the first release candidate, all of the following must be true:

- [ ] Fresh supported Apple Silicon Mac; no Homebrew/Xcode required for the user.
- [ ] User double-clicks a normal signed/notarized title `.app`.
- [ ] Missing Rosetta is detected by executing x86-64 code and can be installed through Apple's supported flow.
- [ ] Required outRage runtime downloads/installs with integrity verification.
- [ ] Installed runtime passes portability/self-containment validation.
- [ ] Packaged runtime can execute a real x86-64 Win32 smoke program.
- [ ] Packaged runtime can initialize the configured DXMT/Metal path.
- [ ] First-run vendor launcher installation/authentication works when required.
- [ ] Game install is directed to managed storage through safe path mapping.
- [ ] Entitlement/auth remains owned by the vendor launcher.
- [ ] Subsequent launch prefers a legitimate title bootstrap/direct route when supported, with launcher fallback when necessary.
- [ ] outRage correctly detects the actual game process and does not mistake the launcher for the game.
- [ ] Title renders through the intended backend on real hardware.
- [ ] Keyboard/mouse, audio, networking required by the supported mode, fullscreen/windowing, and save data are validated.
- [ ] App/Dock/menu identity is title-appropriate rather than generic compatibility-engine branding where technically possible.
- [ ] Clean quit works and the native host ends when the real game session ends.
- [ ] Cold reboot + relaunch works without manual prefix repair.
- [ ] Game update creates/uses the correct build-specific cache state.
- [ ] Corrupt/missing runtime produces a recoverable state rather than bricking every title.
- [ ] User-facing diagnostics can be collected without leaking credentials/tokens.
- [ ] Runtime/profile update integrity and rollback behavior are defined/tested.
- [ ] CI/release gates run on the exact release artifact.
- [ ] Third-party licensing/attribution/source obligations are satisfied.
- [ ] Release app/runtime are appropriately signed and notarized.

Anything short of this may be a strong engineering milestone, but it is not the first product completion milestone.

---

# 5. Architecture

## 5.1 High-level launch path

```text
<Title.app>
    |
    v
OutRageHost (native Swift/macOS lifecycle)
    |
    +--> Bundled profile
    |       +--> signed/verified profile update (when available)
    |       `--> EffectiveProfileResolver
    |
    +--> HostCapabilities
    |       +--> architecture / Metal
    |       `--> actual x86-64 execution probe for Rosetta
    |
    +--> RuntimeCatalog / RuntimeBootstrap
    |       +--> verified package download/cache
    |       +--> install / descriptor validation
    |       `--> compatible runtime resolution
    |
    +--> RuntimeEnvironmentPreparer
    |       +--> PrefixManager
    |       +--> RuntimePathMapper
    |       +--> graphics/backend overlay configuration
    |       +--> PerformanceLaunchTuner
    |       `--> build-specific graphics/runtime cache preparation
    |
    +--> InstallationStateResolver / Acquisition
    |       +--> import existing
    |       +--> Steam
    |       `--> managed launcher installer/login/install
    |
    +--> LaunchSession
    |       +--> direct target
    |       +--> legitimate target bootstrap executable
    |       `--> managed launcher fallback
    |
    +--> ProcessHandoffMonitor / ProcessDiscovery
    |       `--> find newly spawned real target process
    |
    +--> title lifecycle monitoring
    |       +--> native host visibility/identity
    |       +--> logs/diagnostics
    |       `--> clean session end
    `--> done
```

## 5.2 Storage model

On macOS, the default base is:

```text
~/Library/Application Support/outRage/
```

Layout:

```text
Runtimes/                 Shared verified runtime installations
Profiles/                 Installed/updated profile state
Targets/<profile-id>/     Actual managed game/title files
Prefixes/<profile-id>/    Isolated Windows compatibility prefix
Cache/                    Shared cache root
Cache/RuntimePackages/    Downloaded runtime package cache
Cache/<profile-id>/       Per-title cache state
Logs/<profile-id>.log     Stable per-title launch log
```

The launcher can be made to see a conventional Windows path inside `Prefixes/<profile-id>` while the real title payload remains under `Targets/<profile-id>`.

## 5.3 Core rule: one canonical preparation path

Direct targets, target-bootstrap launches, and managed-launcher launches must share the same runtime preparation semantics. Prefix configuration, mappings, renderer policy, caches, runtime environment, diagnostics, and performance policy must not drift into separate implementations.

If a feature requires copy/pasting launch preparation into another launcher path, the architecture is moving in the wrong direction.

---

# 6. Core data model

## RuntimeProfile

The schema is currently version `1`. It describes a title without requiring game-specific branches in the host.

Key fields:

- `id` — stable lowercase profile identifier.
- `displayName` — title shown by the host/bundle.
- `bundleIdentifier` — macOS bundle identity.
- `executable` — relative target executable path.
- `executableScope` — `target` or `prefix`.
- `workingDirectory` — optional relative working directory.
- `runtime` — `native` or `compatibility`.
- `runtimeIdentifier` — explicit runtime package/catalog ID.
- `runtimePackageSource` — verified source/manifest for bootstrap installation.
- `launcher` — `direct` or `managed`.
- `cpu` — `auto`, `native`, `rosetta`, or `fex`.
- `graphics` — `auto`, `metal`, `dxmt`, `d3dMetal`, `dxvk`, or `vkd3d`.
- `arguments` — target arguments.
- `environment` — explicit title environment. Explicit values take precedence over typed/default policy.
- `pathMappings` — prefix-visible paths mapped to managed host storage.
- `processMatch` — target-process identity used for handoff; defaults to executable basename.
- `performance` — typed performance policy.
- `acquisition` — how the title becomes installed/available.

Validation rejects unsupported schema versions, unsafe relative paths, invalid IDs, invalid runtime identifiers, invalid process-match values, incompatible prefix/native combinations, malformed package sources, invalid mappings, and invalid acquisition/performance configuration.

## Acquisition

Current acquisition modes:

### `managedLauncher`

For a vendor launcher that must be installed inside the title prefix. It can specify:

- installer URL and optional SHA-256;
- installer arguments;
- installed launcher executable/arguments;
- optional `targetBootstrapExecutable` and arguments;
- product identifier.

A target bootstrap is **not a bypass**. It is a legitimate title-provided bootstrap program that may hand into an already authenticated launcher session. If it does not work or is not configured, outRage falls back to the managed launcher path.

### `steam`

Describes a Steam app ID and optional branch for Windows target acquisition.

### `importExisting`

Uses an already-available target payload placed/imported into managed storage.

## PerformancePolicy

Current typed controls:

- `preferredMaxFrameRate`
- `metalFXSpatialUpscaling`
- `metalFXSpatialUpscaleFactor`

Typed policy fills in safe defaults. Explicit per-title environment configuration remains authoritative when both are present.

## Target build fingerprint

Caches must track the actual target build rather than only the profile ID. An executable change should produce a new build-specific cache identity so stale shader/runtime state does not contaminate a new game build.

## Runtime package

A runtime package is not trusted merely because its ZIP extracts. The package path includes a descriptor/manifest, digest verification, installation into the runtime catalog, post-install resolution, and increasingly strict smoke/portability gates.

---

# 7. Repository map

```text
Package.swift
    Swift 6 package: OutRageKit + outrage CLI + outrage-host.

Sources/OutRageKit/
    Product/runtime logic. Keep generic behavior here.

Sources/OutRageCLI/main.swift
    Developer utility for host/runtime/profile inspection, packaging and launch tests.

Sources/OutRageHost/main.swift
    Native title-app host and end-user lifecycle/UI entry point.

Profiles/
    Versioned target profiles/examples.

Tests/OutRageKitTests/
    Unit/integration regression coverage for core behavior.

Tools/runtime/
    Reproducible runtime source build, dependency build, relocation,
    signing, portability audit, source patching, and smoke harnesses.

.github/workflows/ci.yml
    Fast Swift/tooling validation.

.github/workflows/runtime-build.yml
    Expensive packaged-runtime build/install/audit/smoke lane.

.github/workflows/runtime-deps.yml
    Pinned x86-64 launcher dependency build/architecture lane.

docs/ARCHITECTURE.md
    Code-facing subsystem overview. This HANDOFF remains the roadmap/source of truth.
```

Important `OutRageKit` areas include acquisition, bundle generation/signing, runtime bootstrap/catalog/install/package verification, profile loading/update verification, prefix/path mapping, backend resolution, environment preparation, performance/cache preparation, PE probing, launch session construction, managed launcher bootstrap, process discovery/handoff, and diagnostics.

---

# 8. Current subsystem status — snapshot 2026-10-25

| Area | Status | What that actually means |
| --- | --- | --- |
| Swift package / core CI | ✅ Proven | Swift tests and release CLI/host builds are green at the snapshot head. |
| Profile schema + validation | 🟢 Implemented | Broad validation and serialization tests exist; first production title profile still pending. |
| Runtime storage/isolation | 🟢 Implemented | Stable runtime/profile/target/prefix/cache/log layout exists. |
| PE probing | 🟢 Implemented | Windows executable architecture/graphics-hint inspection exists. |
| Runtime package/manifest/install | ✅ Proven | Package/build/install path has produced a verified installed runtime. |
| Runtime catalog resilience | 🟢 Implemented | Malformed entries can be ignored during discovery without weakening install validation. |
| x86-64 compatibility runtime | ✅ Proven (foundation) | A pinned x86-64 engine + Metal backend package has built and installed successfully; stricter launcher-ready runtime is the active milestone. |
| DXMT composition/overlay | 🟢 Implemented | Builtin layout and prefix overlay behavior are implemented/tested. |
| DXMT packaged smoke | 🟡 In progress | Gate exists in heavy runtime workflow; newest complete runtime must pass it together with all other gates. |
| Real Win32 packaged smoke | 🟡 In progress | Gate/harness exists; must pass on final launcher-capable package. |
| Mach-O portability audit | 🟢 Implemented | Runtime workflow audits self-containment; final dependency-integrated package must pass. |
| Pinned x86-64 launcher deps | 🟡 In progress | GMP/Nettle/GnuTLS/FreeType build lane exists; integration/proof is current work. |
| Prefix management | 🟢 Implemented | Isolated per-title prefix prep exists. |
| Path mapping/storage virtualization | 🟢 Implemented | Empty placeholder adoption + non-empty protection are covered. |
| Direct launch | 🟢 Implemented | Canonical launch session path exists; real target proof belongs to reference-title milestone. |
| Managed launcher bootstrap | 🟢 Implemented | Installer/bootstrap/planning path exists; real authenticated launcher proof pending. |
| Target bootstrap executable | 🟢 Implemented | Profile can prefer a legitimate title bootstrap before launcher fallback. |
| Process handoff | 🟢 Implemented | Baseline/new-process resolution, configurable match, one-shot monitoring, and launcher-PID exclusion exist/tests pass. |
| Native app bundle generation | 🟢 Implemented | `.app` generation and metadata path exist. |
| App code signing | 🟢 Implemented (dev) | Ad-hoc sign/verify by default; release Developer ID/notarization pending. |
| Rosetta detection/install UX | 🟢 Implemented | Detection uses real x86-64 execution; native install action exists. |
| Native translated-process identity | 🟡 In progress | `OUTRAGE_APP_NAME` + winemac patcher are integrated/tested; packaged-runtime/title proof pending. |
| Signed profile updates | 🟢 Implemented | Envelope/store/channel/effective profile primitives exist; production distribution/rotation/rollback pending. |
| Build-specific cache/performance policy | 🟢 Implemented | Fingerprint/cache/tuning policy exists; real-title measurements pending. |
| Diagnostics | 🟢 Foundation | Logs/developer diagnostics exist; redacted support bundle and polished recovery UX pending. |
| Real Tier-3 managed title | ⬜ Planned | First complete launcher → installed game → Metal gameplay proof has not yet been achieved. |
| Release signing/notarization | ⬜ Planned | Not a development blocker, mandatory for release. |
| License/redistribution audit | ⬜ Planned | Mandatory before distributing a release. |

### Live build note

Follow-up evidence on 2026-10-25:

- [Runtime Build #5](https://github.com/Pajic-LLC/outRage/actions/runs/40179533510) built and installed its package, then failed before the portability audit could run: whitespace-based `awk` parsing truncated `Library/Application Support` to `Library/Application`. DXMT and Win32 gates were skipped. The workflow now parses the tab-separated runtime listing by tabs; a real Mach-O regression checks both spaced paths and audit failure propagation.
- [Runtime Dependencies #1](https://github.com/Pajic-LLC/outRage/actions/runs/40179693905) failed at the GnuTLS install-time relink after selecting ARM Homebrew Brotli/Zstd libraries for an x86-64 output. The builder now restricts pkg-config discovery to the pinned prefix and explicitly disables those unbundled optional compression dependencies. A new complete dependency build is still required before calling this proven.
- A native Mach-O relocation regression now proves transitive dependency loading through `dlopen` after moving the runtime and deleting the dependency build prefix, with no `DYLD_*` overrides. It exposed another whitespace truncation in `otool -L` parsing; bundling/auditing now strip metadata rather than splitting dependency names on spaces. This proves relocation mechanics on the host architecture, not x86-64 launcher compatibility.
- Normal CI for the first fix passed, and the native CLI/host release builds pass locally. Full dependency and runtime proof runs are still pending.
- Local validation cannot currently prove translated execution: this Mac's x86-64 probe reports `Bad CPU type in executable` (Rosetta is unavailable). Its Command Line Tools also lack the Swift `Testing` module, so the full Swift suite must run on the CI Xcode toolchain. These environment limits do not establish runtime compatibility or gameplay.

---

# 9. Runtime composition strategy

The current FOSS Metal runtime builder pins:

- CodeWeavers/CrossOver FOSS source package `26.3.0` with a fixed SHA-256.
- DXMT `v0.80` builtin archive with a fixed SHA-256.
- Runtime ID `outrage-metal-x86_64`.

The engine is built as x86-64 on Apple Silicon and executed through Rosetta. Build-time use of Homebrew/toolchains is acceptable **only on the build machine**. It is not acceptable for the produced runtime to depend on those build-machine paths at runtime.

The initial stripped engine configuration deliberately omitted several optional dependencies. That is sufficient to prove core packaging/execution, but modern authenticated GUI launchers need more. The active launcher-ready dependency lane builds a pinned x86-64 set centered around:

```text
GMP -> Nettle -> GnuTLS
             + FreeType
```

The output must be bundled/relocated into the runtime, load paths rewritten, modified Mach-O files re-signed, and the final package audited so a user does not need Homebrew.

---

# 10. Milestones to completion

## M0 — Make intent and completion measurable

**Status: ✅ Proven by this handoff once committed.**

Goal: eliminate “what are we even building?” ambiguity.

Acceptance criteria:

- [x] Mission is explicit.
- [x] Product goals and non-goals are explicit.
- [x] Current architecture is documented.
- [x] Implemented vs proven vs in-progress is distinguished.
- [x] Milestones have exit criteria.
- [x] Definition of product completion exists.
- [x] README points here.

## M1 — Core runtime foundation

**Status: ✅/🟢 Mostly complete.**

Goal: deterministic profile, runtime, bundle, prefix, target, planning, packaging, and launch foundations.

Acceptance criteria:

- [x] Versioned profile schema and validation.
- [x] Stable storage layout.
- [x] Host capability discovery.
- [x] Runtime catalog/descriptor/package/install pipeline.
- [x] App bundle generation.
- [x] PE probing.
- [x] Prefix/environment prep.
- [x] Direct/managed launch session model.
- [x] Swift regression suite.
- [x] Release CLI/host build in CI.

Preserve this foundation. Add targeted Rockstar/RAGE fixes when a demonstrated title failure requires them, with regression coverage at the appropriate layer.

## M2 — Launcher-capable self-contained runtime

**Status: 🟡 CURRENT.**

Goal: produce a packaged runtime capable of both game rendering and modern authenticated launcher operation on a clean end-user Mac.

Tasks:

- [x] Pin compatibility-engine and DXMT sources/hashes.
- [x] Build x86-64 engine on Apple Silicon.
- [x] Compose DXMT builtin backend.
- [x] Package + manifest + checksum.
- [x] Install the package through outRage itself.
- [x] Add Mach-O portability audit.
- [x] Add DXMT initialization smoke harness.
- [x] Add real x86-64 Win32 execution smoke harness.
- [x] Add native-title winemac identity patcher with anchor/idempotence tests.
- [x] Add pinned x86-64 dependency builder.
- [x] Add runtime dylib relocation/signing tool.
- [ ] Resolve the current dependency CI result and fix any real build errors.
- [ ] Prove the dependency-integrated engine build. Implementation now builds/reuses a locked x86-64 prefix, requires GnuTLS/FreeType, and rewrites their configured `dlopen` names to `@rpath`; a complete x86-64 artifact run is pending.
- [ ] Prove all dependency dylibs in the real runtime package. The builder now invokes relocation/signing before staging smoke/packaging and includes the dependency lock; native transitive-load regression passes.
- [ ] Re-run portability audit on the exact dependency-integrated package.
- [ ] Require packaged DXMT module-load and real D3D11 device-creation smoke to pass. Both are now wired into the workflow.
- [ ] Require packaged Win32 PE smoke to pass.
- [ ] Preserve runtime signing after relocation.
- [ ] Upload the exact passing artifact.

**M2 exit gate:** one uploaded package installs from its own manifest on a clean CI home, has no forbidden build-machine dynamic-library references, executes a real Win32 x86-64 program, and proves the DXMT builtin path initializes.

## M3 — Generic managed-launcher lifecycle

**Status: 🟢 code foundation; real proof pending.**

Goal: support a launcher without turning the core into launcher-specific automation.

Tasks/acceptance:

- [x] HTTPS/file installer source validation.
- [x] Optional installer SHA-256 validation.
- [x] Isolated launcher prefix.
- [x] Managed install/launcher planning.
- [x] Windows install-path mapping to managed title storage.
- [x] Protect non-empty mapped destinations.
- [x] Allow safe adoption of empty placeholders.
- [x] Profile-configurable game process match.
- [x] Process baseline + newly spawned target detection.
- [x] Exclude launcher PID from target match.
- [x] Adopt a target the user starts from visible launcher UI during first-run setup.
- [x] Support legitimate title bootstrap executable before launcher fallback.
- [ ] Prove a real launcher can install under the launcher-capable runtime.
- [ ] Prove login UI/TLS/fonts work correctly.
- [ ] Prove login/session persists after quit/reboot as expected by the vendor.
- [ ] Prove install/update/verify flows work with mapped title storage.
- [ ] Prove host follows the game process when launcher remains resident.
- [ ] Prove clean game quit and launcher/session cleanup semantics.

**M3 exit gate:** a real authenticated launcher can install, authenticate, install/update a legitimately owned title, spawn the game, and hand lifecycle control to outRage without credentials being captured or DRM/entitlement being bypassed.

## M4 — First reference title end-to-end

**Status: ⬜ next major product milestone.**

Goal: prove GTA V Legacy Story Mode through the official Rockstar Games Launcher, legitimate ownership, DXMT/Metal, and a native title app.

The current intended Tier-3 reference scenario is **Rockstar Games Launcher / GTA V Legacy Story Mode** because it exercises authentication, a managed launcher, a title bootstrap, a large install, updates, process handoff, Direct3D rendering, and persistent launcher state. This is a compatibility target, not a promise of unsupported online/anti-cheat functionality.

Reference-title tasks:

- [ ] Create a real profile with verified executable paths/scopes, process match, path mappings, runtime ID, renderer, and acquisition strategy.
- [ ] Install launcher into isolated prefix using the launcher-capable runtime.
- [ ] Log in manually using vendor UI; verify TLS/fonts/web content.
- [ ] Install the legitimately owned title into mapped managed target storage.
- [ ] Verify file integrity/update path.
- [ ] Test the title-provided bootstrap route if legitimate and functional.
- [ ] If bootstrap route cannot start the owned title, use managed launcher fallback without inventing an undocumented bypass.
- [ ] Detect/adopt the actual game process.
- [ ] Render through DXMT/Metal.
- [ ] Validate keyboard/mouse and any controller path intended for support.
- [ ] Validate audio.
- [ ] Validate networking required by the supported game mode.
- [ ] Validate fullscreen/window behavior and display scaling.
- [ ] Validate local settings/save behavior.
- [ ] Quit and relaunch.
- [ ] Reboot macOS and relaunch.
- [ ] Update the game and verify new build fingerprint/cache behavior.
- [ ] Capture compatibility workarounds in profiles when possible; implement targeted Rockstar/RAGE fixes when the evidence requires runtime or host changes.

**M4 exit gate:** the reference title can be installed and repeatedly launched from its macOS `.app` into real gameplay on supported hardware with the vendor's ownership/authentication intact.

### Important Rockstar/managed-launcher rule

Do **not** assume there is a documented “launch product X” command/API if the vendor has not documented one. The preferred order is:

1. legitimate title bootstrap executable inside the authenticated environment;
2. managed launcher flow;
3. additional generic launcher integration only when it is robust and legitimate.

Brittle screen-coordinate clicking is not the architecture.

## M5 — Native-feel product UX

**Status: 🟢 foundation / ⬜ polish.**

Goal: remove the remaining “wrapper” feel.

Acceptance criteria:

- [x] Native `.app` bundle generation.
- [x] Games category/high-resolution metadata.
- [x] Development signing/verification.
- [x] Native Rosetta missing-state/install action.
- [x] Per-title app-name environment bridge.
- [x] Engine patch point for native translated-process identity.
- [ ] Prove title identity in Dock/application menu on packaged runtime.
- [ ] First-run progress UI for runtime download/install and launcher setup.
- [ ] Clear “login required / install required / update required / ready / launching / running / failed” states.
- [ ] No terminal during normal use.
- [ ] User-friendly retry/recover actions.
- [ ] App icon/branding pipeline finalized.
- [ ] Proper macOS quit/reopen behavior.
- [ ] Accessibility/keyboard navigation pass for native host UI.

**M5 exit gate:** a non-developer can use the app without learning compatibility terminology.

## M6 — Performance and stability

**Status: 🟢 infrastructure / ⬜ measurements.**

Goal: make repeat launches smooth and prevent optimizations from becoming compatibility hazards.

Acceptance criteria:

- [x] Build-specific cache fingerprint.
- [x] Dedicated DXMT cache/log paths created before launch.
- [x] Bounded recent-build cache retention.
- [x] Runtime performance defaults with title environment override precedence.
- [x] Typed frame-pacing/MetalFX policy.
- [ ] Define repeatable per-title benchmark scenes/settings.
- [ ] Record cold launch, warm launch, shader-stutter behavior, frame pacing, memory use, and crash rate.
- [ ] Test common display modes/resolutions relevant to the target Mac.
- [ ] Validate update/cold-cache behavior.
- [ ] Add regression thresholds based on measured baselines rather than invented FPS promises.
- [ ] Long-session soak test.

**M6 exit gate:** repeatable measurements show no known severe stability regression and performance policy is documented per supported title/hardware class.

## M7 — Updates, recovery, and supportability

**Status: 🟢 primitives / ⬜ product flow.**

Goal: keep installed titles working when runtimes, profiles, launchers, games, or macOS change.

Acceptance criteria:

- [x] Verified runtime package install.
- [x] Resilient runtime catalog discovery.
- [x] Signed profile envelope/store primitives.
- [ ] Production profile signing key/rotation policy.
- [ ] Profile update transport/distribution policy.
- [ ] Runtime update/rollback policy.
- [ ] Detect failed update and preserve last-known-good runtime/profile.
- [ ] Repair/reinstall runtime without deleting target/prefix by default.
- [ ] User-facing support bundle with token/credential redaction.
- [ ] Version report includes host macOS, hardware class, runtime/profile/build fingerprint/backend, but no sensitive auth data.
- [ ] Launcher/game update compatibility regression playbook.

**M7 exit gate:** a bad compatibility update is recoverable and support data is safe/useful.

## M8 — Release engineering and compliance

**Status: ⬜ Planned.**

Goal: turn the engineering build into something that can be legitimately distributed.

Acceptance criteria:

- [ ] Inventory every redistributed component/version/license.
- [ ] Verify redistribution obligations for CodeWeavers/Wine sources, DXMT, GMP, Nettle, GnuTLS, FreeType, and any other bundled component.
- [ ] Include required notices/attribution and source availability/source offer where required.
- [ ] Do not bundle proprietary vendor game/launcher payloads unless redistribution is explicitly allowed.
- [ ] Finalize Developer ID signing for host/apps/runtime executables.
- [ ] Hardened-runtime compatibility review.
- [ ] Notarize release artifacts.
- [ ] Verify Gatekeeper behavior on a fresh Mac.
- [ ] Define release manifest/checksum/update hosting.
- [ ] Define uninstall behavior and data-retention choices.

**M8 exit gate:** release candidate is both technically portable and distributable under applicable licenses/platform requirements.

## M9 — v0.1 release candidate

**Status: ⬜ Planned.**

Goal: satisfy the Definition of complete on a fresh machine.

Final matrix should include at minimum:

- [ ] Fresh supported Apple Silicon system.
- [ ] System with Rosetta already present.
- [ ] System without Rosetta before first launch.
- [ ] First install/auth/title install.
- [ ] Warm second launch.
- [ ] Cold reboot launch.
- [ ] Game update.
- [ ] Runtime update.
- [ ] Profile update.
- [ ] Deliberately corrupt/missing runtime recovery.
- [ ] Network unavailable during runtime bootstrap.
- [ ] Launcher session expired/login required again.
- [ ] Clean uninstall/reinstall while preserving or deleting title data as selected.
- [ ] Signed/notarized artifact downloaded outside the development machine.

**M9 exit gate:** every mandatory release checklist item passes on the exact release candidate bytes.

---

# 11. CI and test policy

## Fast CI

`.github/workflows/ci.yml` currently:

1. checks the Swift version;
2. syntax-checks runtime shell tooling;
3. compile-checks and tests the native-identity patcher, then exercises the real workflow audit and native dylib relocation/load/signature regressions;
4. runs `swift test`;
5. builds release `outrage` and `outrage-host`.

A normal feature is not ready to stack more work on top of if fast CI is red for a real regression.

## Runtime Dependencies

`.github/workflows/runtime-deps.yml` builds the pinned x86-64 dependency prefix and verifies architecture for the relevant GMP/Nettle/Hogweed/FreeType/GnuTLS dylibs.

This lane exists so dependency failures can fail faster than a full compatibility-engine rebuild.

## Runtime Build

`.github/workflows/runtime-build.yml` is the expensive artifact gate. It must operate on the same package that would be uploaded:

1. build the runtime package;
2. install that package through `outrage runtime-install`;
3. resolve the installed runtime;
4. audit runtime dylib self-containment;
5. run DXMT builtin-module smoke;
6. create a real D3D11 device through the installed runtime;
7. run real Windows execution smoke;
8. inspect/checksum the package;
9. upload only after the gates pass.

### Expensive-build rule

Do **not** restart an hour-scale runtime compile for README/docs/profile-only work. Runtime workflows should remain path-scoped/manual-dispatch friendly. When a runtime-related input changes, the next heavy run must test the exact new package; otherwise leave a valid expensive run alone.

### Test-level rule

- Unit test: proves local logic.
- Integration test: proves components agree.
- Package smoke: proves the installed artifact can execute the required substrate.
- Real-title acceptance test: proves the user-facing path.

Never mark a real-title milestone complete because only the first two levels passed.

---

# 12. Developer CLI

The `outrage` utility currently exposes:

```text
outrage doctor
outrage paths
outrage runtimes
outrage runtime-build-metal <engine> <backend> <id> <version> <output-dir>
outrage runtime-pack <dir> <version> <output-dir>
outrage runtime-install <runtime.zip> <manifest.json>
outrage runtime-smoke-dxmt <runtime-id>
outrage validate <profile.json>
outrage plan <profile.json>
outrage prepare <profile.json>
outrage acquisition-plan <profile.json>
outrage probe <windows-executable>
outrage launch <profile.json> [--wait]
outrage bundle <profile.json> [--host ...] [--icon ...] [--output ...]
               [--unsigned | --sign-identity <identity>] [--hardened-runtime]
```

Useful local baseline:

```bash
swift test
swift build -c release --product outrage --product outrage-host
swift run outrage doctor
swift run outrage validate Profiles/bootstrap.json
```

The CLI is a developer surface. The final user experience must not require it.

---

# 13. Architectural invariants / decisions

Treat these as current project decisions. Change them only with an explicit reason and update this document when doing so.

1. **Product scope is Rockstar/RAGE.** Prefer profiles for title policy and reusable shared infrastructure, but allow measured, targeted RAGE compatibility code when a recipe is insufficient.
2. **One canonical runtime preparation path.** Direct, bootstrap, and managed-launcher flows must not drift.
3. **Legitimate auth/entitlement stays intact.** outRage orchestrates; it does not impersonate ownership.
4. **Explicit profile configuration beats defaults.** Typed convenience/performance policy must not silently override a deliberate title environment setting.
5. **DXMT builtin layout is not DXVK native-override layout.** Do not force native DLL overrides that would bypass the intended builtin path.
6. **Runtime install is strict; catalog discovery is resilient.** Bad incoming packages are rejected, but one damaged installed entry must not make all valid runtimes undiscoverable.
7. **End-user runtime is self-contained.** Homebrew may be a build dependency, never an end-user runtime dependency.
8. **Path mapping is safe.** Empty placeholders may be adopted; non-empty directories are protected.
9. **Game-process handoff excludes the launcher itself.** A launcher command line mentioning the game is not proof the game is running.
10. **Rosetta availability is proven by execution.** Do not infer it solely from filesystem artifacts.
11. **Cache identity follows target build identity.** A title update must not blindly reuse incompatible build state.
12. **Compatibility updates are verifiable.** Runtime packages and profile updates have integrity/authenticity gates.
13. **No hidden credential collection.** Logs/support bundles must be designed around this constraint.
14. **GTA V Legacy Story Mode is the first proof target.** Prefer profile data for its policy; use narrowly scoped Rockstar/RAGE fixes when real failures require code. Do not trade title correctness for hypothetical generality.

---

# 14. Key risks and mitigation

## ⚠️ Rosetta lifecycle

Apple controls Rosetta availability and future macOS behavior.

**Mitigation:** isolate CPU backend selection behind the backend model, detect by real execution, and keep the architecture capable of introducing another x86 execution backend such as FEX if/when technically viable.

## ⚠️ Launcher updates

Chromium/CEF-based launchers can change dependencies, login flows, process topology, bootstrap behavior, and update mechanisms.

**Mitigation:** carry the runtime dependencies a modern launcher legitimately needs; keep process matching/profile metadata flexible; avoid screen-coordinate automation; preserve diagnostics and fallback to visible launcher UI when required.

## ⚠️ DXMT/game rendering regressions

A title update or backend update can alter shader/API behavior.

**Mitigation:** pin known-good runtime components, use signed profile updates for title policy, keep build-specific caches, add repeatable rendering tests/benchmark scenes, and retain rollback paths.

## ⚠️ Anti-cheat / protected online modes

Some systems may require unsupported Windows/kernel behavior or prohibit compatibility layers.

**Mitigation:** do not circumvent them. Mark those modes unsupported unless a legitimate compatible configuration is verified.

## ⚠️ Dynamic library portability

Builds may accidentally link against Homebrew/runner/source-tree paths.

**Mitigation:** package-level `otool` audit, dylib relocation, re-signing, and fresh-environment tests before upload/release.

## ⚠️ Licensing/redistribution

Open-source components have obligations; proprietary launcher/game redistribution has separate restrictions.

**Mitigation:** complete M8 before public distribution; ship only what we are allowed to ship; keep third-party versions and sources reproducible.

## ⚠️ macOS signing/notarization

Ad-hoc development signing is not a release strategy.

**Mitigation:** test hardened-runtime constraints early enough to catch runtime/JIT/translation conflicts, then Developer ID sign and notarize exact release bytes.

## ⚠️ Hardware/display variation

Apple Silicon generation, unified memory, display refresh rate, scaling, and HDR can affect behavior.

**Mitigation:** establish supported hardware classes and test matrix based on measured results rather than blanket compatibility claims.

---

# 15. Working protocol for every future session

This is how we avoid another vague-repo state.

1. **Read `Current primary objective` and the active milestone first.**
2. **Check live CI only for lanes relevant to the current objective.** Do not churn expensive jobs unnecessarily.
3. **Choose the highest-priority unblocked checkbox.** Work on a concrete exit criterion, not general “cleanup.”
4. **Implement the smallest coherent slice that advances the milestone.**
5. **Add/adjust regression tests at the correct level.**
6. **Run/observe the appropriate gate.** A real external failure gets captured as evidence, not guessed around.
7. **If the failure is title-specific, prefer a profile fix. If generic, fix the core.**
8. **Update this handoff when status, decisions, risks, or next actions materially change.**
9. **Do not check off an acceptance criterion without evidence.**
10. **Keep commits meaningful.** The commit history should show milestone progress rather than dozens of unexplained one-off mutations.

When a long build is running, parallel work is allowed only if it does not invalidate/restart that proof unnecessarily.

---

# 16. Current ordered next actions

This is the queue to follow unless new evidence makes a higher item invalid.

1. **Prove the dependency isolation fix in a fresh Runtime Dependencies run.** The original failure was ARM Homebrew Brotli/Zstd contamination during GnuTLS installation; inspect the new run before claiming the x86-64 prefix works.
2. **Prove the spaced-path audit fix in a fresh Runtime Build run.** Build #5 stopped before auditing; capture the actual portability, DXMT, and Win32 results now that the complete runtime path reaches the auditor.
3. **Prove the newly integrated launcher runtime on the final commit.** The builder now constructs/reuses the pinned prefix, enables GnuTLS/FreeType, validates both configured SONAMEs against that prefix, and changes them to relocatable `@rpath` names. It rejects reuse of an older dependency-disabled engine. The new package version is `26.3.0+v0.80-launcher.1`; do not confuse it with the stripped foundation package.
4. **Inspect the integrated package bundling result.** The builder now relocates/signs the full engine and copies the dependency lock before packaging. GnuTLS uses `/dev/null` as its default priority-file path, consistent with the pinned Wine behavior, to avoid compiling the dependency prefix into runtime configuration; certificate verification remains enabled.
5. **Run the complete M2 gate on the dependency-integrated package:** install its own ZIP, portability audit, DXMT smoke, Win32 PE smoke. The CLI DXMT check proves builtin module loading, not GPU device creation; the workflow now additionally runs `smoke-d3d11-runtime.sh`. Neither graphics initialization nor launcher functionality is proven until those gates and real vendor flows pass.
6. **Create the first real Tier-3 reference title profile.** Keep product/process paths and launch policy in profile data.
7. **Run a real managed-launcher first-run:** installer → login → game install into mapped storage → launch.
8. **Prove title bootstrap if available, otherwise launcher fallback.** Do not invent undocumented entitlement shortcuts.
9. **Prove process handoff and real gameplay through Metal.** Record every failure at the layer where it occurs.
10. **Iterate M3/M4 until warm launch, cold reboot launch, update, quit, input/audio/network/display, and diagnostics pass.**
11. **Complete native-feel UX and support/recovery flows.**
12. **Benchmark/stability pass.**
13. **Release signing/notarization/license audit.**
14. **Run the M9 fresh-machine matrix on the exact release candidate.**

---

# 17. Reference-title support tiers

Use these tiers when describing compatibility so “supported” has a concrete meaning.

- **Tier 0 — Runtime substrate:** packaged Windows execution + intended graphics backend smoke works.
- **Tier 1 — Direct title:** executable launches directly without external authenticated launcher orchestration.
- **Tier 2 — Acquired/imported title:** Steam/import workflow is managed and repeatable.
- **Tier 3 — Managed authenticated title:** vendor launcher install/login/update + title install + launcher-to-game handoff + repeat launch works.
- **Release-supported:** Tier requirement plus real gameplay, input/audio/display/network requirements for the advertised mode, updates, recovery, diagnostics, signing/notarization, and documented limitations.

The first difficult Tier-3 title is the architecture proof. It is not permission to call every launcher/title supported.

---

# 18. Fresh-machine acceptance scenario

This is the story the release must ultimately pass without developer intervention:

1. User downloads a signed/notarized supported title app.
2. Gatekeeper accepts the app normally.
3. User opens it.
4. Host checks real x86-64 execution capability.
5. If Rosetta is absent, host offers Apple's supported install action, then rechecks.
6. Host verifies/installs the required outRage runtime.
7. Runtime passes local descriptor/integrity expectations.
8. If title is not installed, host enters acquisition/setup state.
9. Vendor launcher installer runs inside isolated prefix if required.
10. User logs into the vendor launcher directly.
11. User installs owned title; mapped path points payload to `Targets/<id>`.
12. Game launches; outRage identifies the real target process.
13. Launcher becomes an implementation detail; game receives title identity/environment/backend/cache policy.
14. Game renders through the intended Metal path and reaches supported gameplay.
15. User quits game; host/session exits cleanly.
16. User opens the title app again; authenticated/installed state is reused legitimately.
17. No terminal, Homebrew, Xcode, prefix editor, or manual DLL copying is involved.
18. If anything fails, the user gets a useful recovery state and can produce a redacted diagnostic bundle.

That scenario is the north star. Every subsystem should make one or more of those steps more deterministic.

---

# 19. Glossary

**Host** — native `outrage-host` process embedded in/generated for a title app; owns macOS lifecycle/UI.

**Profile** — versioned data describing how one title should be acquired, prepared, launched, identified, and tuned.

**Runtime** — packaged compatibility engine + graphics backend + required supporting libraries used to execute the Windows target.

**Prefix** — isolated Windows-like environment for one title/launcher.

**Target** — the actual managed game/title payload.

**Acquisition** — process by which the target becomes available: managed launcher, Steam, or import.

**Target bootstrap** — legitimate title-provided executable used to start the title through an already authenticated environment when supported.

**Process handoff** — transition from launcher/bootstrap ownership to monitoring the newly spawned real game process.

**Path mapping** — safe mapping from a prefix-visible Windows location to outRage-managed host storage.

**Build fingerprint** — identity derived from the current target build used to separate cache state across updates.

**DXMT** — Direct3D-to-Metal translation backend used by the current Metal runtime path.

**Smoke test** — minimal execution test that proves the installed packaged substrate actually functions, not only that files exist.

**Reference title** — first real title used to prove an entire support tier end-to-end.

---

# 20. Maintenance rule

This document is only useful if it stays honest.

Whenever a milestone materially changes:

- update the status table;
- check/uncheck the relevant acceptance criteria;
- update `Current primary objective` and `Current ordered next actions`;
- record a new risk/decision if the architecture changed;
- do not rewrite history to make an incomplete gate look complete.

**The repo should always make it possible for a new engineering session to answer three questions in under two minutes: _What are we building? What is proven? What is the next unblocked step?_**
