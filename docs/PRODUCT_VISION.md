# outRage — Product Vision

> Product direction supplied by the project owner on 2026-10-25. For current implementation status, evidence, and ordered engineering work, see [HANDOFF.md](../HANDOFF.md). Roadmap descriptions below are goals, not evidence of shipped support.

## Read this first

**outRage is a macOS compatibility platform dedicated specifically to Rockstar Games titles built on or closely associated with the RAGE ecosystem.**

It is **not** intended to become a general-purpose Windows game launcher.

It is **not** “Wine with a GUI.”

It is **not** a generic replacement for CrossOver, Whisky, Heroic, Porting Kit, or similar software.

The reason this project exists is much narrower and more ambitious:

> **Make RAGE-engine Rockstar games feel as close to native macOS games as technically possible on Apple Silicon.**

Everything in the architecture, UX, compatibility patches, runtime packaging, launcher handling, performance work, title profiles, process management, graphics stack, filesystem layout, and future development must serve that goal.

If a generic abstraction conflicts with making Rockstar/RAGE titles work better, **optimize for RAGE titles**.

---

# 1. The vision

The eventual user experience should be almost indistinguishable from owning a native Mac version of a Rockstar title.

The user should be able to have applications such as:

- Grand Theft Auto V
- Grand Theft Auto IV
- Red Dead Redemption 2
- Max Payne 3
- GTA V Enhanced
- future compatible RAGE titles

appear as ordinary macOS applications.

The user should not need to understand:

- Wine
- Wine prefixes
- Windows DLL overrides
- DXMT
- D3DMetal
- Rosetta
- Windows filesystem mappings
- Rockstar Games Launcher internals
- Steam depots
- shader caches
- environment variables
- compatibility patches

Those are outRage implementation details.

The desired user experience is simply:

**Install → Play.**

---

# 2. The north-star experience

Imagine somebody downloads outRage on an Apple Silicon Mac.

They select **Grand Theft Auto V**.

outRage determines whether they own it through a supported legitimate source.

If necessary it asks them to sign into Steam or Rockstar.

The Windows game files are obtained legitimately.

outRage silently prepares:

- the correct compatibility runtime,
- the correct Wine prefix,
- the Rockstar launcher environment,
- the Metal graphics translation layer,
- RAGE-specific compatibility fixes,
- filesystem mappings,
- controller configuration,
- audio configuration,
- shader caches,
- process handling,
- title identity,
- and performance settings.

The user eventually gets:

**Grand Theft Auto V.app**

They launch it from:

- Finder,
- Spotlight,
- Launchpad,
- the Dock,
- or outRage itself.

They see normal Mac behavior.

The Rockstar launcher should appear only when it genuinely must appear for authentication, installation, updates, consent, or another required vendor workflow.

Otherwise the user should feel like they launched **GTA V**, not “a Windows compatibility environment.”

When the game starts, outRage should hand the visible session over to the actual game process.

When the game exits, the Mac application exits cleanly.

If something fails, outRage should explain the problem in normal user language rather than exposing Wine errors.

That is the product.

---

# 3. Why outRage is RAGE-specific

Generic Windows compatibility layers already exist.

outRage only makes sense if it can go substantially deeper than them for this particular family of games.

We can exploit knowledge of:

- Rockstar launch behavior,
- Rockstar Games Launcher,
- Social Club dependencies,
- RAGE process trees,
- known executable structures,
- expected Windows directories,
- per-title graphics APIs,
- RAGE timing behavior,
- RAGE filesystem assumptions,
- RAGE input behavior,
- shader behavior,
- RAGE memory behavior,
- title-specific DLL requirements,
- title-specific startup sequences,
- title-specific launcher quirks,
- title-specific patches,
- title-specific performance characteristics.

The long-term goal is therefore effectively:

> **A RAGE compatibility layer for macOS.**

Wine is one component of it.

DXMT is one component of it.

Rosetta is one component of it.

The Rockstar launcher is one component of it.

None of those individually define outRage.

---

# 4. Core supported-title strategy

Do not attempt every Rockstar game simultaneously.

