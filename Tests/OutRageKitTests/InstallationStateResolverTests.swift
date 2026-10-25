import Foundation
import Testing
@testable import OutRageKit

@Test func installationStateProgressesFromRuntimeToLauncherToReady() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let paths = RuntimePaths(baseURL: root)
    let profile = RuntimeProfile(
        id: "state-target",
        displayName: "State Target",
        bundleIdentifier: "com.pajic.state-target",
        executable: "game.exe",
        runtimeIdentifier: "state-runtime",
        cpu: .native,
        graphics: .metal,
        acquisition: AcquisitionDescriptor(
            kind: .managedLauncher,
            installerURL: URL(string: "https://example.com/installer.exe")!,
            managedLauncherExecutable: "drive_c/Launcher/Launcher.exe"
        )
    )

    #expect(try InstallationStateResolver.resolve(
        profile: profile,
        paths: paths,
        fileManager: fm
    ) == .runtimeRequired)

    let runtimeRoot = paths.runtimesURL.appendingPathComponent("state-runtime", isDirectory: true)
    let bin = runtimeRoot.appendingPathComponent("bin", isDirectory: true)
    try fm.createDirectory(at: bin, withIntermediateDirectories: true)
    let runtimeExecutable = bin.appendingPathComponent("runtime")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: runtimeExecutable)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runtimeExecutable.path)
    try JSONEncoder().encode(RuntimeDescriptor(
        id: "state-runtime",
        executable: "bin/runtime",
        supportedCPUBackends: [.native],
        supportedGraphicsBackends: [.metal]
    )).write(to: runtimeRoot.appendingPathComponent("runtime.json"))

    #expect(try InstallationStateResolver.resolve(
        profile: profile,
        paths: paths,
        fileManager: fm
    ) == .managedLauncherInstallerRequired)

    let launcher = paths.prefixURL(for: profile.id).appendingPathComponent("drive_c/Launcher/Launcher.exe")
    try fm.createDirectory(at: launcher.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("launcher".utf8).write(to: launcher)

    #expect(try InstallationStateResolver.resolve(
        profile: profile,
        paths: paths,
        fileManager: fm
    ) == .managedLauncherReady(launcher))

    try fm.createDirectory(at: paths.targetURL(for: profile.id), withIntermediateDirectories: true)
    try Data("game".utf8).write(to: paths.executableURL(for: profile))

    #expect(try InstallationStateResolver.resolve(
        profile: profile,
        paths: paths,
        fileManager: fm
    ) == .ready)
}
