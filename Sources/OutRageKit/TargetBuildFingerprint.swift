import Foundation

public struct TargetBuildFingerprint: Codable, Equatable, Hashable, Sendable {
    public let executableSHA256: String
    public let fileSize: UInt64

    public init(executableSHA256: String, fileSize: UInt64) {
        self.executableSHA256 = executableSHA256.lowercased()
        self.fileSize = fileSize
    }

    public static func inspect(
        executableURL: URL,
        fileManager: FileManager = .default
    ) throws -> TargetBuildFingerprint {
        let attributes = try fileManager.attributesOfItem(atPath: executableURL.path)
        let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        return TargetBuildFingerprint(
            executableSHA256: try FileDigest.sha256(of: executableURL),
            fileSize: size
        )
    }
}

public struct RuntimeCacheFingerprint: Codable, Equatable, Hashable, Sendable {
    public let profileID: String
    public let target: TargetBuildFingerprint
    public let runtimeIdentifier: String
    public let runtimeRevision: Int
    public let graphicsBackend: GraphicsBackend

    public init(
        profileID: String,
        target: TargetBuildFingerprint,
        runtimeIdentifier: String,
        runtimeRevision: Int,
        graphicsBackend: GraphicsBackend
    ) {
        self.profileID = profileID
        self.target = target
        self.runtimeIdentifier = runtimeIdentifier
        self.runtimeRevision = runtimeRevision
        self.graphicsBackend = graphicsBackend
    }

    public var stableKey: String {
        let input = [
            profileID,
            target.executableSHA256,
            String(target.fileSize),
            runtimeIdentifier,
            String(runtimeRevision),
            graphicsBackend.rawValue
        ].joined(separator: "|")
        return Self.sha256(Data(input.utf8))
    }

    private static func sha256(_ data: Data) -> String {
        // Keep hashing implementation file-based elsewhere; this small in-memory
        // payload is intentionally routed through CryptoKit directly.
        #if canImport(CryptoKit)
        return CryptoHash.sha256(data)
        #else
        return String(inputHashFallback(data))
        #endif
    }

    private static func inputHashFallback(_ data: Data) -> UInt64 {
        data.reduce(1469598103934665603) { value, byte in
            (value ^ UInt64(byte)) &* 1099511628211
        }
    }
}

#if canImport(CryptoKit)
import CryptoKit

private enum CryptoHash {
    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
#endif
