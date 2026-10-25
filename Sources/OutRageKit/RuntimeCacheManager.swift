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
    public static func prepare(
        fingerprint: RuntimeCacheFingerprint,
        paths: RuntimePaths = RuntimePaths(),
        fileManager: FileManager = .default
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
