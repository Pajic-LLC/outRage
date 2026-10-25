import Foundation
import Testing
@testable import OutRageKit

@Test func legacyProfileWithoutExecutableScopeDefaultsToTarget() throws {
    let json = """
    {
      "schemaVersion": 1,
      "id": "legacy",
      "displayName": "Legacy",
      "bundleIdentifier": "com.pajic.legacy",
      "executable": "game.exe",
      "runtime": "compatibility",
      "launcher": "managed",
      "cpu": "auto",
      "graphics": "auto",
      "arguments": [],
      "environment": {}
    }
    """
    let profile = try JSONDecoder().decode(RuntimeProfile.self, from: Data(json.utf8))
    #expect(profile.resolvedExecutableScope == .target)
}

@Test func launchSessionCanResolvePrefixScopedLauncher() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let paths = RuntimePaths(baseURL: root)
    try paths.ensureDirectories(fileManager: fm)
    try paths.ensureTargetDirectories(for: "prefix-launcher", fileManager: fm)

    let runtimeRoot = paths.runtimesURL.appendingPathComponent("test-runtime", isDirectory: true)
    let bin = runtimeRoot.appendingPathComponent("bin", isDirectory: true)
    try fm.createDirectory(at: bin, withIntermediateDirectories: true)
    let runtimeExecutable = bin.appendingPathComponent("runtime")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: runtimeExecutable)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runtimeExecutable.path)

    let descriptor = RuntimeDescriptor(
        id: "test-runtime",
        executable: "bin/runtime",
        supportedCPUBackends: [.native],
        supportedGraphicsBackends: [.metal]
    )
    try JSONEncoder().encode(descriptor).write(to: runtimeRoot.appendingPathComponent("runtime.json"))

    let launcher = paths.prefixURL(for: "prefix-launcher").appendingPathComponent("drive_c/Launcher/Launcher.exe")
    try fm.createDirectory(at: launcher.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("launcher".utf8).write(to: launcher)

    let profile = RuntimeProfile(
        id: "prefix-launcher",
        displayName: "Prefix Launcher",
        bundleIdentifier: "com.pajic.prefix-launcher",
        executable: "drive_c/Launcher/Launcher.exe",
        executableScope: .prefix,
        runtimeIdentifier: "test-runtime",
        cpu: .native,
        graphics: .metal
    )
    let host = HostCapabilities(
        architecture: "arm64",
        operatingSystemVersion: "test",
        hasMetal: true,
        hasRosetta: false
    )

    let session = try LaunchSessionBuilder.prepare(
        profile: profile,
        paths: paths,
        host: host,
        fileManager: fm
    )

    #expect(session.plan.executableURL == launcher)
    #expect(session.command.arguments.last == launcher.path)
}
