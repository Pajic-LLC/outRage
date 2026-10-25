import Foundation
import Testing
@testable import OutRageKit

@Test func generatedGameBundleCanBeAdHocSignedAndVerified() throws {
    #if os(macOS)
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }
    try fm.createDirectory(at: root, withIntermediateDirectories: true)

    let host = root.appendingPathComponent("host")
    try fm.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: host)
    let profile = RuntimeProfile(
        id: "signed-app",
        displayName: "Signed App",
        bundleIdentifier: "com.pajic.signed-app",
        executable: "target.exe"
    )
    let app = try AppBundleBuilder().build(
        profile: profile,
        hostExecutable: host,
        outputDirectory: root,
        fileManager: fm
    )

    try AppBundleCodeSigner.sign(appURL: app)
    try AppBundleCodeSigner.verify(appURL: app)
    #endif
}