The intended progression is:

### Tier 1 — GTA V Legacy

This should be our first flagship target.

Reasons:

- mature RAGE title,
- Direct3D 11,
- enormous user base,
- well-understood Windows behavior,
- excellent test case for DXMT,
- Rockstar Games Launcher involvement,
- representative of the problems outRage exists to solve.

The first major product milestone is:

> **Grand Theft Auto V Story Mode launching from a normal macOS application on Apple Silicon through a fully outRage-managed environment.**

### Tier 2 — GTA IV

Useful because it exercises an older generation of RAGE and older Windows assumptions.

### Tier 3 — Max Payne 3

Another important Rockstar/RAGE-era compatibility target.

### Tier 4 — Red Dead Redemption 2

A considerably more demanding RAGE generation and an important graphics/runtime milestone.

### Tier 5 — GTA V Enhanced

Adds newer graphics and runtime complexity.

### Tier 6 — future RAGE titles

The architecture should eventually allow new RAGE games to gain support through:

- new profiles,
- compatibility packs,
- runtime changes,
- small targeted patches,

rather than rebuilding outRage from scratch.

---

# 5. Acquisition is part of the product

A major problem on macOS is not merely executing the game.

We first need to get the legitimate Windows game files onto the Mac.

outRage must solve this cleanly.

## Steam-owned titles

The preferred strategy is direct legitimate Windows depot acquisition.

Steam tooling can request the Windows version of an owned title even from macOS.

outRage should eventually hide the underlying Steam machinery behind native UI.

Conceptually:

**Steam sign-in → ownership validation → Windows game depot → outRage game storage**

The user should not manually use SteamCMD.

outRage should orchestrate it.

## Rockstar-owned titles

The Rockstar Games Launcher has no native macOS version.

For Rockstar purchases, outRage should run the **real Rockstar Games Launcher** inside an outRage-managed Windows compatibility environment.

That means:

**outRage → managed Wine environment → official Rockstar Games Launcher → user authentication → legitimate download/install**

The vendor launcher remains responsible for:

- authentication,
- ownership,
- licensing,
- updates where required.

outRage is responsible for making that Windows software function correctly on macOS.

---

# 6. Important legal and technical boundary

outRage is an interoperability and compatibility project.

It must **not** become a DRM bypass.

Do not implement:

- ownership spoofing,
- Rockstar authentication bypasses,
- Steam authentication bypasses,
- cracked executables,
- launcher credential interception,
- license emulation,
- anti-cheat bypasses,
- pirated depot acquisition,
- redistribution of Rockstar game files.

Use legitimate vendor flows.

If Rockstar Launcher authentication is required, run Rockstar Launcher.

If Steam ownership is required, authenticate with Steam.

If a title's online anti-cheat does not support the compatibility environment, mark that mode unsupported.

Story Mode compatibility is considerably more important than trying to defeat an anti-cheat system.

---

# 7. macOS-first product architecture

The visible product should be native macOS software.

The primary application layer should use:

- Swift
- SwiftUI
- AppKit where necessary

The Mac host should own:

- setup,
- installation,
- library management,
- title state,
- launch state,
- errors,
- updates,
- diagnostics,
- process ownership,
- native notifications,
- Finder/Dock integration.

Windows compatibility software should remain behind this host.

The user should not interact with raw Wine unless debugging.

---

# 8. CPU execution strategy

Current Apple Silicon Macs are ARM64.

Most Rockstar PC titles we care about are x86-64 Windows applications.

The initial practical execution path is therefore:

**Windows x86-64 game  
→ x86-64 Wine-compatible runtime  
→ Rosetta  
→ Apple Silicon**

This is acceptable for the first production architecture.

Rosetta detection and legitimate installation support should be integrated into the native outRage onboarding experience.

Longer term, investigate:

**Windows x86-64  
→ ARM64 Wine  
→ FEX or equivalent x86 translation  
→ Apple Silicon**

The architecture should therefore keep CPU backends modular.

Expected backend concepts include:

- native
- Rosetta
- FEX
- automatic selection

