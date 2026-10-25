import CryptoKit
import Foundation
import Testing
@testable import OutRageKit

@Test func signedProfileTrustStoreAcceptsValidEnvelope() throws {
    let privateKey = Curve25519.Signing.PrivateKey()
    let profile = RuntimeProfile(
        id: "signed-target",
        displayName: "Signed Target",
        bundleIdentifier: "com.pajic.signed-target",
        executable: "target.exe"
    )
    let payload = try JSONEncoder().encode(profile)
    let signature = try privateKey.signature(for: payload)
    let envelope = SignedProfileEnvelope(
        keyID: "test-key",
        payload: payload,
        signature: signature
    )
    let trustStore = ProfileTrustStore(
        publicKeys: ["test-key": privateKey.publicKey.rawRepresentation]
    )

    #expect(try trustStore.verify(envelope) == profile)
}

@Test func signedProfileTrustStoreRejectsTamperedPayload() throws {
    let privateKey = Curve25519.Signing.PrivateKey()
    let profile = RuntimeProfile(
        id: "signed-target",
        displayName: "Signed Target",
        bundleIdentifier: "com.pajic.signed-target",
        executable: "target.exe"
    )
    let payload = try JSONEncoder().encode(profile)
    let signature = try privateKey.signature(for: payload)
    var tampered = payload
    tampered.append(0x20)
    let envelope = SignedProfileEnvelope(
        keyID: "test-key",
        payload: tampered,
        signature: signature
    )
    let trustStore = ProfileTrustStore(
        publicKeys: ["test-key": privateKey.publicKey.rawRepresentation]
    )

    #expect(throws: SignedProfileError.self) {
        try trustStore.verify(envelope)
    }
}
