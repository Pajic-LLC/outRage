import CryptoKit
import Foundation

public struct SignedProfileEnvelope: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var keyID: String
    public var payloadBase64: String
    public var signatureBase64: String

    public init(
        schemaVersion: Int = 1,
        keyID: String,
        payloadBase64: String,
        signatureBase64: String
    ) {
        self.schemaVersion = schemaVersion
        self.keyID = keyID
        self.payloadBase64 = payloadBase64
        self.signatureBase64 = signatureBase64
    }

    public init(
        keyID: String,
        payload: Data,
        signature: Data
    ) {
        self.init(
            keyID: keyID,
            payloadBase64: payload.base64EncodedString(),
            signatureBase64: signature.base64EncodedString()
        )
    }

    public func validate() throws {
        guard schemaVersion == 1 else {
            throw SignedProfileError.unsupportedSchema(schemaVersion)
        }
        guard !keyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SignedProfileError.emptyKeyID
        }
        guard Data(base64Encoded: payloadBase64) != nil else {
            throw SignedProfileError.invalidPayloadEncoding
        }
        guard Data(base64Encoded: signatureBase64) != nil else {
            throw SignedProfileError.invalidSignatureEncoding
        }
    }
}

public struct ProfileTrustStore: Sendable {
    public let publicKeys: [String: Data]

    public init(publicKeys: [String: Data]) {
        self.publicKeys = publicKeys
    }

    public func verify(_ envelope: SignedProfileEnvelope) throws -> RuntimeProfile {
        try envelope.validate()
        guard let keyData = publicKeys[envelope.keyID] else {
            throw SignedProfileError.unknownKey(envelope.keyID)
        }
        guard let payload = Data(base64Encoded: envelope.payloadBase64) else {
            throw SignedProfileError.invalidPayloadEncoding
        }
        guard let signature = Data(base64Encoded: envelope.signatureBase64) else {
            throw SignedProfileError.invalidSignatureEncoding
        }

        let publicKey: Curve25519.Signing.PublicKey
        do {
            publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
        } catch {
            throw SignedProfileError.invalidPublicKey(envelope.keyID)
        }

        guard publicKey.isValidSignature(signature, for: payload) else {
            throw SignedProfileError.invalidSignature
        }

        let profile: RuntimeProfile
        do {
            profile = try JSONDecoder().decode(RuntimeProfile.self, from: payload)
        } catch {
            throw SignedProfileError.invalidProfilePayload
        }
        try profile.validate()
        return profile
    }
}

public enum SignedProfileError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchema(Int)
    case emptyKeyID
    case invalidPayloadEncoding
    case invalidSignatureEncoding
    case unknownKey(String)
    case invalidPublicKey(String)
    case invalidSignature
    case invalidProfilePayload

    public var description: String {
        switch self {
        case .unsupportedSchema(let value): return "Unsupported signed profile schema: \(value)"
        case .emptyKeyID: return "Signed profile key id cannot be empty"
        case .invalidPayloadEncoding: return "Signed profile payload is not valid base64"
        case .invalidSignatureEncoding: return "Signed profile signature is not valid base64"
        case .unknownKey(let keyID): return "Signed profile uses an unknown key: \(keyID)"
        case .invalidPublicKey(let keyID): return "Signed profile public key is invalid: \(keyID)"
        case .invalidSignature: return "Signed profile signature verification failed"
        case .invalidProfilePayload: return "Signed profile payload is not a valid runtime profile"
        }
    }
}
