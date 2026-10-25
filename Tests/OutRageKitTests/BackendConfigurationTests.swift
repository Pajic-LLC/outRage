import Foundation
import Testing
@testable import OutRageKit

@Test func backendConfigurationsComposeIntoLaunchCommand() throws {
    let profile = RuntimeProfile(
        id: "backend-test",
        displayName: "Backend Test",
        bundleIdentifier: "com.pajic.backend-test",
        executable: "target.exe",
        cpu: .rosetta,
        graphics: .dxmt
    )
    let host = HostCapabilities(
        architecture: "arm64",
        operatingSystemVersion: "test",
        hasMetal: true,
        hasRosetta: true
    )
    let targetRoot = URL(fileURLWithPath: "/tmp/backend-target")
    let plan = try LaunchPlanner.makePlan(profile: profile, targetRoot: targetRoot, host: host)
    let runtime = RuntimeDescriptor(
        id: "backend-runtime",
        executable: "bin/runtime",
        argumentPrefix: ["--base"],
        environment: ["BASE": "1"],
        supportedCPUBackends: [.rosetta],
        supportedGraphicsBackends: [.dxmt],
        cpuConfigurations: [
            "rosetta": RuntimeBackendConfiguration(
                arguments: ["--cpu", "translated"],
                environment: ["CPU_MODE": "translated"]
            )
        ],
        graphicsConfigurations: [
            "dxmt": RuntimeBackendConfiguration(
                arguments: ["--renderer", "metal"],
                environment: ["RENDER_CACHE": "${CACHE_ROOT}"]
            )
        ]
    )
    let context = RuntimeLaunchContext(
        runtimeRoot: URL(fileURLWithPath: "/tmp/runtime"),
        targetRoot: targetRoot,
        prefixRoot: URL(fileURLWithPath: "/tmp/prefix"),
        cacheRoot: URL(fileURLWithPath: "/tmp/cache")
    )

    let command = try LaunchCommandBuilder.make(
        plan: plan,
        runtime: runtime,
        runtimeRoot: context.runtimeRoot,
        context: context
    )

    #expect(command.arguments == [
        "-x86_64",
        "/tmp/runtime/bin/runtime",
        "--base",
        "--cpu", "translated",
        "--renderer", "metal",
        "/tmp/backend-target/target.exe"
    ])
    #expect(command.environment["BASE"] == "1")
    #expect(command.environment["CPU_MODE"] == "translated")
    #expect(command.environment["RENDER_CACHE"] == "/tmp/cache")
    #expect(command.environment["OUTRAGE_APP_NAME"] == "Backend Test")
}

@Test func profileEnvironmentOverridesRuntimeAndCPUBackendDefaults() throws {
    let profile = RuntimeProfile(
        id: "override-test",
        displayName: "Override Test",
        bundleIdentifier: "com.pajic.override-test",
        executable: "target.exe",
        cpu: .rosetta,
        graphics: .dxmt,
        environment: [
            "ROSETTA_ADVERTISE_AVX": "0",
            "OUTRAGE_APP_NAME": "Custom Native Name",
            "SHARED": "profile"
        ]
    )
    let host = HostCapabilities(
        architecture: "arm64",
        operatingSystemVersion: "test",
        hasMetal: true,
        hasRosetta: true
    )
    let targetRoot = URL(fileURLWithPath: "/tmp/override-target")
    let plan = try LaunchPlanner.makePlan(profile: profile, targetRoot: targetRoot, host: host)
    let runtime = RuntimeDescriptor(
        id: "override-runtime",
        executable: "bin/runtime",
        environment: [
            "ROSETTA_ADVERTISE_AVX": "runtime",
            "SHARED": "runtime"
        ],
        supportedCPUBackends: [.rosetta],
        supportedGraphicsBackends: [.dxmt],
        cpuConfigurations: [
            "rosetta": RuntimeBackendConfiguration(
                environment: [
                    "ROSETTA_ADVERTISE_AVX": "1",
                    "SHARED": "cpu"
                ]
            )
        ]
    )
    let context = RuntimeLaunchContext(
        runtimeRoot: URL(fileURLWithPath: "/tmp/runtime"),
        targetRoot: targetRoot,
        prefixRoot: URL(fileURLWithPath: "/tmp/prefix"),
        cacheRoot: URL(fileURLWithPath: "/tmp/cache")
    )

    let command = try LaunchCommandBuilder.make(
        plan: plan,
        runtime: runtime,
        runtimeRoot: context.runtimeRoot,
        context: context
    )

    #expect(command.environment["ROSETTA_ADVERTISE_AVX"] == "0")
    #expect(command.environment["OUTRAGE_APP_NAME"] == "Custom Native Name")
    #expect(command.environment["SHARED"] == "profile")
}

@Test func automaticCPUResolutionPrefersRosettaOnAppleSiliconToday() throws {
    let runtime = RuntimeDescriptor(
        id: "multi-cpu",
        executable: "runtime",
        supportedCPUBackends: [.fex, .rosetta, .native],
        supportedGraphicsBackends: [.dxmt]
    )
    let host = HostCapabilities(
        architecture: "arm64",
        operatingSystemVersion: "test",
        hasMetal: true,
        hasRosetta: true
    )

    #expect(try BackendResolver.resolveCPU(requested: .auto, runtime: runtime, host: host) == .rosetta)
}

@Test func automaticCPUResolutionFallsBackToFEXWithoutRosetta() throws {
    let runtime = RuntimeDescriptor(
        id: "arm-runtime",
        executable: "runtime",
        supportedCPUBackends: [.fex, .native],
        supportedGraphicsBackends: [.dxmt]
    )
    let host = HostCapabilities(
        architecture: "arm64",
        operatingSystemVersion: "test",
        hasMetal: true,
        hasRosetta: false
    )

    #expect(try BackendResolver.resolveCPU(requested: .auto, runtime: runtime, host: host) == .fex)
}

@Test func automaticGraphicsResolutionUsesD3DMetalForD3D12Hints() throws {
    let runtime = RuntimeDescriptor(
        id: "graphics-runtime",
        executable: "runtime",
        supportedCPUBackends: [.native],
        supportedGraphicsBackends: [.dxmt, .d3dMetal]
    )

    #expect(try BackendResolver.resolveGraphics(
        requested: .auto,
        runtime: runtime,
        hints: [.d3d12, .dxgi]
    ) == .d3dMetal)
}
