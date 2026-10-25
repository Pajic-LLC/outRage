import Foundation
import Testing
@testable import OutRageKit

@Test func runtimeOverlayInstallsSelectedBackendFiles() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let runtimeRoot = root.appendingPathComponent("runtime", isDirectory: true)
    let targetRoot = root.appendingPathComponent("target", isDirectory: true)
    let prefixRoot = root.appendingPathComponent("prefix", isDirectory: true)
    let cacheRoot = root.appendingPathComponent("cache", isDirectory: true)
    for directory in [runtimeRoot, targetRoot, prefixRoot, cacheRoot] {
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    let backendDirectory = runtimeRoot.appendingPathComponent("backends/metal", isDirectory: true)
    try fm.createDirectory(at: backendDirectory, withIntermediateDirectories: true)
    let source = backendDirectory.appendingPathComponent("graphics.dll")
    try Data("graphics".utf8).write(to: source)

    let runtime = RuntimeDescriptor(
        id: "overlay-runtime",
        executable: "runtime",
        supportedCPUBackends: [.native],
        supportedGraphicsBackends: [.dxmt],
        graphicsConfigurations: [
            "dxmt": RuntimeBackendConfiguration(
                fileMappings: [
                    RuntimeFileMapping(
                        source: "backends/metal/graphics.dll",
                        destinationScope: .prefix,
                        destination: "drive_c/windows/system32/graphics.dll",
                        mode: .symlink
                    )
                ]
            )
        ]
    )
    let context = RuntimeLaunchContext(
        runtimeRoot: runtimeRoot,
        targetRoot: targetRoot,
        prefixRoot: prefixRoot,
        cacheRoot: cacheRoot
    )

    try RuntimeOverlayInstaller.apply(
        runtime: runtime,
        cpu: .native,
        graphics: .dxmt,
        context: context,
        fileManager: fm
    )

    let installed = prefixRoot.appendingPathComponent("drive_c/windows/system32/graphics.dll")
    let values = try installed.resourceValues(forKeys: [.isSymbolicLinkKey])
    #expect(values.isSymbolicLink == true)
    #expect(try Data(contentsOf: installed) == Data("graphics".utf8))
}

@Test func runtimeFileMappingRejectsTraversal() {
    let mapping = RuntimeFileMapping(
        source: "backend.dll",
        destinationScope: .target,
        destination: "../outside.dll"
    )

    #expect(throws: RuntimeDescriptorError.self) {
        try mapping.validate()
    }
}
