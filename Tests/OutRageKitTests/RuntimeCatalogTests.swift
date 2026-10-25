import Foundation
import Testing
@testable import OutRageKit

@Test func runtimeCatalogSkipsBrokenEntriesAndResolvesValidRuntime() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }
    try fm.createDirectory(at: root, withIntermediateDirectories: true)

    let broken = root.appendingPathComponent("broken", isDirectory: true)
    try fm.createDirectory(at: broken, withIntermediateDirectories: true)
    try Data("not-json".utf8).write(to: broken.appendingPathComponent("runtime.json"))

    let missingExecutable = root.appendingPathComponent("missing-executable", isDirectory: true)
    try fm.createDirectory(at: missingExecutable, withIntermediateDirectories: true)
    let missingDescriptor = RuntimeDescriptor(
        id: "missing-executable",
        executable: "bin/runtime",
        supportedCPUBackends: [.native],
        supportedGraphicsBackends: [.metal]
    )
    try JSONEncoder().encode(missingDescriptor).write(
        to: missingExecutable.appendingPathComponent("runtime.json")
    )

    let valid = root.appendingPathComponent("valid-runtime", isDirectory: true)
    let bin = valid.appendingPathComponent("bin", isDirectory: true)
    try fm.createDirectory(at: bin, withIntermediateDirectories: true)
    let executable = bin.appendingPathComponent("runtime")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    let validDescriptor = RuntimeDescriptor(
        id: "valid-runtime",
        executable: "bin/runtime",
        supportedCPUBackends: [.native],
        supportedGraphicsBackends: [.metal]
    )
    try JSONEncoder().encode(validDescriptor).write(
        to: valid.appendingPathComponent("runtime.json")
    )

    let catalog = RuntimeCatalog(runtimesURL: root)
    let installed = try catalog.installed(fileManager: fm)
    #expect(installed.map(\.descriptor.id) == ["valid-runtime"])

    let resolved = try catalog.resolve(
        identifier: "valid-runtime",
        fileManager: fm
    )
    #expect(resolved.descriptor.id == "valid-runtime")
}
