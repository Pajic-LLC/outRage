import Foundation
import Testing
@testable import OutRageKit

@Test func launchSessionUsesPEHintsForAutomaticGraphicsSelection() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let paths = RuntimePaths(baseURL: root)
    try paths.ensureDirectories(fileManager: fm)
    try paths.ensureTargetDirectories(for: "auto-graphics", fileManager: fm)

    let runtimeRoot = paths.runtimesURL.appendingPathComponent("multi-graphics", isDirectory: true)
    let bin = runtimeRoot.appendingPathComponent("bin", isDirectory: true)
    try fm.createDirectory(at: bin, withIntermediateDirectories: true)
    let runtimeExecutable = bin.appendingPathComponent("runtime")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: runtimeExecutable)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runtimeExecutable.path)

    let descriptor = RuntimeDescriptor(
        id: "multi-graphics",
        executable: "bin/runtime",
        supportedCPUBackends: [.native],
        supportedGraphicsBackends: [.dxmt, .d3dMetal]
    )
    try JSONEncoder().encode(descriptor).write(to: runtimeRoot.appendingPathComponent("runtime.json"))

    let target = paths.targetURL(for: "auto-graphics").appendingPathComponent("target.exe")
    try makeSyntheticPE(machine: 0x8664, imports: ["d3d12.dll", "dxgi.dll"]).write(to: target)

    let profile = RuntimeProfile(
        id: "auto-graphics",
        displayName: "Auto Graphics",
        bundleIdentifier: "com.pajic.auto-graphics",
        executable: "target.exe",
        runtimeIdentifier: "multi-graphics",
        cpu: .native,
        graphics: .auto
    )
    let host = HostCapabilities(
        architecture: "arm64",
        operatingSystemVersion: "test",
        hasMetal: true,
        hasRosetta: false
    )

    let session = try LaunchSessionBuilder.prepare(
        profile: profile,
        paths: paths,
        host: host,
        fileManager: fm
    )

    #expect(session.plan.graphics == .d3dMetal)
    #expect(session.command.graphics == .d3dMetal)
}

private func makeSyntheticPE(machine: UInt16, imports: [String]) -> Data {
    var data = Data(repeating: 0, count: 512)
    data[0] = 0x4d
    data[1] = 0x5a
    let peOffset: UInt32 = 0x80
    data[0x3c] = UInt8(peOffset & 0xff)
    data[0x3d] = UInt8((peOffset >> 8) & 0xff)
    data[0x3e] = UInt8((peOffset >> 16) & 0xff)
    data[0x3f] = UInt8((peOffset >> 24) & 0xff)
    data[0x80] = 0x50
    data[0x81] = 0x45
    data[0x82] = 0x00
    data[0x83] = 0x00
    data[0x84] = UInt8(machine & 0xff)
    data[0x85] = UInt8((machine >> 8) & 0xff)
    data.append(Data(imports.joined(separator: " ").utf8))
    return data
}
