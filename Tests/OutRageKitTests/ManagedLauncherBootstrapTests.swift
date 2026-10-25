import Foundation
import Testing
@testable import OutRageKit

@Test func managedLauncherCommandUsesInstalledPrefixExecutable() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let paths = RuntimePaths(baseURL: root)
    try paths.ensureDirectories(fileManager: fm)
    try paths.ensureTargetDirectories(for: "managed", fileManager: fm)

    let runtimeRoot = paths.runtimesURL.appendingPathComponent("runtime", isDirectory: true)
    let bin = runtimeRoot.appendingPathComponent("bin", isDirectory: true)
    try fm.createDirectory(at: bin, withIntermediateDirectories: true)
    let runtimeExecutable = bin.appendingPathComponent("runtime")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: runtimeExecutable)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runtimeExecutable.path)

    let descriptor = RuntimeDescriptor(
        id: "runtime",
        executable: "bin/runtime",
        supportedCPUBackends: [.native],
        supportedGraphicsBackends: [.metal]
    )
    try JSONEncoder().encode(descriptor).write(to: runtimeRoot.appendingPathComponent("runtime.json"))

    let launcher = paths.prefixURL(for: "managed").appendingPathComponent("drive_c/Launcher/Launcher.exe")
    try fm.createDirectory(at: launcher.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("launcher".utf8).write(to: launcher)

    let target = paths.targetURL(for: "managed").appendingPathComponent("game.exe")
    try Data("target-build".utf8).write(to: target)

    let profile = RuntimeProfile(
        id: "managed",
        displayName: "Managed",
        bundleIdentifier: "com.pajic.managed",
        executable: "game.exe",
        runtimeIdentifier: "runtime",
        cpu: .native,
        graphics: .metal,
        acquisition: AcquisitionDescriptor(
            kind: .managedLauncher,
            installerURL: URL(string: "https://example.com/installer.exe")!,
            managedLauncherExecutable: "drive_c/Launcher/Launcher.exe",
            managedLauncherArguments: ["--resume"]
        )
    )
    let host = HostCapabilities(
        architecture: "arm64",
        operatingSystemVersion: "test",
        hasMetal: true,
        hasRosetta: false
    )

    let command = try ManagedLauncherBootstrap.makeInstalledLauncherCommand(
        profile: profile,
        paths: paths,
        host: host,
        fileManager: fm
    )

    #expect(command.executableURL == runtimeExecutable)
    #expect(command.arguments == [launcher.path, "--resume"])
    #expect(command.environment["OUTRAGE_BUILD_CACHE_ROOT"] != nil)
    #expect(command.environment["OUTRAGE_SHADER_CACHE_PATH"] != nil)

    if let cacheRoot = command.environment["OUTRAGE_BUILD_CACHE_ROOT"] {
        #expect(fm.fileExists(atPath: cacheRoot))
    }
}
