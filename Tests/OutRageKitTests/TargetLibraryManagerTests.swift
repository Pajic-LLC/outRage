import Foundation
import Testing
@testable import OutRageKit

@Test func targetLibraryManagerPlacesManagedTargetOnExternalRoot() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let dataRoot = root.appendingPathComponent("data", isDirectory: true)
    let externalRoot = root.appendingPathComponent("external", isDirectory: true)
    try fm.createDirectory(at: externalRoot, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let paths = RuntimePaths(baseURL: dataRoot)
    let location = try TargetLibraryManager.placeTarget(
        profileID: "external-target",
        on: externalRoot,
        paths: paths,
        fileManager: fm
    )

    #expect(try location.managedURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true)
    #expect(location.storageURL == externalRoot.appendingPathComponent("outRage Games/external-target", isDirectory: true))

    try Data("payload".utf8).write(to: location.managedURL.appendingPathComponent("asset.bin"))
    #expect(try Data(contentsOf: location.storageURL.appendingPathComponent("asset.bin")) == Data("payload".utf8))
}

@Test func targetLibraryManagerIsIdempotentForSameExternalRoot() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let externalRoot = root.appendingPathComponent("external", isDirectory: true)
    try fm.createDirectory(at: externalRoot, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let paths = RuntimePaths(baseURL: root.appendingPathComponent("data", isDirectory: true))
    let first = try TargetLibraryManager.placeTarget(
        profileID: "same-target",
        on: externalRoot,
        paths: paths,
        fileManager: fm
    )
    let second = try TargetLibraryManager.placeTarget(
        profileID: "same-target",
        on: externalRoot,
        paths: paths,
        fileManager: fm
    )

    #expect(first == second)
}
