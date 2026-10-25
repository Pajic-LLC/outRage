# outRage Architecture

This document explains the current code-facing architecture. For product goals, live priorities, milestone status, acceptance criteria, risks, and the definition of completion, see [`../HANDOFF.md`](../HANDOFF.md).

## Design principle

outRage makes Rockstar RAGE-engine games feel like native Apple Silicon Mac games. GTA V Legacy Story Mode is the first target; see [the product vision](PRODUCT_VISION.md). Shared infrastructure stays reusable and testable, but product scope is Rockstar/RAGE.

The core rule is:

> **Title-specific behavior belongs in a profile whenever possible; runtime preparation and lifecycle behavior belong in shared code.**

Prefer declarative title recipes where they express the real behavior. Targeted Rockstar/RAGE compatibility code is appropriate when evidence shows a profile alone cannot solve the issue; do not let a generic abstraction obstruct the supported title path.

## Products

The Swift package currently exposes three products:

- **`OutRageKit`** — core profile/runtime/acquisition/launch logic.
- **`outrage`** — developer CLI for validation, diagnostics, packaging, smoke tests, planning, and launch experiments.
- **`outrage-host`** — native macOS lifecycle/UI host embedded in generated title applications.

## Launch flow

```text
Generated Title.app
        |
        v
    OutRageHost
        |
        +--> load bundled profile
        |       `--> resolve verified profile update when available
        |
        +--> detect host capabilities
        |       +--> CPU / architecture
        |       +--> Metal
        |       `--> Rosetta by real x86-64 execution probe
        |
        +--> resolve/bootstrap runtime
        |       +--> package source/cache
        |       +--> checksum/manifest validation
        |       +--> install into runtime catalog
        |       `--> resolve compatible descriptor
        |
        +--> prepare launch environment
        |       +--> isolated prefix
        |       +--> target storage
        |       +--> safe path mappings
        |       +--> graphics backend/overlays
        |       +--> DXMT cache/log directories
        |       +--> build fingerprint/cache state
        |       `--> performance policy
        |
        +--> resolve installation/acquisition state
        |       +--> direct/imported target
        |       +--> Steam
        |       `--> managed launcher
        |
        +--> start
        |       +--> direct executable
        |       +--> title bootstrap executable
        |       `--> managed launcher fallback
        |
        +--> process handoff
        |       `--> newly spawned target process matching profile policy
        |
        `--> monitor real target lifecycle / diagnostics / exit
```

## RuntimeProfile

`RuntimeProfile` is the central title contract. Schema v1 currently contains:

- identity: `id`, `displayName`, `bundleIdentifier`;
- executable: `executable`, `executableScope`, `workingDirectory`;
- runtime selection: `runtime`, `runtimeIdentifier`, `runtimePackageSource`;
- launch behavior: `launcher`, `cpu`, `graphics`, `arguments`, `environment`;
- virtualization/lifecycle: `pathMappings`, `processMatch`;
- tuning: `performance`;
- acquisition: `acquisition`.

Profiles are validated before launch. Unsafe absolute/traversal paths and invalid cross-field combinations are rejected early.

### Effective profile resolution

The generated app can carry a bundled profile while verified update machinery supplies a newer compatible profile. The effective profile is the one used for runtime preparation and launch. This lets compatibility policy change without rebuilding every title application.

Signed/verified profile updates are a security boundary: unverified data must never silently become executable launch policy.

## Runtime storage

Default macOS root:

```text
~/Library/Application Support/outRage/
```

```text
Runtimes/                 installed shared runtimes
Profiles/                 profile/update state
Targets/<profile-id>/     managed game payload
Prefixes/<profile-id>/    isolated compatibility prefix
Cache/RuntimePackages/    runtime download cache
Cache/<profile-id>/       per-title/build cache state
Logs/<profile-id>.log     per-title launch output
```

Target payload and prefix are deliberately separate. A launcher can see an expected Windows install path inside the prefix while `RuntimePathMapper` maps that location to managed title storage.

Mapping behavior must be conservative: an empty placeholder may be adopted; non-empty content is protected rather than silently replaced.

## Runtime model

A compatibility runtime is a versioned package described by a `RuntimeDescriptor` and installed in `Runtimes/`.

The current Apple Silicon path is an **x86-64 compatibility engine executed through Rosetta** with a Metal-oriented graphics backend. The current FOSS Metal builder pins a CodeWeavers/CrossOver source package and DXMT archive by version and SHA-256.

### Runtime lifecycle

1. Discover installed runtimes through `RuntimeCatalog`.
2. Ignore malformed installed catalog entries during discovery so one damaged runtime does not poison all valid entries.
3. Keep installation strict: incoming packages must validate.
4. Bootstrap/download a required package only from an accepted source with integrity metadata.
5. Install package into the catalog.
6. Prepare title-specific prefix/backend overlays and environment.
7. Execute through the selected CPU backend.

## CPU backend

`CPUBackend` currently models:

- `auto`
- `native`
- `rosetta`
- `fex`

Rosetta availability is determined by attempting real x86-64 execution, not by assuming a filesystem artifact means translation is usable.

The native host can present an Apple-supported Rosetta installation action when it is missing and re-probe afterward.

The enum intentionally leaves room for another translation backend without rewriting profile semantics.

## Graphics backend

`GraphicsBackend` currently models:

- `auto`
- `metal`
- `dxmt`
- `d3dMetal`
- `dxvk`
- `vkd3d`

The current FOSS Metal runtime uses DXMT. Its builtin layout is treated distinctly from a DXVK-style native override layout: the runtime must not force the wrong override mode and accidentally bypass DXMT.

