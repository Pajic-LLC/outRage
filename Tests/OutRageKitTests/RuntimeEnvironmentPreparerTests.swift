import Foundation
import Testing
@testable import OutRageKit

@Test func runtimeEnvironmentPreparationAppliesProfileInstallRedirects() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let paths = RuntimePaths(baseURL: root)
    try paths.ensureDirectories(fileManager: fm)
    try paths.ensureTargetDirectories(for: "prepared", fileManager: fm)

    let runtimeRoot = paths.runtimesURL.appendingPathComponent("prepared-runtime", isDirectory: true)
    let bin = runtimeRoot.appendingPathComponent("bin", isDirectory: true)
    try fm.createDirectory(at: bin, withIntermediateDirectories: true)
    let runtimeExecutable = bin.appendingPathComponent("runtime")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: runtimeExecutable)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runtimeExecutable.path)

    let descriptor = RuntimeDescriptor(
        id: "prepared-runtime",
        executable: "bin/runtime",
        supportedCPUBackends: [.native],
        supportedGraphicsBackends: [.metal]
    )
    try JSONEncoder().encode(descriptor).write(to: runtimeRoot.appendingPathComponent("runtime.json"))

    let targetRoot = paths.targetURL(for: "prepared")
    try Data("game-data".utf8).write(to: targetRoot.appendingPathComponent("asset.bin"))

    let profile = RuntimeProfile(
        id: "prepared",
        displayName: "Prepared",
        bundleIdentifier: "com.pajic.prepared",
        executable: "game.exe",
        runtimeIdentifier: "prepared-runtime",
        cpu: .native,
        graphics: .metal,
        pathMappings: [
            RuntimePathMapping(
                sourceScope: .target,
                source: ".",
                destinationScope: .prefix,
                destination: "drive_c/Program Files/Example/Game"
            )
        ]
    )
    let host = HostCapabilities(
        architecture: "arm64",
        operatingSystemVersion: "test",
        hasMetal: true,
        hasRosetta: false
    )

    let prepared = try RuntimeEnvironmentPreparer.prepare(
        profile: profile,
        paths: paths,
        host: host,
        fileManager: fm
    )

    #expect(prepared.cpu == .native)
    #expect(prepared.graphics == .metal)
    let redirected = paths.prefixURL(for: profile.id)
        .appendingPathComponent("drive_c/Program Files/Example/Game")
    #expect(try redirected.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true)
    #expect(try Data(contentsOf: redirected.appendingPathComponent("asset.bin")) == Data("game-data".utf8))
}
