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
}