`DXMTRuntimeSmokeVerifier` exists to prove that the installed packaged runtime can initialize the intended DXMT path, rather than only checking that DLL files exist.

## Runtime portability

Build-time dependencies are allowed on CI/developer machines. Runtime dependencies on Homebrew/MacPorts/developer paths are not.

Runtime tooling therefore includes:

- pinned source download/checksum validation;
- x86-64 dependency construction;
- dylib bundling/relocation;
- Mach-O load-command audit;
- code-signing of modified runtime binaries;
- package install verification;
- real Win32 execution smoke;
- DXMT initialization smoke.

A package should only be uploaded after the exact installed package passes the applicable gates.

## Prefix and environment preparation

`RuntimeEnvironmentPreparer` is intended to be the canonical preparation layer used by all launch paths.

Responsibilities include:

- ensure the runtime/profile directories exist;
- prepare the isolated prefix;
- apply safe path mappings;
- prepare graphics overlays/backend configuration;
- create backend cache/log directories before execution;
- apply performance/runtime defaults;
- preserve explicit per-title environment precedence;
- prepare build-specific cache state.

Direct launch, title-bootstrap launch, and managed-launcher launch must not duplicate or diverge from these semantics.

## Acquisition

`AcquisitionDescriptor` currently supports:

### Managed launcher

Describes a launcher installer and optional checksum/arguments, the installed launcher executable, launcher arguments, and optionally a target bootstrap executable.

The launcher owns its authentication/entitlement state. outRage must not capture credentials or bypass ownership checks.

### Steam

Describes a Windows Steam app ID and optional branch for acquisition into managed target storage.

### Import existing

Describes a target already present/placed in managed storage.

Acquisition gets a title into a launchable state; it is intentionally separate from the launch session itself.

## Managed launcher and target bootstrap

A managed title may have three relevant executable roles:

1. **Installer** — first-run setup only.
2. **Managed launcher** — vendor UI/auth/update fallback.
3. **Target bootstrap** — optional legitimate title-provided executable that can initiate the owned title through an authenticated environment.

The target bootstrap exists so a routine launch does not have to pretend the launcher's visible UI is the only entry point when the title already supplies a legitimate bootstrap mechanism.

If the bootstrap is unavailable or does not work, outRage falls back to the managed launcher. It does not invent an undocumented DRM/entitlement bypass.

## Process handoff

Managed launchers often remain alive after starting a game. The host therefore cannot equate “launcher process exited” with “game session ended.”

The handoff model:

1. capture a baseline of relevant processes before starting launcher/bootstrap;
2. start the launcher/bootstrap;
3. observe new processes;
4. match the profile's configured `processMatch` (or target executable basename);
5. explicitly reject the launcher PID as the game even if the launcher command line mentions the target executable;
6. adopt the real target process;
7. keep the host alive until the target session ends.

The same detection path also lets first-run setup adopt a game the user starts manually from an already-visible launcher instead of starting a duplicate copy.

## Performance/cache model

Performance policy is data-driven. Current typed policy includes:

- preferred maximum frame rate;
- MetalFX spatial-upscaling enablement;
- MetalFX spatial upscale factor.

Explicit profile environment values remain authoritative over generated defaults.

Target executable fingerprinting creates build-specific cache identity. This prevents a game update from blindly inheriting stale shader/runtime state while allowing a bounded set of recent build caches to remain available.

Performance tuning must be measured per supported title/hardware configuration; the architecture should not encode arbitrary global FPS assumptions.

## Native application identity

Generated `.app` bundles carry title metadata and are ad-hoc signable/verifiable for development.

For the translated child path, outRage propagates `OUTRAGE_APP_NAME`. The runtime build applies a guarded/idempotent winemac source patch that can use that identity for the macOS process/application menu instead of presenting a generic compatibility-engine name.

The patcher is designed to fail closed if expected upstream source anchors move so a source update cannot silently apply a malformed patch.

## Signing

There are two distinct concerns:

- **Development correctness:** generated app bundles and modified runtime Mach-O files can be ad-hoc signed/verified so local execution does not depend on undefined signing state.
- **Release trust:** public artifacts must ultimately use an appropriate Developer ID/hardened-runtime/notarization strategy and satisfy Gatekeeper on a fresh Mac.

Development ad-hoc signing must never be confused with release readiness.

## Diagnostics

The architecture uses stable per-title logs plus developer inspection through the CLI (`doctor`, `plan`, `prepare`, `probe`, runtime listing/smoke commands).

The release path still needs a user-facing support bundle that gathers relevant versions, runtime/profile/backend/build fingerprint, and logs while explicitly redacting credentials, tokens, and private authentication state.

## Testing layers

The project intentionally distinguishes:

1. **Unit tests** — local behavior and invariants.
2. **Integration tests** — core components compose correctly.
3. **Packaged runtime smoke tests** — the exact installed artifact executes Windows code and initializes the intended graphics path.
4. **Real-title acceptance tests** — launcher/install/gameplay/update/quit behavior on supported hardware.

A feature can be implemented at levels 1–2 while still being unproven at levels 3–4. See `HANDOFF.md` for the current status matrix and milestone exit gates.

## Security and product boundaries

The architecture assumes legitimately owned software and keeps vendor authentication/entitlement checks intact. outRage does not need launcher passwords, should not log them, and should not patch game binaries to bypass DRM or anti-cheat.

Installer/runtime/profile inputs are treated as executable policy and therefore require validation/integrity controls appropriate to their source.

## Where to continue

Do not use this architecture document as a to-do list. The ordered implementation queue and current active milestone are maintained in [`HANDOFF.md`](../HANDOFF.md).