Do not hard-code the entire application around Rosetta forever.

---

# 9. Graphics strategy

The most important objective is:

> **Translate RAGE's Windows graphics workloads to Metal with as little overhead as practical.**

The graphics backend must remain swappable per title.

## Direct3D 11 titles

DXMT is the preferred open-source path where compatible.

This is particularly important for GTA V Legacy.

Conceptually:

**RAGE D3D11  
→ DXMT  
→ Metal  
→ Apple GPU**

## Direct3D 12 titles

D3DMetal / Game Porting Toolkit technology may provide an appropriate path where its licensing and redistribution terms allow it.

The graphics abstraction therefore must support multiple backend types.

Examples already represented by the project include:

- Metal
- DXMT
- D3DMetal
- DXVK
- VKD3D

Not every backend has to ship.

The important architectural point is that profiles choose the correct graphics path instead of embedding it globally.

---

# 10. The RAGE compatibility layer

This is ultimately the part that should make outRage special.

Over time, build a RAGE-focused compatibility layer containing targeted fixes for problems such as:

- Rockstar Launcher startup behavior
- Social Club
- launcher CEF/web components
- CPU capability detection
- synchronization primitives
- process spawning
- timing behavior
- Windows registry assumptions
- Windows filesystem assumptions
- AppData/Documents mappings
- controller/XInput handling
- audio behavior
- fullscreen/window behavior
- display enumeration
- Metal translation quirks
- shader compilation
- shader cache persistence
- memory allocation behavior
- thread scheduling
- title-specific DLL expectations
- Rockstar overlay behavior
- launcher-to-game handoff
- game-to-launcher handoff
- crash reporting
- native Mac application identity
- save locations
- title-specific performance tuning

Whenever a repeatable RAGE-specific workaround is discovered, prefer turning it into structured compatibility behavior rather than asking users to configure it manually.

---

# 11. Profiles are compatibility recipes

Each supported title should have a versioned outRage profile.

A profile describes how outRage handles that title.

Profiles may specify:

- title ID,
- display name,
- bundle ID,
- executable,
- process match,
- working directory,
- runtime version,
- CPU backend,
- graphics backend,
- launcher mode,
- environment variables,
- Windows path mappings,
- acquisition source,
- Steam application ID,
- Rockstar launcher details,
- startup arguments,
- bootstrap executable,
- performance policy,
- compatibility flags.

Eventually profiles should also support:

- tested game build ranges,
- runtime compatibility ranges,
- minimum macOS version,
- minimum hardware class,
- title-specific patches,
- recommended settings,
- known unsupported modes,
- save-path behavior,
- launcher version requirements.

The goal is:

> Supporting another RAGE title should increasingly mean creating or updating a compatibility recipe rather than writing another launcher.

---

# 12. The runtime

outRage needs its own reproducible compatibility runtime.

The end user must **not** install:

- Homebrew,
- developer Wine,
- random dylibs,
- Xcode,
- terminal dependencies.

We build the runtime ourselves and distribute a self-contained package.

The runtime currently revolves around an x86-64 Wine-derived engine plus a Metal graphics backend.

Runtime packages must be:

- versioned,
- reproducible,
- checksum verified,
- auditable,
- self-contained,
- installable into outRage's runtime catalog.

No runtime may depend on paths such as:

- `/opt/homebrew`
- developer machines
- CI runner directories
- arbitrary system packages

after packaging.

All non-system dependencies must be bundled and relocated appropriately.

---

# 13. Runtime verification

A runtime package is not considered working just because it compiled.

There must be escalating proof levels.

### Level 1 — build proof

Runtime compiles.

### Level 2 — package proof

Archive and manifest are produced.

### Level 3 — portability proof

Mach-O dependencies resolve only to:

- macOS system libraries,
- or libraries contained in the runtime.

### Level 4 — execution proof

A Windows x86-64 executable successfully runs through the packaged runtime.

### Level 5 — graphics proof

DXMT or the selected graphics backend successfully initializes through the packaged runtime.

### Level 6 — launcher proof

Rockstar Games Launcher successfully starts and functions.

