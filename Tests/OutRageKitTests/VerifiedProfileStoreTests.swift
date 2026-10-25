import CryptoKit
import Foundation
import Testing
@testable import OutRageKit

@Test func verifiedProfileStoreReverifiesStoredEnvelopeOnResolve() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }
    try fm.createDirectory(at: root, withIntermediateDirectories: true)

    let privateKey = Curve25519.Signing.PrivateKey()
    let trustStore = ProfileTrustStore(
        publicKeys: ["release": privateKey.publicKey.rawRepresentation]
    )
    let bundled = RuntimeProfile(
        id: "verified-target",
        displayName: "Verified Target",
        bundleIdentifier: "com.pajic.verified-target",
        executable: "target.exe",
        arguments: ["--bundled"]
    )
    let bundledURL = root.appendingPathComponent("bundled.json")
    try ProfileLoader.save(bundled, to: bundledURL)

    let updated = RuntimeProfile(
        id: bundled.id,
        displayName: bundled.displayName,
        bundleIdentifier: bundled.bundleIdentifier,
        executable: bundled.executable,
        arguments: ["--updated"]
    )
    let payload = try JSONEncoder().encode(updated)
    let envelope = SignedProfileEnvelope(
        keyID: "release",
        payload: payload,
        signature: try privateKey.signature(for: payload)
    )
    let envelopeData = try JSONEncoder().encode(envelope)
    let paths = RuntimePaths(baseURL: root.appendingPathComponent("data", isDirectory: true))

    _ = try VerifiedProfileStore.install(
        envelopeData: envelopeData,
        expectedProfileID: bundled.id,
        trustStore: trustStore,
        paths: paths,
        fileManager: fm
    )

    #expect(try VerifiedProfileStore.resolve(
        bundledProfileURL: bundledURL,
        trustStore: trustStore,
        paths: paths,
        fileManager: fm
    ) == updated)

    var tampered = envelopeData
    tampered.append(0x20)
    try tampered.write(
        to: VerifiedProfileStore.envelopeURL(profileID: bundled.id, paths: paths),
        options: .atomic
    )

    #expect(try VerifiedProfileStore.resolve(
        bundledProfileURL: bundledURL,
        trustStore: trustStore,
        paths: paths,
        fileManager: fm
    ) == bundled)
}
