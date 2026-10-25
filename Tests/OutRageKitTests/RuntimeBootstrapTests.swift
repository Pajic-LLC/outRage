import Foundation
import Testing
@testable import OutRageKit

@Test func runtimeBootstrapInstallsPinnedPackageFromLocalSource() async throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let sourceRuntime = root.appendingPathComponent("bootstrap-runtime", isDirectory: true)
    let bin = sourceRuntime.appendingPathComponent("bin", isDirectory: true)
    try fm.createDirectory(at: bin, withIntermediateDirectories: true)

    let descriptor = RuntimeDescriptor(
        id: "bootstrap-runtime",
        executable: "bin/runtime",
        supportedCPUBackends: [.native],
        supportedGraphicsBackends: [.metal]
    )
    try JSONEncoder().encode(descriptor).write(to: sourceRuntime.appendingPathComponent("runtime.json"))

    let executable = bin.appendingPathComponent("runtime")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

    let packages = root.appendingPathComponent("packages", isDirectory: true)
    let artifacts = try RuntimePackager.build(
        runtimeRoot: sourceRuntime,
        version: "1.0.0",
        outputDirectory: packages,
        fileManager: fm
    )

    let profile = RuntimeProfile(
        id: "bootstrap-target",
        displayName: "Bootstrap Target",
        bundleIdentifier: "com.pajic.bootstrap-target",
        executable: "target.exe",
        runtimeIdentifier: "bootstrap-runtime",
        runtimePackageSource: RuntimePackageSource(
            archiveURL: artifacts.archiveURL,
            manifest: artifacts.manifest
        )
    )
    let paths = RuntimePaths(baseURL: root.appendingPathComponent("data", isDirectory: true))

    let installed = try await RuntimeBootstrap.ensureInstalled(
        for: profile,
        paths: paths,
        fileManager: fm
    )

    #expect(installed?.descriptor.id == "bootstrap-runtime")
    #expect(fm.isExecutableFile(atPath: paths.runtimesURL.appendingPathComponent("bootstrap-runtime/bin/runtime").path))
    #expect(fm.fileExists(atPath: paths.runtimePackageArchiveURL(identifier: "bootstrap-runtime", version: "1.0.0").path))
}
