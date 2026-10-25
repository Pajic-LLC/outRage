# outRage

outRage is a **pre-alpha macOS compatibility runtime and orchestration layer** for making legitimately owned Windows games behave like native-feeling Apple Silicon `.app` bundles.

The project combines a native Swift host, data-driven per-title profiles, isolated prefixes and managed game storage, a packaged x86-64 compatibility runtime, Metal-oriented graphics translation, verified runtime/profile updates, and managed-launcher process handoff.

> **Status:** pre-alpha engineering project. There is no supported public release yet.

## Goal

The end-state experience is simple: double-click a title `.app` and let outRage handle the compatibility implementation details — host capability checks, Rosetta setup when required, verified runtime installation, prefix preparation, launcher setup/authentication, install-path mapping, graphics backend selection, process handoff, caches, diagnostics, and clean session lifecycle.

The user should not need Homebrew, Xcode, a terminal, a prefix editor, or manual DLL configuration.

Authentication, ownership, entitlement, launcher updates, and DRM remain with the game/vendor. **outRage is not a DRM bypass.**

## Start here

- **[Engineering handoff / living completion plan](HANDOFF.md)** — authoritative mission, current status, milestones, acceptance criteria, risks, and ordered next work.
- **[Architecture](docs/ARCHITECTURE.md)** — code-facing subsystem and launch-flow overview.

If you are continuing development, read `HANDOFF.md` before changing the roadmap or deciding what is “done.”

## Current architecture

```text
Title.app
  -> outrage-host
  -> effective title profile
  -> host/runtime capability resolution
  -> verified runtime + isolated prefix/target storage
  -> graphics/performance/cache preparation
  -> direct target | title bootstrap | managed launcher
  -> real game process handoff
  -> native lifecycle + diagnostics
```

The Swift package contains:

- `OutRageKit` — reusable compatibility/runtime/orchestration logic.
- `outrage` — developer CLI for profiles, runtimes, packaging, smoke tests, planning, and launch validation.
- `outrage-host` — native macOS title-app host.

Runtime tooling lives under `Tools/runtime/`; CI is split between fast Swift/tool validation and expensive runtime/dependency artifact gates.

## Development baseline

Requires macOS 14+ and Swift 6 for development.

```bash
swift test
swift build -c release --product outrage --product outrage-host
swift run outrage doctor
swift run outrage validate Profiles/bootstrap.json
```

Building the compatibility runtime itself has additional build-machine dependencies. Those dependencies must **not** become end-user runtime dependencies; portability is enforced by the runtime artifact gates.

## Project rule

A subsystem is not considered complete just because its unit tests pass. `HANDOFF.md` distinguishes implementation from package-level proof and real-title acceptance. The exact release candidate must ultimately pass the documented fresh-machine scenario.
