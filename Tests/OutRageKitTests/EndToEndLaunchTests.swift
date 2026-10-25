import Foundation
import Testing
@testable import OutRageKit

@Test func compatibilityRuntimeLaunchesTargetEndToEnd() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let paths = RuntimePaths(baseURL: root)
    try paths.ensureDirectories(fileManager: fm)

    let runtimeRoot = paths.runtimesURL.appendingPathComponent("test-runtime", isDirectory: true)
    let runtimeBin = runtimeRoot.appendingPathComponent("bin", isDirectory: true)
    try fm.createDirectory(at: runtimeBin, withIntermediateDirectories: true)

    let runtimeExecutable = runtimeBin.appendingPathComponent("runtime")
    try Data("#!/bin/sh\nexec \"$@\"\n".utf8).write(to: runtimeExecutable)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runtimeExecutable.path)

    let descriptor = RuntimeDescriptor(
        id: "test-runtime",
        executable: "bin/runtime",
        supportedCPUBackends: [.native],
        supportedGraphicsBackends: [.metal]
    )
    try JSONEncoder().encode(descriptor).write(to: runtimeRoot.appendingPathComponent("runtime.json"))

    let targetRoot = paths.targetURL(for: "e2e")
    try fm.createDirectory(at: targetRoot, withIntermediateDirectories: true)
    let marker = root.appendingPathComponent("launched.txt")
    let target = targetRoot.appendingPathComponent("target.exe")
    let script = "#!/bin/sh\nprintf launched > \"\(marker.path)\"\n"
    try Data(script.utf8).write(to: target)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path)

    let profile = RuntimeProfile(
        id: "e2e",
        displayName: "E2E",
        bundleIdentifier: "com.pajic.e2e",
        executable: "target.exe",
        runtimeIdentifier: "test-runtime",
        cpu: .native,
        graphics: .metal
    )
    let host = HostCapabilities(
        architecture: "arm64",
        operatingSystemVersion: "test",
        hasMetal: true,
        hasRosetta: true
    )

    let session = try LaunchSessionBuilder.prepare(
        profile: profile,
        paths: paths,
        host: host,
        fileManager: fm
    )
    let process = try ProcessRunner.start(session.command, fileManager: fm)
    process.waitUntilExit()

    #expect(process.terminationStatus == 0)
    #expect(fm.fileExists(atPath: marker.path))
    #expect(try String(contentsOf: marker, encoding: .utf8) == "launched")
}
