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
            managedLauncherDisplayName: "Rockstar Games Launcher",
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

    #expect(
        command.executableURL.resolvingSymlinksInPath() ==
        runtimeExecutable.resolvingSymlinksInPath()
    )
    #expect(command.arguments == [launcher.path, "--resume"])
    #expect(command.environment["OUTRAGE_APP_NAME"] == "Rockstar Games Launcher")
    let installerCommand = try ManagedLauncherBootstrap.makeInstallerCommand(
        profile: profile, installerURL: launcher, paths: paths, host: host, fileManager: fm
    )
    #expect(installerCommand.environment["OUTRAGE_APP_NAME"] == "Rockstar Games Launcher")
    #expect(command.environment["OUTRAGE_BUILD_CACHE_ROOT"] != nil)
    #expect(command.environment["OUTRAGE_SHADER_CACHE_PATH"] != nil)

    if let cacheRoot = command.environment["OUTRAGE_BUILD_CACHE_ROOT"] {
        #expect(fm.fileExists(atPath: cacheRoot))
    }
}

@Test func managedTitleBootstrapRunsFromTargetRootAndKeepsPerformanceCache() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let paths = RuntimePaths(baseURL: root)
    try paths.ensureDirectories(fileManager: fm)
    try paths.ensureTargetDirectories(for: "bootstrap-target", fileManager: fm)

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

    let targetRoot = paths.targetURL(for: "bootstrap-target")
    let target = targetRoot.appendingPathComponent("game.exe")
    let bootstrap = targetRoot.appendingPathComponent("PlayTarget.exe")
    try Data("target-build".utf8).write(to: target)
    try Data("bootstrap".utf8).write(to: bootstrap)

    let profile = RuntimeProfile(
        id: "bootstrap-target",
        displayName: "Bootstrap Target",
        bundleIdentifier: "com.pajic.bootstrap-target",
        executable: "game.exe",
        runtimeIdentifier: "runtime",
        cpu: .native,
        graphics: .metal,
        acquisition: AcquisitionDescriptor(
            kind: .managedLauncher,
            installerURL: URL(string: "https://example.com/installer.exe")!,
            managedLauncherExecutable: "drive_c/Launcher/Launcher.exe",
            managedLauncherDisplayName: "Rockstar Games Launcher",
            targetBootstrapExecutable: "PlayTarget.exe",
            targetBootstrapArguments: ["--story"]
        )
    )
    let host = HostCapabilities(
        architecture: "arm64",
        operatingSystemVersion: "test",
        hasMetal: true,
        hasRosetta: false
    )

    #expect(try ManagedLauncherBootstrap.targetBootstrapURL(profile: profile, paths: paths) == bootstrap)

    let command = try ManagedLauncherBootstrap.makeTargetBootstrapCommand(
        profile: profile,
        paths: paths,
        host: host,
        fileManager: fm
    )

    #expect(command.executableURL.resolvingSymlinksInPath() == runtimeExecutable.resolvingSymlinksInPath())
    #expect(command.arguments == [bootstrap.path, "--story"])
    #expect(command.environment["OUTRAGE_APP_NAME"] == "Bootstrap Target")
    #expect(command.workingDirectoryURL == targetRoot)
    #expect(command.environment["OUTRAGE_BUILD_CACHE_ROOT"] != nil)
    #expect(command.environment["OUTRAGE_SHADER_CACHE_PATH"] != nil)
}

@Test func managedTitleBootstrapRejectsTargetPathTraversal() {
    let profile = RuntimeProfile(
        id: "bad-bootstrap",
        displayName: "Bad Bootstrap",
        bundleIdentifier: "com.pajic.bad-bootstrap",
        executable: "game.exe",
        acquisition: AcquisitionDescriptor(
            kind: .managedLauncher,
            installerURL: URL(string: "https://example.com/installer.exe")!,
            targetBootstrapExecutable: "../outside.exe"
        )
    )

    #expect(throws: AcquisitionError.invalidTargetBootstrapExecutable("../outside.exe")) {
        try profile.validate()
    }
}
