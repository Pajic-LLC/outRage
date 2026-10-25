import Foundation

public struct ProfileUpdateSource: Equatable, Sendable {
    public let url: URL
    public let expectedProfileID: String

    public init(url: URL, expectedProfileID: String) {
        self.url = url
        self.expectedProfileID = expectedProfileID
    }

    public func validate() throws {
        guard url.isFileURL || url.scheme?.lowercased() == "https" else {
            throw ProfileUpdateError.insecureURL
        }
        guard !expectedProfileID.isEmpty,
              expectedProfileID.range(of: #"^[a-z0-9][a-z0-9._-]*$"#, options: .regularExpression) != nil else {
            throw ProfileUpdateError.invalidProfileID(expectedProfileID)
        }
    }
}

public enum ProfileUpdateChannel {
    @discardableResult
    public static func install(
        from source: ProfileUpdateSource,
        trustStore: ProfileTrustStore,
        paths: RuntimePaths = RuntimePaths(),
        fileManager: FileManager = .default
    ) async throws -> RuntimeProfile {
        try source.validate()
        try paths.ensureDirectories(fileManager: fileManager)

        let data: Data
        if source.url.isFileURL {
            data = try Data(contentsOf: source.url)
        } else {
            let (downloaded, response) = try await URLSession.shared.data(from: source.url)
            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                throw ProfileUpdateError.httpStatus(http.statusCode)
            }
            data = downloaded
        }

        let envelope: SignedProfileEnvelope
        do {
            envelope = try JSONDecoder().decode(SignedProfileEnvelope.self, from: data)
        } catch {
            throw ProfileUpdateError.invalidEnvelope
        }

        let profile = try trustStore.verify(envelope)
        guard profile.id == source.expectedProfileID else {
            throw ProfileUpdateError.profileIDMismatch(
                expected: source.expectedProfileID,
                actual: profile.id
            )
        }

        let destination = paths.profilesURL.appendingPathComponent(profile.id + ".json")
        let temporary = paths.profilesURL.appendingPathComponent(".profile-" + UUID().uuidString + ".json")
        defer { try? fileManager.removeItem(at: temporary) }

        try ProfileLoader.save(profile, to: temporary)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: temporary, to: destination)
        return profile
    }
}

public enum ProfileUpdateError: Error, Equatable, CustomStringConvertible {
    case insecureURL
    case invalidProfileID(String)
    case httpStatus(Int)
    case invalidEnvelope
    case profileIDMismatch(expected: String, actual: String)

    public var description: String {
        switch self {
        case .insecureURL: return "Profile update URL must use HTTPS"
        case .invalidProfileID(let value): return "Invalid expected profile id: \(value)"
        case .httpStatus(let status): return "Profile update failed with HTTP status \(status)"
        case .invalidEnvelope: return "Profile update is not a valid signed envelope"
        case .profileIDMismatch(let expected, let actual):
            return "Profile update id mismatch: expected \(expected), found \(actual)"
        }
    }
}
