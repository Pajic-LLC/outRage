import Foundation

public struct RuntimePackageManifest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var runtimeIdentifier: String
    public var version: String
    public var archiveSHA256: String
    public var rootSubdirectory: String?

    public init(
        schemaVersion: Int = 1,
        runtimeIdentifier: String,
        version: String,
        archiveSHA256: String,
        rootSubdirectory: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.runtimeIdentifier = runtimeIdentifier
        self.version = version
        self.archiveSHA256 = archiveSHA256.lowercased()
        self.rootSubdirectory = rootSubdirectory
    }

    public func validate() throws {
        guard schemaVersion == 1 else {
            throw RuntimePackageError.unsupportedSchema(schemaVersion)
        }
        guard !runtimeIdentifier.isEmpty, !runtimeIdentifier.contains("/") else {
            throw RuntimePackageError.invalidRuntimeIdentifier(runtimeIdentifier)
        }
        guard !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RuntimePackageError.invalidVersion
        }
        guard archiveSHA256.range(of: #"^[a-fA-F0-9]{64}$"#, options: .regularExpression) != nil else {
            throw RuntimePackageError.invalidSHA256
        }
        if let rootSubdirectory {
            guard !rootSubdirectory.hasPrefix("/"), !rootSubdirectory.contains("..") else {
                throw RuntimePackageError.invalidRootSubdirectory(rootSubdirectory)
            }
        }
    }
}

public enum RuntimePackageError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchema(Int)
    case invalidRuntimeIdentifier(String)
    case invalidVersion
    case invalidSHA256
    case invalidRootSubdirectory(String)
    case checksumMismatch
    case packagingFailed(Int32)
    case extractionFailed(Int32)
    case descriptorMissing
    case descriptorIdentifierMismatch(expected: String, actual: String)

    public var description: String {
        switch self {
        case .unsupportedSchema(let value): return "Unsupported runtime package schema: \(value)"
        case .invalidRuntimeIdentifier(let value): return "Invalid runtime identifier: \(value)"
        case .invalidVersion: return "Runtime package version cannot be empty"
        case .invalidSHA256: return "Runtime package SHA-256 must be 64 hexadecimal characters"
        case .invalidRootSubdirectory(let value): return "Invalid runtime package root: \(value)"
        case .checksumMismatch: return "Runtime package checksum does not match"
        case .packagingFailed(let status): return "Runtime package creation failed with status \(status)"
        case .extractionFailed(let status): return "Runtime package extraction failed with status \(status)"
        case .descriptorMissing: return "Runtime package does not contain runtime.json"
        case .descriptorIdentifierMismatch(let expected, let actual):
            return "Runtime package identifier mismatch: expected \(expected), found \(actual)"
        }
    }
}
