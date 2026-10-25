import Foundation

public enum ArtifactDownloader {
    @discardableResult
    public static func download(
        from sourceURL: URL,
        to destinationURL: URL,
        expectedSHA256: String? = nil,
        fileManager: FileManager = .default
    ) async throws -> URL {
        let (temporaryURL, response) = try await URLSession.shared.download(from: sourceURL)

        if let http = response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            throw ArtifactDownloadError.httpStatus(http.statusCode)
        }

        if let expectedSHA256,
           try !FileDigest.verifySHA256(expectedSHA256, of: temporaryURL) {
            throw ArtifactDownloadError.checksumMismatch
        }

        let parent = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)

        let partial = parent.appendingPathComponent(".partial-" + UUID().uuidString)
        defer { try? fileManager.removeItem(at: partial) }
        try fileManager.copyItem(at: temporaryURL, to: partial)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: partial, to: destinationURL)

        return destinationURL
    }
}

public enum ArtifactDownloadError: Error, Equatable, CustomStringConvertible {
    case httpStatus(Int)
    case checksumMismatch

    public var description: String {
        switch self {
        case .httpStatus(let status): return "Download failed with HTTP status \(status)"
        case .checksumMismatch: return "Downloaded artifact checksum does not match"
        }
    }
}
