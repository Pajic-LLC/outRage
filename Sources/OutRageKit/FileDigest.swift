import CryptoKit
import Foundation

public enum FileDigest {
    public static func sha256(
        of url: URL,
        chunkSize: Int = 1024 * 1024
    ) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            guard let data = try handle.read(upToCount: chunkSize), !data.isEmpty else { break }
            hasher.update(data: data)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public static func verifySHA256(_ expected: String, of url: URL) throws -> Bool {
        let normalized = expected.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return try sha256(of: url) == normalized
    }
}
