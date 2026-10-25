import Foundation
import Testing
@testable import OutRageKit

@Test func generatedAppBundleCarriesNativeGameMetadataAndIcon() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }
    try fm.createDirectory(at: root, withIntermediateDirectories: true)

    let host = root.appendingPathComponent("host")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: host)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: host.path)

    let icon = root.appendingPathComponent("icon.icns")
    try Data("fake-icns".utf8).write(to: icon)

    let profile = RuntimeProfile(
        id: "native-bundle",
        displayName: "Native Bundle",
        bundleIdentifier: "com.pajic.native-bundle",
        executable: "target.exe"
    )
    let app = try AppBundleBuilder().build(
        profile: profile,
        hostExecutable: host,
        iconURL: icon,
        outputDirectory: root,
        fileManager: fm
    )

    let plistURL = app.appendingPathComponent("Contents/Info.plist")
    let data = try Data(contentsOf: plistURL)
    let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

    #expect(plist["CFBundleIdentifier"] as? String == "com.pajic.native-bundle")
    #expect(plist["LSApplicationCategoryType"] as? String == "public.app-category.games")
    #expect(plist["NSHighResolutionCapable"] as? Bool == true)
    #expect(plist["CFBundleIconFile"] as? String == "AppIcon")
    #expect(fm.fileExists(atPath: app.appendingPathComponent("Contents/Resources/AppIcon.icns").path))
}
