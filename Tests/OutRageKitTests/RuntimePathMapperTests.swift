import Foundation
import Testing
@testable import OutRageKit

@Test func runtimePathMapperLinksTargetIntoPrefix() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let target = root.appendingPathComponent("target", isDirectory: true)
    let prefix = root.appendingPathComponent("prefix", isDirectory: true)
    let cache = root.appendingPathComponent("cache", isDirectory: true)
    let runtime = root.appendingPathComponent("runtime", isDirectory: true)
    for directory in [target, prefix, cache, runtime] {
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    try Data("payload".utf8).write(to: target.appendingPathComponent("asset.bin"))

    let context = RuntimeLaunchContext(
        runtimeRoot: runtime,
        targetRoot: target,
        prefixRoot: prefix,
        cacheRoot: cache
    )
    let mapping = RuntimePathMapping(
        sourceScope: .target,
        destinationScope: .prefix,
        destination: "dosdevices/o:"
    )

    try RuntimePathMapper.apply([mapping], context: context, fileManager: fm)

    let linked = prefix.appendingPathComponent("dosdevices/o:")
    #expect(try linked.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true)
    #expect(try Data(contentsOf: linked.appendingPathComponent("asset.bin")) == Data("payload".utf8))
}

@Test func runtimePathMapperRefusesOccupiedDestination() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let target = root.appendingPathComponent("target", isDirectory: true)
    let prefix = root.appendingPathComponent("prefix", isDirectory: true)
    let cache = root.appendingPathComponent("cache", isDirectory: true)
    let runtime = root.appendingPathComponent("runtime", isDirectory: true)
    for directory in [target, prefix, cache, runtime] {
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    let occupied = prefix.appendingPathComponent("dosdevices/o:")
    try fm.createDirectory(at: occupied.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("do-not-replace".utf8).write(to: occupied)

    let context = RuntimeLaunchContext(
        runtimeRoot: runtime,
        targetRoot: target,
        prefixRoot: prefix,
        cacheRoot: cache
    )

    #expect(throws: RuntimePathMapperError.self) {
        try RuntimePathMapper.apply([
            RuntimePathMapping(
                sourceScope: .target,
                destinationScope: .prefix,
                destination: "dosdevices/o:"
            )
        ], context: context, fileManager: fm)
    }
}
