import Foundation
import Testing
@testable import OutRageKit

@Test func performanceLaunchTunerRoutesDXMTCacheToBuildSpecificDirectory() {
    let command = LaunchCommand(
        executableURL: URL(fileURLWithPath: "/runtime/wine"),
        arguments: ["target.exe"],
        workingDirectoryURL: URL(fileURLWithPath: "/target"),
        environment: ["EXISTING": "1"],
        graphics: .dxmt
    )
    let cache = RuntimeCacheLocation(
        rootURL: URL(fileURLWithPath: "/cache/build"),
        shaderURL: URL(fileURLWithPath: "/cache/build/Shaders"),
        fingerprintURL: URL(fileURLWithPath: "/cache/build/fingerprint.json")
    )

    let tuned = PerformanceLaunchTuner.tune(command, cache: cache)

    #expect(tuned.environment["EXISTING"] == "1")
    #expect(tuned.environment["OUTRAGE_BUILD_CACHE_ROOT"] == "/cache/build")
    #expect(tuned.environment["DXMT_SHADER_CACHE_PATH"] == "/cache/build/Shaders")
}
