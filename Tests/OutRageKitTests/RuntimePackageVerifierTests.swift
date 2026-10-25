import Foundation
import Testing
@testable import OutRageKit

@Test func runtimePackageVerifierChecksArchiveDescriptorAndExecutable() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let runtimeRoot = root.appendingPathComponent("runtime", isDirectory: true)
    let bin = runtimeRoot.appendingPathComponent("bin", isDirectory: true)
    let output = root.appendingPathComponent("output", isDirectory: true)
    try fm.createDirectory(at: bin, withIntermediateDirectories: true)

    let executable = bin.appendingPathComponent("runtime")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

    let descriptor = RuntimeDescriptor(
        id: "verified-runtime",
        executable: "bin/runtime",
        supportedCPUBackends: [.native],
        supportedGraphicsBackends: [.metal]
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(descriptor).write(to: runtimeRoot.appendingPathComponent("runtime.json"))

    let artifacts = try RuntimePackager.build(
        runtimeRoot: runtimeRoot,
        version: "1.0.0",
        outputDirectory: output,
        fileManager: fm
    )
    let verification = try RuntimePackageVerifier.verify(
        archiveURL: artifacts.archiveURL,
        manifestURL: artifacts.manifestURL,
        fileManager: fm
    )

    #expect(verification.runtimeIdentifier == "verified-runtime")
    #expect(verification.version == "1.0.0")
    #expect(verification.executable == "bin/runtime")
}
