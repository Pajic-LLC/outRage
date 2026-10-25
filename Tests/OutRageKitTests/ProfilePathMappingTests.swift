import Foundation
import Testing
@testable import OutRageKit

@Test func profilePathMappingsCanDescribeDefaultInstallRedirects() throws {
    let mapping = RuntimePathMapping(
        sourceScope: .target,
        source: ".",
        destinationScope: .prefix,
        destination: "drive_c/Program Files/Example/Target"
    )
    let profile = RuntimeProfile(
        id: "mapped-target",
        displayName: "Mapped Target",
        bundleIdentifier: "com.pajic.mapped-target",
        executable: "target.exe",
        pathMappings: [mapping]
    )

    try profile.validate()
    #expect(profile.pathMappings == [mapping])
}

@Test func profilePathMappingsRejectTraversal() {
    let profile = RuntimeProfile(
        id: "bad-mapping",
        displayName: "Bad Mapping",
        bundleIdentifier: "com.pajic.bad-mapping",
        executable: "target.exe",
        pathMappings: [
            RuntimePathMapping(
                sourceScope: .target,
                destinationScope: .prefix,
                destination: "../outside"
            )
        ]
    )

    #expect(throws: RuntimeDescriptorError.self) {
        try profile.validate()
    }
}

@Test func runtimePathMapperAdoptsEmptyLauncherCreatedInstallDirectory() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let context = RuntimeLaunchContext(
        runtimeRoot: root.appendingPathComponent("Runtime", isDirectory: true),
        targetRoot: root.appendingPathComponent("Target", isDirectory: true),
        prefixRoot: root.appendingPathComponent("Prefix", isDirectory: true),
        cacheRoot: root.appendingPathComponent("Cache", isDirectory: true)
    )
    try fm.createDirectory(at: context.targetRoot, withIntermediateDirectories: true)
    let destination = context.prefixRoot.appendingPathComponent("drive_c/Program Files/Example/Target", isDirectory: true)
    try fm.createDirectory(at: destination, withIntermediateDirectories: true)

    try RuntimePathMapper.apply(
        [
            RuntimePathMapping(
                sourceScope: .target,
                source: ".",
                destinationScope: .prefix,
                destination: "drive_c/Program Files/Example/Target"
            )
        ],
        context: context,
        fileManager: fm
    )

    let values = try destination.resourceValues(forKeys: [.isSymbolicLinkKey])
    #expect(values.isSymbolicLink == true)
    #expect(destination.resolvingSymlinksInPath() == context.targetRoot.resolvingSymlinksInPath())
}

@Test func runtimePathMapperNeverReplacesNonEmptyLauncherDirectory() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let context = RuntimeLaunchContext(
        runtimeRoot: root.appendingPathComponent("Runtime", isDirectory: true),
        targetRoot: root.appendingPathComponent("Target", isDirectory: true),
        prefixRoot: root.appendingPathComponent("Prefix", isDirectory: true),
        cacheRoot: root.appendingPathComponent("Cache", isDirectory: true)
    )
    try fm.createDirectory(at: context.targetRoot, withIntermediateDirectories: true)
    let destination = context.prefixRoot.appendingPathComponent("drive_c/Program Files/Example/Target", isDirectory: true)
    try fm.createDirectory(at: destination, withIntermediateDirectories: true)
    try Data("existing".utf8).write(to: destination.appendingPathComponent("existing.bin"))

    #expect(throws: RuntimePathMapperError.destinationOccupied(destination.standardizedFileURL.path)) {
        try RuntimePathMapper.apply(
            [
                RuntimePathMapping(
                    sourceScope: .target,
                    source: ".",
                    destinationScope: .prefix,
                    destination: "drive_c/Program Files/Example/Target"
                )
            ],
            context: context,
            fileManager: fm
        )
    }
    #expect(fm.fileExists(atPath: destination.appendingPathComponent("existing.bin").path))
}
