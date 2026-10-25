import Foundation
import Testing
@testable import OutRageKit

@Test func dxmtBackendCachePreparationCreatesConfiguredDirectories() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let context = RuntimeLaunchContext(
        runtimeRoot: root.appendingPathComponent("Runtime", isDirectory: true),
        targetRoot: root.appendingPathComponent("Target", isDirectory: true),
        prefixRoot: root.appendingPathComponent("Prefix", isDirectory: true),
        cacheRoot: root.appendingPathComponent("Cache", isDirectory: true)
    )

    try GraphicsBackendCachePreparer.prepare(
        graphics: .dxmt,
        context: context,
        fileManager: fm
    )

    #expect(fm.fileExists(atPath: context.cacheRoot.path))
    #expect(fm.fileExists(atPath: context.cacheRoot.appendingPathComponent("dxmt-shaders").path))
    #expect(fm.fileExists(atPath: context.cacheRoot.appendingPathComponent("dxmt-logs").path))
}

@Test func nonDXMTBackendCachePreparationOnlyCreatesRoot() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let context = RuntimeLaunchContext(
        runtimeRoot: root.appendingPathComponent("Runtime", isDirectory: true),
        targetRoot: root.appendingPathComponent("Target", isDirectory: true),
        prefixRoot: root.appendingPathComponent("Prefix", isDirectory: true),
        cacheRoot: root.appendingPathComponent("Cache", isDirectory: true)
    )

    try GraphicsBackendCachePreparer.prepare(
        graphics: .metal,
        context: context,
        fileManager: fm
    )

    #expect(fm.fileExists(atPath: context.cacheRoot.path))
    #expect(!fm.fileExists(atPath: context.cacheRoot.appendingPathComponent("dxmt-shaders").path))
}
