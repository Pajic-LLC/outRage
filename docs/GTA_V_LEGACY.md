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

## Required runtime and proof

Install the exact `26.3.0+v0.80-launcher.1` package that passes the dependency-integrated build, portability audit, DXMT module-load, D3D11 device-creation, and Windows-execution gates. The reference profile currently selects by runtime ID; it does not enforce package-version ranges. Do not use a previously installed stripped foundation runtime for this test. No release runtime download is configured in this developer profile.

Developer checks:

```sh
swift run outrage validate Profiles/gta-v-legacy-rockstar.json
swift run outrage acquisition-plan Profiles/gta-v-legacy-rockstar.json
swift run outrage bundle Profiles/gta-v-legacy-rockstar.json
```

The generated `Grand Theft Auto V.app` contains the native host and profile. Development ad-hoc signing verifies bundle structure; it is not Developer ID signing or notarization. Title artwork and release packaging remain unfinished.

Before claiming gameplay, record the exact package checksum/version, game build, host macOS/chip, launcher version, successful login/install/update behavior, first gameplay frame, input/audio/saves, handoff to `GTA5.exe`, clean quit, and repeat launch. Until those are exercised, this profile is a test input rather than a compatibility claim.
