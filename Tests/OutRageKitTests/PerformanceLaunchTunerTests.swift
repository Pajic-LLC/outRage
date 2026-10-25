import Foundation
import Testing
@testable import OutRageKit

private func testCommand(
    graphics: GraphicsBackend = .dxmt,
    environment: [String: String] = [:]
) -> LaunchCommand {
    LaunchCommand(
        executableURL: URL(fileURLWithPath: "/tmp/runtime"),
        arguments: ["target.exe"],
        workingDirectoryURL: URL(fileURLWithPath: "/tmp"),
        environment: environment,
        graphics: graphics
    )
}

private func testCache() -> RuntimeCacheLocation {
    RuntimeCacheLocation(
        rootURL: URL(fileURLWithPath: "/tmp/cache/build"),
        shaderURL: URL(fileURLWithPath: "/tmp/cache/build/Shaders"),
        fingerprintURL: URL(fileURLWithPath: "/tmp/cache/build/fingerprint.json")
    )
}

@Test func performanceLaunchTunerRoutesDXMTCacheToBuildSpecificDirectory() {
    let tuned = PerformanceLaunchTuner.tune(
        testCommand(environment: ["EXISTING": "1"]),
        cache: testCache()
    )

    #expect(tuned.environment["EXISTING"] == "1")
    #expect(tuned.environment["OUTRAGE_BUILD_CACHE_ROOT"] == "/tmp/cache/build")
    #expect(tuned.environment["DXMT_SHADER_CACHE_PATH"] == "/tmp/cache/build/Shaders")
}

@Test func dxmtPerformancePolicyBuildsFramePacingAndMetalFXConfiguration() {
    let tuned = PerformanceLaunchTuner.tune(
        testCommand(environment: ["DXMT_CONFIG": "existing.option=1;"]),
        cache: testCache(),
        policy: PerformancePolicy(
            preferredMaxFrameRate: 60,
            metalFXSpatialUpscaling: true,
            metalFXSpatialUpscaleFactor: 1.5
        )
    )

    #expect(tuned.environment["DXMT_METALFX_SPATIAL_SWAPCHAIN"] == "1")
    #expect(tuned.environment["DXMT_CONFIG"] == "existing.option=1;d3d11.preferredMaxFrameRate=60;d3d11.metalSpatialUpscaleFactor=1.5;")
}

@Test func explicitDXMTEnvironmentAlwaysWinsOverTypedPolicy() {
    let explicit = [
        "DXMT_CONFIG": "title.custom=1;",
        "DXMT_METALFX_SPATIAL_SWAPCHAIN": "0"
    ]
    let tuned = PerformanceLaunchTuner.tune(
        testCommand(environment: explicit),
        cache: testCache(),
        policy: PerformancePolicy(
            preferredMaxFrameRate: 120,
            metalFXSpatialUpscaling: true,
            metalFXSpatialUpscaleFactor: 1.75
        ),
        explicitEnvironment: explicit
    )

    #expect(tuned.environment["DXMT_CONFIG"] == "title.custom=1;")
    #expect(tuned.environment["DXMT_METALFX_SPATIAL_SWAPCHAIN"] == "0")
}

@Test func performancePolicyDoesNotEmitDXMTKnobsForOtherBackends() {
    let tuned = PerformanceLaunchTuner.tune(
        testCommand(graphics: .d3dMetal),
        cache: testCache(),
        policy: PerformancePolicy(
            preferredMaxFrameRate: 60,
            metalFXSpatialUpscaling: true,
            metalFXSpatialUpscaleFactor: 1.5
        )
    )

    #expect(tuned.environment["DXMT_CONFIG"] == nil)
    #expect(tuned.environment["DXMT_METALFX_SPATIAL_SWAPCHAIN"] == nil)
    #expect(tuned.environment["DXMT_SHADER_CACHE_PATH"] == nil)
    #expect(tuned.environment["OUTRAGE_BUILD_CACHE_ROOT"] == "/tmp/cache/build")
}

@Test func performancePolicyValidationRejectsUnsafeValues() {
    #expect(throws: PerformancePolicyError.invalidPreferredMaxFrameRate(1001)) {
        try PerformancePolicy(preferredMaxFrameRate: 1001).validate()
    }

    #expect(throws: PerformancePolicyError.invalidMetalFXSpatialUpscaleFactor(2.1)) {
        try PerformancePolicy(metalFXSpatialUpscaleFactor: 2.1).validate()
    }
}

@Test func mullionUsesBuildCacheWithoutD3D11PerformanceDirectives() {
    let tuned = PerformanceLaunchTuner.tune(testCommand(graphics: .mullion), cache: testCache(),
        policy: PerformancePolicy(preferredMaxFrameRate: 60, metalFXSpatialUpscaling: true))
    #expect(tuned.environment["DXMT_SHADER_CACHE_PATH"] == "/tmp/cache/build/Shaders")
    #expect(tuned.environment["DXMT_CONFIG"] == nil)
    #expect(tuned.environment["DXMT_METALFX_SPATIAL_SWAPCHAIN"] == nil)
}
