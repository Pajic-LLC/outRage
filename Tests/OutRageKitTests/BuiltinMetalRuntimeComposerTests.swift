import Foundation
import Testing
@testable import OutRageKit

@Test func builtinMetalRuntimeComposerBuildsRunnableLayout() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? fm.removeItem(at: root) }

    let engine = root.appendingPathComponent("engine", isDirectory: true)
    let engineBin = engine.appendingPathComponent("bin", isDirectory: true)
    try fm.createDirectory(at: engineBin, withIntermediateDirectories: true)
    let wine = engineBin.appendingPathComponent("wine64")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: wine)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wine.path)

    let backend = root.appendingPathComponent("backend/artifacts/x86_64", isDirectory: true)
    try fm.createDirectory(at: backend, withIntermediateDirectories: true)
    for name in ["winemetal.so", "winemetal.dll", "d3d11.dll", "dxgi.dll", "d3d10core.dll"] {
        try Data(name.utf8).write(to: backend.appendingPathComponent(name))
    }

    let output = root.appendingPathComponent("composed", isDirectory: true)
    let composed = try BuiltinMetalRuntimeComposer.compose(
        engineRoot: engine,
        backendRoot: root.appendingPathComponent("backend", isDirectory: true),
        runtimeIdentifier: "metal-runtime",
        outputRoot: output,
        fileManager: fm
    )

    #expect(composed.descriptor.executable == "bin/wine64")
    #expect(composed.descriptor.prefixInitializer?.executable == "bin/wine64")
    #expect(composed.descriptor.prefixInitializer?.arguments == ["wineboot", "--init"])
    #expect(composed.descriptor.supportedCPUBackends == [.rosetta])
    #expect(composed.descriptor.supportedGraphicsBackends == [.dxmt])
    #expect(composed.descriptor.configuration(for: CPUBackend.rosetta)?.environment?["ROSETTA_ADVERTISE_AVX"] == "1")
    #expect(composed.descriptor.environment["WINEPREFIX"] == "${PREFIX_ROOT}")
    #expect(composed.descriptor.environment["WINEDLLOVERRIDES"] == "mscoree,mshtml=")
    #expect(composed.descriptor.environment["DXMT_SHADER_CACHE_PATH"] == "${CACHE_ROOT}/dxmt-shaders")
    #expect(composed.descriptor.environment["OUTRAGE_TARGET_DRIVE"] == "O:")
    #expect(composed.descriptor.pathMappings == [
        RuntimePathMapping(
            sourceScope: .target,
            source: ".",
            destinationScope: .prefix,
            destination: "dosdevices/o:"
        )
    ])

    #expect(fm.fileExists(atPath: output.appendingPathComponent("lib/wine/x86_64-unix/winemetal.so").path))
    #expect(fm.fileExists(atPath: output.appendingPathComponent("lib/wine/x86_64-windows/d3d11.dll").path))
    #expect(fm.fileExists(atPath: output.appendingPathComponent("lib/wine/x86_64-windows/dxgi.dll").path))
    #expect(fm.fileExists(atPath: output.appendingPathComponent("runtime.json").path))
}