### Level 7 — title proof

A real RAGE game reaches gameplay.

### Level 8 — product proof

The same title can be launched from a normal signed outRage-generated `.app` on a clean Mac without developer tooling.

That distinction is extremely important.

Do not call something “complete” because unit tests pass.

---

# 14. Rockstar Games Launcher lifecycle

The Rockstar launcher is a first-class compatibility target.

It cannot be treated as an annoying popup.

outRage must understand its lifecycle.

A typical first-run sequence may be:

1. Launch outRage title app.
2. Validate runtime.
3. Validate/create title prefix.
4. Install Rockstar Games Launcher if absent.
5. Run Rockstar Games Launcher.
6. User signs in.
7. User completes vendor-required actions.
8. Launcher installs or recognizes title.
9. outRage detects title installation.
10. outRage establishes subsequent bootstrap strategy.

On later launches:

1. User opens title `.app`.
2. outRage resolves the profile.
3. Runtime and prefix are prepared.
4. Required Rockstar services/processes start.
5. Launcher is bootstrapped only as much as required.
6. Game starts.
7. outRage detects the actual game executable.
8. Native host treats that executable as the primary session.
9. Launcher windows should remain invisible/minimized where technically safe and legitimate.

Do not break authentication or updates merely to hide the launcher.

Correctness first.

Transparency second.

---

# 15. Game process handoff

When a launcher starts a title, the launcher process is not the game.

outRage must track the process tree and identify the real title executable.

For example conceptually:

**outRage host  
→ Wine  
→ Rockstar Launcher  
→ Rockstar service/helper processes  
→ GTA5.exe**

Once `GTA5.exe` exists, the session should revolve around it.

This affects:

- Dock state,
- launch state,
- game-running state,
- quit behavior,
- crash detection,
- logs,
- title identity,
- performance telemetry.

Profiles already include concepts such as `processMatch` for this reason.

Continue developing this into robust launcher-to-game process adoption.

---

# 16. Filesystem experience

Each title should be isolated.

Something conceptually similar to:

`~/Library/Application Support/outRage/`

containing:

- `Runtimes/`
- `Profiles/`
- `Prefixes/`
- `Targets/`
- `Cache/`
- `Logs/`

Each title gets independent managed storage.

Avoid one enormous shared Wine prefix.

Reasons:

- easier compatibility tuning,
- fewer launcher conflicts,
- easier recovery,
- easier deletion,
- easier diagnostics,
- safer updates.

The Windows environment may expect directories such as:

