import Foundation
import Testing
@testable import OutRageKit

@Test func runtimeCacheManagerCreatesStableBuildSpecificShaderCache() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let paths = RuntimePaths(baseURL: root)
    let fingerprint = RuntimeCacheFingerprint(
        profileID: "cache-target",
        target: TargetBuildFingerprint(
            executableSHA256: String(repeating: "a", count: 64),
            fileSize: 1234
        ),
        runtimeIdentifier: "runtime",
        runtimeRevision: 2,
        graphicsBackend: .dxmt
    )

    let first = try RuntimeCacheManager.prepare(
        fingerprint: fingerprint,
        paths: paths,
        fileManager: fm
    )
    let second = try RuntimeCacheManager.prepare(
        fingerprint: fingerprint,
        paths: paths,
        fileManager: fm
    )

    #expect(first == second)
    #expect(fm.fileExists(atPath: first.shaderURL.path))
    #expect(fm.fileExists(atPath: first.fingerprintURL.path))
}

@Test func runtimeCacheFingerprintChangesAcrossTargetBuilds() {
    let first = RuntimeCacheFingerprint(
        profileID: "target",
        target: TargetBuildFingerprint(
            executableSHA256: String(repeating: "1", count: 64),
            fileSize: 100
        ),
        runtimeIdentifier: "runtime",
        runtimeRevision: 1,
        graphicsBackend: .dxmt
    )
    let second = RuntimeCacheFingerprint(
        profileID: "target",
        target: TargetBuildFingerprint(
            executableSHA256: String(repeating: "2", count: 64),
            fileSize: 101
        ),
        runtimeIdentifier: "runtime",
        runtimeRevision: 1,
        graphicsBackend: .dxmt
    )

    #expect(first.stableKey != second.stableKey)
}
