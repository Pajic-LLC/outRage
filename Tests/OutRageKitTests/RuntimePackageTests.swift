import Foundation
import Testing
@testable import OutRageKit

@Test func fileDigestMatchesKnownSHA256() throws {
    let fm = FileManager.default
    let url = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? fm.removeItem(at: url) }

    try Data("abc".utf8).write(to: url)
    let digest = try FileDigest.sha256(of: url)

    #expect(digest == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
}

@Test func runtimeInstallerExtractsVerifiedPackage() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let payload = root.appendingPathComponent("payload", isDirectory: true)
    let bin = payload.appendingPathComponent("bin", isDirectory: true)
    try fm.createDirectory(at: bin, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let descriptor = RuntimeDescriptor(
        id: "package-test",
        executable: "bin/runtime",
        supportedCPUBackends: [.native],
        supportedGraphicsBackends: [.metal]
    )
    try JSONEncoder().encode(descriptor).write(to: payload.appendingPathComponent("runtime.json"))

    let executable = bin.appendingPathComponent("runtime")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

    let archive = root.appendingPathComponent("runtime.zip")
    let ditto = Process()
    ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    ditto.arguments = ["-c", "-k", "--keepParent", payload.path, archive.path]
    try ditto.run()
    ditto.waitUntilExit()
    #expect(ditto.terminationStatus == 0)

    let manifest = RuntimePackageManifest(
        runtimeIdentifier: "package-test",
        version: "0.1.0",
        archiveSHA256: try FileDigest.sha256(of: archive),
        rootSubdirectory: "payload"
    )
    let paths = RuntimePaths(baseURL: root.appendingPathComponent("installed", isDirectory: true))

    let installed = try RuntimeInstaller.install(
        archiveURL: archive,
        manifest: manifest,
        paths: paths,
        fileManager: fm
    )

    #expect(installed.descriptor.id == "package-test")
    #expect(fm.isExecutableFile(atPath: installed.rootURL.appendingPathComponent("bin/runtime").path))
}
