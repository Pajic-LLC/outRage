import Foundation
import Testing
@testable import OutRageKit

@Test func dxmtSmokeVerifierAcceptsBuiltinModuleLoads() throws {
    let log = """
    00d4:trace:loaddll:build_module Loaded L\"C:\\windows\\system32\\winemetal.dll\" at 0001: builtin
    00d4:trace:loaddll:build_module Loaded L\"C:\\windows\\system32\\DXGI.DLL\" at 0002: builtin
    00d4:trace:loaddll:build_module Loaded L\"C:\\windows\\system32\\d3d11.dll\" at 0003: builtin
    info: Metal Shading Language 3.1
    """

    let result = try DXMTRuntimeSmokeVerifier.evaluate(
        log: log,
        runtimeIdentifier: "runtime"
    )

    #expect(result.runtimeIdentifier == "runtime")
    #expect(result.loadedModules == ["d3d11.dll", "dxgi.dll", "winemetal.dll"])
}

@Test func dxmtSmokeVerifierRejectsNativeOrMissingModuleLoads() {
    let log = """
    trace: Loaded L\"C:\\windows\\system32\\winemetal.dll\" at 0001: builtin
    trace: Loaded L\"C:\\windows\\system32\\DXGI.DLL\" at 0002: native
    trace: Loaded L\"C:\\windows\\system32\\d3d11.dll\" at 0003: builtin
    """

    #expect(throws: DXMTRuntimeSmokeError.modulesNotLoaded(["dxgi.dll"])) {
        try DXMTRuntimeSmokeVerifier.evaluate(log: log, runtimeIdentifier: "runtime")
    }
}

@Test func dxmtSmokeProbeUsesRosettaRuntimeAndDebugTracing() throws {
    let root = URL(fileURLWithPath: "/tmp/runtime")
    let context = RuntimeLaunchContext(
        runtimeRoot: root,
        targetRoot: URL(fileURLWithPath: "/tmp/target"),
        prefixRoot: URL(fileURLWithPath: "/tmp/prefix"),
        cacheRoot: URL(fileURLWithPath: "/tmp/cache")
    )
    let runtime = RuntimeDescriptor(
        id: "runtime",
        executable: "bin/wine64",
        environment: ["WINEPREFIX": "${PREFIX_ROOT}"],
        supportedCPUBackends: [.rosetta],
        supportedGraphicsBackends: [.dxmt]
    )

    let command = try DXMTRuntimeSmokeVerifier.probeCommand(
        runtime: runtime,
        runtimeRoot: root,
        cpu: .rosetta,
        context: context
    )

    #expect(command.executableURL.path == "/usr/bin/arch")
    #expect(command.arguments == [
        "-x86_64",
        "/tmp/runtime/bin/wine64",
        "rundll32",
        "d3d11.dll,NoSuchEntry"
    ])
    #expect(command.environment["WINEPREFIX"] == "/tmp/prefix")
    #expect(command.environment["WINEDEBUG"] == "+loaddll,+dxmt")
    #expect(command.environment["DXMT_LOG_LEVEL"] == "info")
}
