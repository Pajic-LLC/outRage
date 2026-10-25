import Foundation
import Testing
@testable import OutRageKit

@Test func targetImporterLinksExistingLibraryWithoutCopying() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let source = root.appendingPathComponent("existing", isDirectory: true)
    try fm.createDirectory(at: source, withIntermediateDirectories: true)
    let executable = source.appendingPathComponent("game/target.exe")
    try fm.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("target".utf8).write(to: executable)

    let paths = RuntimePaths(baseURL: root.appendingPathComponent("runtime-data", isDirectory: true))
    let profile = RuntimeProfile(
        id: "import-test",
        displayName: "Import Test",
        bundleIdentifier: "com.pajic.import-test",
        executable: "game/target.exe",
        acquisition: AcquisitionDescriptor(kind: .importExisting)
    )

    let linked = try TargetImporter.linkExisting(
        sourceDirectory: source,
        profile: profile,
        paths: paths,
        fileManager: fm
    )

    let values = try linked.resourceValues(forKeys: [.isSymbolicLinkKey])
    #expect(values.isSymbolicLink == true)
    #expect(fm.fileExists(atPath: linked.appendingPathComponent(profile.executable).path))
    #expect(try Data(contentsOf: linked.appendingPathComponent(profile.executable)) == Data("target".utf8))
}
