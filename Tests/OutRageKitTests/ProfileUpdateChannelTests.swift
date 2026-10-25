import CryptoKit
import Foundation
import Testing
@testable import OutRageKit

@Test func profileUpdateChannelInstallsVerifiedProfileAtomically() async throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }
    try fm.createDirectory(at: root, withIntermediateDirectories: true)

    let privateKey = Curve25519.Signing.PrivateKey()
    let profile = RuntimeProfile(
        id: "updated-target",
        displayName: "Updated Target",
        bundleIdentifier: "com.pajic.updated-target",
        executable: "target.exe",
        arguments: ["--updated"]
    )
    let payload = try JSONEncoder().encode(profile)
    let signature = try privateKey.signature(for: payload)
    let envelope = SignedProfileEnvelope(
        keyID: "release-key",
        payload: payload,
        signature: signature
    )
    let envelopeURL = root.appendingPathComponent("profile.signed.json")
    try JSONEncoder().encode(envelope).write(to: envelopeURL)

    let paths = RuntimePaths(baseURL: root.appendingPathComponent("data", isDirectory: true))
    let installed = try await ProfileUpdateChannel.install(
        from: ProfileUpdateSource(
            url: envelopeURL,
            expectedProfileID: "updated-target"
        ),
        trustStore: ProfileTrustStore(
            publicKeys: ["release-key": privateKey.publicKey.rawRepresentation]
        ),
        paths: paths,
        fileManager: fm
    )

    #expect(installed == profile)
    let stored = try ProfileLoader.load(
        from: paths.profilesURL.appendingPathComponent("updated-target.json")
    )
    #expect(stored == profile)
}

@Test func profileUpdateChannelRejectsWrongTargetID() async throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }
    try fm.createDirectory(at: root, withIntermediateDirectories: true)

    let privateKey = Curve25519.Signing.PrivateKey()
    let profile = RuntimeProfile(
        id: "other-target",
        displayName: "Other Target",
        bundleIdentifier: "com.pajic.other-target",
        executable: "target.exe"
    )
    let payload = try JSONEncoder().encode(profile)
    let signature = try privateKey.signature(for: payload)
    let envelopeURL = root.appendingPathComponent("profile.signed.json")
    try JSONEncoder().encode(SignedProfileEnvelope(
        keyID: "release-key",
        payload: payload,
        signature: signature
    )).write(to: envelopeURL)

    let paths = RuntimePaths(baseURL: root.appendingPathComponent("data", isDirectory: true))
    await #expect(throws: ProfileUpdateError.self) {
        _ = try await ProfileUpdateChannel.install(
            from: ProfileUpdateSource(
                url: envelopeURL,
                expectedProfileID: "expected-target"
            ),
            trustStore: ProfileTrustStore(
                publicKeys: ["release-key": privateKey.publicKey.rawRepresentation]
            ),
            paths: paths,
            fileManager: fm
        )
    }
}
