import Foundation
import Testing
@testable import OutRageKit

@Test func runtimeCatalogResolvesNamedRuntime() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let runtimes = root.appendingPathComponent("Runtimes", isDirectory: true)
    let runtimeRoot = runtimes.appendingPathComponent("alpha", isDirectory: true)
    let bin = runtimeRoot.appendingPathComponent("bin", isDirectory: true)
    try fm.createDirectory(at: bin, withIntermediateDirectories: true)

    let descriptor = RuntimeDescriptor(
        id: "alpha",
        executable: "bin/runtime",
        supportedCPUBackends: [.rosetta],
        supportedGraphicsBackends: [.dxmt]
    )
    try JSONEncoder().encode(descriptor).write(to: runtimeRoot.appendingPathComponent("runtime.json"))

    let runtimeExecutable = bin.appendingPathComponent("runtime")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: runtimeExecutable)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runtimeExecutable.path)

    let catalog = RuntimeCatalog(runtimesURL: runtimes)
    let resolved = try catalog.resolve(identifier: "alpha", fileManager: fm)

    #expect(resolved.descriptor.id == "alpha")
    #expect(resolved.rootURL.resolvingSymlinksInPath() == runtimeRoot.resolvingSymlinksInPath())
}

@Test func launchSessionResolvesInstalledRuntimeAndPaths() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let paths = RuntimePaths(baseURL: root)
    try paths.ensureDirectories(fileManager: fm)

    let runtimeRoot = paths.runtimesURL.appendingPathComponent("alpha", isDirectory: true)
    let bin = runtimeRoot.appendingPathComponent("bin", isDirectory: true)
    try fm.createDirectory(at: bin, withIntermediateDirectories: true)

    let descriptor = RuntimeDescriptor(
        id: "alpha",
        executable: "bin/runtime",
        argumentPrefix: ["--prefix", "${PREFIX_ROOT}"],
        environment: ["RUNTIME_CACHE": "${CACHE_ROOT}"],
        supportedCPUBackends: [.rosetta],
        supportedGraphicsBackends: [.dxmt]
    )
    try JSONEncoder().encode(descriptor).write(to: runtimeRoot.appendingPathComponent("runtime.json"))

    let runtimeExecutable = bin.appendingPathComponent("runtime")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: runtimeExecutable)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runtimeExecutable.path)

    let targetRoot = paths.targetURL(for: "sample")
    try fm.createDirectory(at: targetRoot, withIntermediateDirectories: true)
    try Data().write(to: targetRoot.appendingPathComponent("target.exe"))

    let profile = RuntimeProfile(
        id: "sample",
        displayName: "Sample",
        bundleIdentifier: "com.pajic.sample",
        executable: "target.exe",
        runtimeIdentifier: "alpha",
        cpu: .rosetta,
        graphics: .dxmt
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

    #expect(session.runtimeIdentifier == "alpha")
    #expect(session.command.executableURL.path == "/usr/bin/arch")
    #expect(session.command.arguments[0] == "-x86_64")
    #expect(URL(fileURLWithPath: session.command.arguments[1]).resolvingSymlinksInPath() == runtimeExecutable.resolvingSymlinksInPath())
    #expect(session.command.arguments[2] == "--prefix")
    #expect(URL(fileURLWithPath: session.command.arguments[3]).resolvingSymlinksInPath() == paths.prefixURL(for: "sample").resolvingSymlinksInPath())
    #expect(URL(fileURLWithPath: session.command.environment["RUNTIME_CACHE"]!).resolvingSymlinksInPath() == paths.cacheURL(for: "sample").resolvingSymlinksInPath())
    #expect(URL(fileURLWithPath: session.command.environment["OUTRAGE_TARGET_ROOT"]!).resolvingSymlinksInPath() == targetRoot.resolvingSymlinksInPath())
    #expect(fm.fileExists(atPath: paths.prefixURL(for: "sample").path))
    #expect(fm.fileExists(atPath: paths.cacheURL(for: "sample").path))
}

@Test func processRunnerExecutesNativeCommand() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let command = LaunchCommand(
        executableURL: URL(fileURLWithPath: "/bin/sh"),
        arguments: ["-c", "exit 0"],
        workingDirectoryURL: root,
        environment: ["OUTRAGE_TEST": "1"],
        graphics: .metal
    )

    let running = try ProcessRunner.start(command, fileManager: fm)
    running.waitUntilExit()

    #expect(running.terminationStatus == 0)
}
