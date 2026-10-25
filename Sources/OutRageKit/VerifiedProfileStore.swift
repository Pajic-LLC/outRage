import Foundation

public enum VerifiedProfileStore {
    public static func envelopeURL(
        profileID: String,
        paths: RuntimePaths = RuntimePaths()
    ) -> URL {
        paths.profilesURL.appendingPathComponent(profileID + ".signed.json")
    }

    @discardableResult
    public static func install(
        envelopeData: Data,
        expectedProfileID: String,
        trustStore: ProfileTrustStore,
        paths: RuntimePaths = RuntimePaths(),
        fileManager: FileManager = .default
    ) throws -> RuntimeProfile {
        try paths.ensureDirectories(fileManager: fileManager)

        let envelope: SignedProfileEnvelope
        do {
            envelope = try JSONDecoder().decode(SignedProfileEnvelope.self, from: envelopeData)
        } catch {
            throw VerifiedProfileStoreError.invalidEnvelope
        }

        let profile = try trustStore.verify(envelope)
        guard profile.id == expectedProfileID else {
            throw VerifiedProfileStoreError.profileIDMismatch(
                expected: expectedProfileID,
                actual: profile.id
            )
        }

        let destination = envelopeURL(profileID: profile.id, paths: paths)
        let temporary = paths.profilesURL.appendingPathComponent(
            ".signed-profile-" + UUID().uuidString + ".json"
        )
        defer { try? fileManager.removeItem(at: temporary) }

        try envelopeData.write(to: temporary, options: .atomic)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: temporary, to: destination)
        return profile
    }

    public static func resolve(
        bundledProfileURL: URL,
        trustStore: ProfileTrustStore,
        paths: RuntimePaths = RuntimePaths(),
        fileManager: FileManager = .default
    ) throws -> RuntimeProfile {
        let bundled = try ProfileLoader.load(from: bundledProfileURL)
        let signedURL = envelopeURL(profileID: bundled.id, paths: paths)
        guard fileManager.fileExists(atPath: signedURL.path) else {
            return bundled
        }

        do {
            let envelope = try JSONDecoder().decode(
                SignedProfileEnvelope.self,
                from: Data(contentsOf: signedURL)
            )
            let candidate = try trustStore.verify(envelope)
            guard candidate.id == bundled.id else {
                throw VerifiedProfileStoreError.profileIDMismatch(
                    expected: bundled.id,
                    actual: candidate.id
                )
            }
            guard candidate.bundleIdentifier == bundled.bundleIdentifier else {
                throw VerifiedProfileStoreError.bundleIdentifierMismatch(
                    expected: bundled.bundleIdentifier,
                    actual: candidate.bundleIdentifier
                )
            }
            return candidate
        } catch {
            // A damaged or no-longer-trusted override must never brick the app.
            return bundled
        }
    }
}

public enum VerifiedProfileStoreError: Error, Equatable, CustomStringConvertible {
    case invalidEnvelope
    case profileIDMismatch(expected: String, actual: String)
    case bundleIdentifierMismatch(expected: String, actual: String)

    public var description: String {
        switch self {
        case .invalidEnvelope:
            return "Compatibility profile update is not a signed envelope"
        case .profileIDMismatch(let expected, let actual):
            return "Compatibility profile id mismatch: expected \(expected), found \(actual)"
        case .bundleIdentifierMismatch(let expected, let actual):
            return "Compatibility profile bundle id mismatch: expected \(expected), found \(actual)"
        }
    }
}
