import Foundation
import Testing
@testable import OutRageKit

@Test func effectiveProfileResolverPrefersInstalledMatchingOverride() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let bundledURL = root.appendingPathComponent("bundled.json")
    let bundled = RuntimeProfile(
        id: "target",
        displayName: "Target",
        bundleIdentifier: "com.pajic.target",
        executable: "target.exe",
        arguments: ["--bundled"]
    )
    try ProfileLoader.save(bundled, to: bundledURL)

    let paths = RuntimePaths(baseURL: root.appendingPathComponent("data", isDirectory: true))
    try paths.ensureDirectories(fileManager: fm)
    let override = RuntimeProfile(
        id: "target",
        displayName: "Target",
        bundleIdentifier: "com.pajic.target",
        executable: "target.exe",
        arguments: ["--updated"]
    )
    try ProfileLoader.save(
        override,
        to: paths.profilesURL.appendingPathComponent("target.json")
    )

    #expect(try EffectiveProfileResolver.resolve(
        bundledProfileURL: bundledURL,
        paths: paths,
        fileManager: fm
    ) == override)
}

@Test func effectiveProfileResolverFallsBackWhenOverrideIsInvalid() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let bundledURL = root.appendingPathComponent("bundled.json")
    let bundled = RuntimeProfile(
        id: "target",
        displayName: "Target",
        bundleIdentifier: "com.pajic.target",
        executable: "target.exe"
    )
    try ProfileLoader.save(bundled, to: bundledURL)

    let paths = RuntimePaths(baseURL: root.appendingPathComponent("data", isDirectory: true))
    try paths.ensureDirectories(fileManager: fm)
    try Data("not-json".utf8).write(
        to: paths.profilesURL.appendingPathComponent("target.json")
    )

    #expect(try EffectiveProfileResolver.resolve(
        bundledProfileURL: bundledURL,
        paths: paths,
        fileManager: fm
    ) == bundled)
}
