import Foundation

public struct RuntimeInstallReceipt: Codable, Equatable, Sendable {
    public var runtimeIdentifier: String
    public var version: String
    public var archiveSHA256: String

    public init(runtimeIdentifier: String, version: String, archiveSHA256: String) {
        self.runtimeIdentifier = runtimeIdentifier
        self.version = version
        self.archiveSHA256 = archiveSHA256.lowercased()
    }

    public static let fileName = ".outrage-runtime.json"

    public static func load(
        from runtimeRoot: URL,
        fileManager: FileManager = .default
    ) throws -> RuntimeInstallReceipt? {
        let url = runtimeRoot.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(RuntimeInstallReceipt.self, from: Data(contentsOf: url))
    }

    public func write(to runtimeRoot: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(
            to: runtimeRoot.appendingPathComponent(Self.fileName),
            options: .atomic
        )
    }

    public func matches(_ manifest: RuntimePackageManifest) -> Bool {
        runtimeIdentifier == manifest.runtimeIdentifier &&
        version == manifest.version &&
        archiveSHA256.caseInsensitiveCompare(manifest.archiveSHA256) == .orderedSame
    }
}
