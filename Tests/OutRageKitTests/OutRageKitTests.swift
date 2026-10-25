import Foundation
import Testing
@testable import OutRageKit

@Test func profileValidationAndPlanning() throws {
    let profile = RuntimeProfile(
        id: "alpha.target",
        displayName: "Alpha Target",
        bundleIdentifier: "com.pajic.alpha-target",
        executable: "bin/target.exe",
        cpu: .auto,
        graphics: .dxmt,
        arguments: ["--safe"]
    )

    try profile.validate()

    let host = HostCapabilities(
        architecture: "arm64",
        operatingSystemVersion: "test",
        hasMetal: true,
        hasRosetta: true
    )
    let root = URL(fileURLWithPath: "/tmp/alpha")
    let plan = try LaunchPlanner.makePlan(profile: profile, targetRoot: root, host: host)

    #expect(plan.cpu == .rosetta)
    #expect(plan.graphics == .dxmt)
    #expect(plan.executableURL.path == "/tmp/alpha/bin/target.exe")
    #expect(plan.arguments == ["--safe"])
}

@Test func profileRoundTrip() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let url = root.appendingPathComponent("profile.json")
    let profile = RuntimeProfile(
        id: "roundtrip",
        displayName: "Round Trip",
        bundleIdentifier: "com.pajic.roundtrip",
        executable: "target.exe",
        performance: PerformancePolicy(
            preferredMaxFrameRate: 60,
            metalFXSpatialUpscaling: true,
            metalFXSpatialUpscaleFactor: 1.5
        )
    )

    try ProfileLoader.save(profile, to: url)
    #expect(try ProfileLoader.load(from: url) == profile)
}

@Test func appBundleBuilderProducesBundleLayout() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let host = root.appendingPathComponent("host")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: host)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: host.path)

    let profile = RuntimeProfile(
        id: "bundle-test",
        displayName: "Bundle Test",
        bundleIdentifier: "com.pajic.bundle-test",
        executable: "target.exe"
    )

    let app = try AppBundleBuilder().build(profile: profile, hostExecutable: host, outputDirectory: root)
    #expect(fm.fileExists(atPath: app.appendingPathComponent("Contents/Info.plist").path))
    #expect(fm.fileExists(atPath: app.appendingPathComponent("Contents/MacOS/outRageHost").path))
    #expect(fm.fileExists(atPath: app.appendingPathComponent("Contents/Resources/profile.json").path))
}

@Test func launchCommandUsesRosettaAndRuntimePreferences() throws {
    let profile = RuntimeProfile(
        id: "command-test",
        displayName: "Command Test",
        bundleIdentifier: "com.pajic.command-test",
        executable: "game/target.exe",
        cpu: .auto,
        graphics: .auto,
        arguments: ["--launch"]
    )
    let host = HostCapabilities(
        architecture: "arm64",
        operatingSystemVersion: "test",
        hasMetal: true,
        hasRosetta: true
    )
    let plan = try LaunchPlanner.makePlan(
        profile: profile,
        targetRoot: URL(fileURLWithPath: "/tmp/target"),
        host: host
    )
    let runtime = RuntimeDescriptor(
        id: "runtime-a",
        executable: "bin/runtime",
        argumentPrefix: ["--managed"],
        supportedCPUBackends: [.rosetta],
        supportedGraphicsBackends: [.dxmt, .d3dMetal]
    )

    let command = try LaunchCommandBuilder.make(
        plan: plan,
        runtime: runtime,
        runtimeRoot: URL(fileURLWithPath: "/tmp/runtime")
    )

    #expect(command.executableURL.path == "/usr/bin/arch")
    #expect(command.arguments == [
        "-x86_64",
        "/tmp/runtime/bin/runtime",
        "--managed",
        "/tmp/target/game/target.exe",
        "--launch"
    ])
    #expect(command.graphics == .dxmt)
    #expect(command.environment["OUTRAGE_CPU_BACKEND"] == "rosetta")
    #expect(command.environment["OUTRAGE_GRAPHICS_BACKEND"] == "dxmt")
}
