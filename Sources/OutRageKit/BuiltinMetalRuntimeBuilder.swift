import Foundation

public enum BuiltinMetalRuntimeBuilder {
    public static func build(
        engineRoot: URL,
        backendRoot: URL,
        runtimeIdentifier: String,
        version: String,
        outputDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> RuntimePackageArtifacts {
        let stagingParent = fileManager.temporaryDirectory.appendingPathComponent(
            "outRage-runtime-build-" + UUID().uuidString,
            isDirectory: true
        )
        let runtimeRoot = stagingParent.appendingPathComponent(runtimeIdentifier, isDirectory: true)
        try fileManager.createDirectory(at: stagingParent, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingParent) }

        _ = try BuiltinMetalRuntimeComposer.compose(
            engineRoot: engineRoot,
            backendRoot: backendRoot,
            runtimeIdentifier: runtimeIdentifier,
            outputRoot: runtimeRoot,
            fileManager: fileManager
        )

        return try RuntimePackager.build(
            runtimeRoot: runtimeRoot,
            version: version,
            outputDirectory: outputDirectory,
            fileManager: fileManager
        )
    }
}
