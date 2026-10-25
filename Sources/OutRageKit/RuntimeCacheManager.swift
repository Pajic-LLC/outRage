import Foundation

public struct RuntimeCacheLocation: Equatable, Sendable {
    public let rootURL: URL
    public let shaderURL: URL
    public let fingerprintURL: URL

    public init(rootURL: URL, shaderURL: URL, fingerprintURL: URL) {
        self.rootURL = rootURL
        self.shaderURL = shaderURL
        self.fingerprintURL = fingerprintURL
    }
}

public enum RuntimeCacheManager {
    public static let defaultRetainedBuilds = 3

    public static func prepare(
        fingerprint: RuntimeCacheFingerprint,
        paths: RuntimePaths = RuntimePaths(),
        fileManager: FileManager = .default,
        retentionLimit: Int = defaultRetainedBuilds
    ) throws -> RuntimeCacheLocation {
        let profileCache = paths.cacheURL(for: fingerprint.profileID)
        let root = profileCache
            .appendingPathComponent("Builds", isDirectory: true)
            .appendingPathComponent(fingerprint.stableKey, isDirectory: true)
        let shader = root.appendingPathComponent("Shaders", isDirectory: true)
        let fingerprintURL = root.appendingPathComponent("fingerprint.json")

        try fileManager.createDirectory(at: shader, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: fingerprintURL.path) {
            let existing = try JSONDecoder().decode(
                RuntimeCacheFingerprint.self,
                from: Data(contentsOf: fingerprintURL)
            )
            guard existing == fingerprint else {
                throw RuntimeCacheError.fingerprintCollision
            }
        } else {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(fingerprint).write(to: fingerprintURL, options: .atomic)
        }

        // Treat every successful prepare as a cache hit so frequently-used builds
        // survive pruning even when their directory was originally created long ago.
        try? fileManager.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: root.path
        )
        try prune(
            profileID: fingerprint.profileID,
            keepingMostRecent: retentionLimit,
            paths: paths,
            fileManager: fileManager
        )

        return RuntimeCacheLocation(
            rootURL: root,
            shaderURL: shader,
            fingerprintURL: fingerprintURL
        )
    }

    public static func prune(
        profileID: String,
        keeping stableKeys: Set<String>,
        paths: RuntimePaths = RuntimePaths(),
        fileManager: FileManager = .default
    ) throws {
        let builds = paths.cacheURL(for: profileID).appendingPathComponent("Builds", isDirectory: true)
        guard fileManager.fileExists(atPath: builds.path) else { return }

        for url in try fileManager.contentsOfDirectory(
            at: builds,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            guard !stableKeys.contains(url.lastPathComponent) else { continue }
            try fileManager.removeItem(at: url)
        }
    }

    public static func prune(
        profileID: String,
        keepingMostRecent limit: Int,
        paths: RuntimePaths = RuntimePaths(),
        fileManager: FileManager = .default
    ) throws {
        let builds = paths.cacheURL(for: profileID).appendingPathComponent("Builds", isDirectory: true)
        guard fileManager.fileExists(atPath: builds.path) else { return }

        let keepCount = max(0, limit)
        let candidates = try fileManager.contentsOfDirectory(
            at: builds,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }

        let sorted = candidates.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if lhsDate == rhsDate {
                return lhs.lastPathComponent < rhs.lastPathComponent
            }
            return lhsDate > rhsDate
        }

        for url in sorted.dropFirst(keepCount) {
            try fileManager.removeItem(at: url)
        }
    }
}

public enum RuntimeCacheError: Error, Equatable, CustomStringConvertible {
    case fingerprintCollision

    public var description: String {
        switch self {
        case .fingerprintCollision:
            return "Runtime cache key collision detected"
        }
    }
}