`C:\Program Files\Rockstar Games\`

while the real bytes live somewhere appropriate in the Mac filesystem.

outRage should manage that translation.

---

# 17. Native title wrappers

A supported game should eventually get a normal application bundle.

Example:

`Grand Theft Auto V.app`

The generated bundle should contain the outRage host plus the title profile.

Its macOS metadata should include:

- title name,
- title icon,
- unique bundle identifier,
- Games category,
- proper high-resolution support,
- signing metadata.

Launching that application should invoke outRage's runtime orchestration automatically.

The user should not see:

`wine GTA5.exe`

They should see:

**Grand Theft Auto V**

---

# 18. Native identity

Where technically possible, remove generic compatibility-layer identity from the user experience.

Examples:

Instead of:

- Wine
- wine64
- Wine Preloader

prefer:

- Grand Theft Auto V
- Red Dead Redemption 2
- Rockstar Games Launcher when the launcher itself is actually visible

The project already has work around winemac native identity.

Continue that direction carefully.

Do not fake process identity in ways that break functionality.

---

# 19. First-run native setup

If Rosetta is required and missing, outRage should handle this as a normal Mac onboarding state.

The user should not receive:

“bad CPU type”

or a terminal command.

Instead:

**Grand Theft Auto V requires Apple's Rosetta compatibility component. Install Rosetta?**

Use Apple's legitimate system installation flow.

After installation, continue the setup automatically where practical.

The same principle applies to:

- runtime installation,
- profile updates,
- launcher installation,
- missing title files.

---

# 20. Performance philosophy

The end goal is not merely:

> “It starts.”

The end goal is:

> **RAGE games running unusually well for Windows games on Apple Silicon because outRage understands them specifically.**

Performance work should eventually cover:

- shader caches,
- precompilation where possible,
- frame pacing,
- Metal resource behavior,
- CPU/GPU synchronization,
- Rosetta overhead,
- unified-memory behavior,
- graphics settings recommendations,
- resolution scaling,
- MetalFX where appropriate,
- RAGE worker-thread behavior,
- CPU scheduling,
- game-specific launch parameters.

Profiles already contain performance-policy concepts.

Expand these only where they represent actual measurable behavior.

Do not add fake “optimization” switches.

---

# 21. Apple Silicon should be treated as one platform family

outRage should detect host capabilities rather than assuming every Mac is identical.

Useful inputs include:

- Apple Silicon generation,
- GPU capabilities,
- unified memory,
- available working set,
- macOS version,
- Rosetta availability,
- graphics backend support.

Eventually outRage can recommend appropriate presets for different classes of machines.

Examples:

- baseline Apple Silicon
- Pro chips
- Max chips
- Ultra-class machines

But hardware tuning should be evidence-based.

---

# 22. Diagnostics

Compatibility failures are unavoidable.

The product should make them understandable.

Each launch should have structured diagnostics such as:

- outRage version,
- title profile version,
- detected game build,
- runtime version,
- Wine engine version,
- graphics backend version,
- macOS version,
- Mac hardware,
- CPU backend,
- launcher version,
- relevant environment configuration,
- process tree,
- exit code,
- compatibility warnings.

Logs should be easy to export.

The eventual user experience might simply say:

**Grand Theft Auto V could not start.**

Then provide:

- Retry
- Repair
- View details
- Export diagnostics

Never make normal users parse a Wine terminal log.

---

# 23. Repair should be built into the architecture

Because titles involve multiple layers, outRage should eventually know how to repair them independently.

Possible repair operations:

- verify runtime,
- reinstall runtime,
- recreate prefix,
- repair Rockstar Launcher,
- verify title files,
- clear shader cache,
- reset compatibility configuration,
- regenerate `.app`,
- restore default profile.

Do not force users to delete mysterious folders manually.

---

# 24. Updating

There are several different kinds of updates:

### outRage application update

Updates the Mac host.

### Runtime update

Updates Wine/RAGE compatibility components.

### Graphics backend update

For example DXMT.

### Profile update

Changes compatibility behavior for a specific RAGE title.

### Vendor launcher update

Handled by Rockstar/Steam where appropriate.

### Game update

Handled through the legitimate owning platform.

Keep these separate.

A GTA V profile fix should not require rebuilding the entire outRage app.

---

# 25. Compatibility regression testing

RAGE games and launchers update.

Something working today may fail tomorrow.

Eventually maintain a matrix approximately like:

| Title | Game Build | Runtime | Graphics | macOS | Status |
|---|---|---|---|---|---|
| GTA V Legacy | build X | runtime Y | DXMT Z | macOS N | working |
| GTA IV | build X | runtime Y | DXMT Z | macOS N | working |
| RDR2 | build X | runtime Y | D3DMetal Z | macOS N | partial |

Profiles should be versioned and testable.

If Rockstar changes its launcher, that should become a tracked compatibility regression rather than random user breakage.

---

# 26. Online play and anti-cheat

Do not build an anti-cheat bypass.

If Rockstar Online or another network mode requires technology that rejects Wine/outRage, report it accurately.

For the initial versions:

**Story Mode is the priority.**

Online functionality may be supported only when it naturally works through legitimate vendor software.

The existence of unsupported multiplayer must never block excellent single-player compatibility.

---

# 27. Relationship to ENRAGE

outRage and ENRAGE are separate projects.

### outRage

Makes RAGE games run well on macOS.

### ENRAGE

Future mod-loader/modding infrastructure for RAGE titles.

Do not merge ENRAGE into outRage's runtime architecture right now.

However, later ENRAGE should be able to detect when a game is running through outRage and integrate with it where useful.

Think of it conceptually as:

**outRage = platform compatibility**

**ENRAGE = game modification platform**

Separate responsibilities.

---

# 28. What outRage must NOT become

Do not drift into building:

- a generic Windows app launcher,
- a general Wine bottle manager,
- a giant UI over arbitrary Wine configuration,
- an Epic/GOG/etc. launcher just because we technically can,
- a universal PC gaming compatibility platform,
- a virtual machine frontend.

A generic subsystem is fine **when it helps RAGE titles**.

But product scope remains:

> **Rockstar / RAGE on macOS.**

The specificity is a feature.

---

# 29. Current implementation direction

The existing repository already contains substantial foundation work including concepts for:

- Swift host
- CLI tooling
- runtime profiles
- runtime storage
- runtime catalogs
- acquisition descriptors
- launch planning
- executable probing
- native `.app` generation
- code signing
- Rosetta handling
- graphics backend selection
- DXMT runtime verification
- runtime packaging
- runtime installation
- dependency auditing
- RAGE/title process matching
- managed launcher acquisition
- title path mappings
- performance policy
- Wine-derived x86-64 runtime builds

Do not throw this architecture away.

Continue it toward the RAGE-specific product vision described above.

The missing work is primarily turning these foundations into a complete real-title product path.

---

# 30. Immediate engineering objective

The immediate objective is:

> **Prove GTA V Legacy Story Mode from legitimate ownership to gameplay through outRage on Apple Silicon.**

That means completing the sequence:

1. Produce a fully self-contained x86-64 runtime.
2. Ensure it runs correctly through Rosetta.
3. Ensure DXMT initializes correctly.
4. Make the runtime capable of running Rockstar Games Launcher dependencies.
5. Install the official Rockstar Games Launcher into a managed prefix.
6. Complete Rockstar login successfully.
7. Obtain or recognize legitimate GTA V files.
8. Launch GTA V.
9. Detect `GTA5.exe`.
10. Reach Story Mode.
11. Keep graphics translated through Metal.
12. Exit cleanly.
13. Repeat launch without manual Wine interaction.
14. Launch through `Grand Theft Auto V.app`.

Until this works, do not spend substantial effort on decorative UI or broad support for unrelated software.

---

# 31. Milestone roadmap

## M0 — Core orchestration foundation

Required pieces:

- profiles
- host capability discovery
- runtime paths
- launch planning
- CLI
- app wrapper generation
- runtime catalog

Largely established.

---

## M1 — Packaged executable runtime

Requirements:

- build x86-64 Wine-compatible engine
- package runtime
- install runtime
- execute Win32 code
- verify checksums
- verify architecture
- eliminate developer-path dependencies

Largely established, but keep strengthening portability.

---

## M2 — Launcher-capable runtime

This is the current major infrastructure milestone.

Requirements include whatever the official Rockstar Games Launcher actually needs, potentially including:

- TLS/network stack,
- fonts,
- CEF dependencies,
- Windows services,
- cryptographic APIs,
- audio/input dependencies,
- launcher helper processes.

Do not guess.

Run the launcher and fix concrete failures.

Exit condition:

> Official Rockstar Games Launcher can install, update, render UI, authenticate, and remain stable inside an outRage-managed prefix on Apple Silicon.

---

## M3 — Rockstar lifecycle orchestration

Automate:

- launcher installation,
- prefix preparation,
- launch,
- authentication state,
- updates,
- title detection,
- process adoption,
- restart behavior.

Exit condition:

> The user can interact with the Rockstar launcher through outRage without touching Wine tooling.

---

## M4 — GTA V Legacy first gameplay

This is the major proof milestone.

Exit condition:

> GTA V Legacy reaches Story Mode through DXMT/Metal on Apple Silicon from legitimate game files.

Capture:

- runtime version
- game build
- macOS version
- Mac model/chip
- first-frame time
- basic FPS/frame pacing
- known rendering issues
- input status
- audio status
- save status

---

## M5 — Native GTA V application experience

Exit condition:

> A user launches `Grand Theft Auto V.app`, reaches GTA V, plays, quits, and never needs to know that Wine exists.

Includes:

- native setup UI
- title identity
- clean process handoff
- native errors
- Dock behavior
- launcher hiding where safe
- diagnostics

---

## M6 — Performance and stability

Work on:

- shader caching,
- stutter,
- frame pacing,
- memory,
- Metal behavior,
- controller support,
- audio,
- fullscreen,
- sleep/wake,
- repeated launches,
- game updates.

Exit condition:

> GTA V is not merely bootable; it is realistically playable for extended sessions.

---

## M7 — Additional RAGE titles

Suggested order:

1. GTA IV
2. Max Payne 3
3. Red Dead Redemption 2
4. GTA V Enhanced

Each title should increase our understanding of the RAGE compatibility surface.

---

## M8 — Release-quality product

Includes:

- polished SwiftUI application
- title library
- Install/Play states
- progress
- repair
- diagnostics
- runtime/profile updates
- Developer ID signing
- notarization
- safe update system

---

## M9 — outRage v1

v1 should mean:

> A normal Mac user with supported Apple Silicon hardware and legitimate ownership can install and play supported Rockstar/RAGE titles without configuring a Windows compatibility environment themselves.

---

# 32. Development priorities

When choosing what to work on, use this priority order:

1. **Does the real RAGE title launch?**
2. **Is the runtime correct and reproducible?**
3. **Does the Rockstar launcher work?**
4. **Does Metal rendering work correctly?**
5. **Does the title run stably?**
6. **Does it perform well?**
7. **Does it feel native?**
8. **Can the workflow be automated further?**
9. **Can the solution generalize to another RAGE title?**
10. Cosmetic polish.

Do not reverse this order.

---

# 33. Engineering philosophy

### Prefer proof over theory

Running GTA V is more valuable than writing another abstraction around a hypothetical future game.

### Prefer deterministic systems

Runtime packages, profiles, manifests, and patches should be reproducible.

### Prefer title-specific knowledge when it creates a better product

We are intentionally not afraid of RAGE-specific code.

### Keep generic infrastructure underneath

Process management, package verification, runtime installation, etc. should remain reusable where sensible.

### Never expose complexity just because the stack is complicated

Complex architecture is our problem, not the user's.

### Avoid permanent hacks

When a temporary workaround proves necessary, document why it exists and what would replace it.

---

# 34. Definition of “native-feeling”

The word **native** in this project does not mean the RAGE executable magically becomes ARM64 Mach-O.

It means the *experience* behaves like a Mac application.

Native-feeling includes:

- ordinary `.app`
- Mac icon
- normal Dock behavior
- native setup UI
- no terminal
- no Wine configuration UI
- sensible file locations
- native error dialogs
- clean launching/quitting
- controller support
- Retina/fullscreen behavior
- good Metal performance
- automatic compatibility configuration
- updates handled intelligently
- minimum visible Windows plumbing

The user should forget the compatibility layer exists.

---

# 35. The product sentence

When uncertain about scope, return to this sentence:

> **outRage makes Rockstar RAGE-engine games feel like native Apple Silicon Mac games.**

Every major feature should be defensible against that sentence.

---

# 36. Instructions for Codex

You are continuing an existing project, not designing an unrelated replacement.

Before changing architecture:

1. Inspect the existing implementation.
2. Understand the current runtime/profile/launcher model.
3. Check the current handoff and architecture docs.
4. Preserve working functionality.
5. Make incremental, testable changes.
6. Run relevant tests.
7. Add regression coverage where appropriate.
8. Update documentation when project state materially changes.

Do not broaden product scope into generic Windows compatibility unless specifically instructed.

When an engineering decision has two options, ask:

> **Which option gets a RAGE title closer to behaving like a native Mac game?**

Choose that one.

The immediate north star is not a perfect framework.

The immediate north star is:

> **Grand Theft Auto V Story Mode running from `Grand Theft Auto V.app` on an Apple Silicon Mac with legitimate game ownership, Metal rendering, outRage-managed compatibility, and no user-facing Wine configuration.**

Build toward that until it is real.