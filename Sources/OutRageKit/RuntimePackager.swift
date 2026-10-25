import Foundation

public struct RuntimePackageArtifacts: Equatable, Sendable {
    public let archiveURL: URL
    public let manifestURL: URL
    public let manifest: RuntimePackageManifest

    public init(archiveURL: URL, manifestURL: URL, manifest: RuntimePackageManifest) {
        self.archiveURL = archiveURL
        self.manifestURL = manifestURL
        self.manifest = manifest
    }
}

public enum RuntimePackager {
    public static func build(
        runtimeRoot: URL,
        version: String,
        outputDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> RuntimePackageArtifacts {
        let descriptorURL = runtimeRoot.appendingPathComponent("runtime.json")
        let descriptor = try RuntimeDescriptorLoader.load(from: descriptorURL)
        let executable = runtimeRoot.appendingPathComponent(descriptor.executable)
        guard fileManager.isExecutableFile(atPath: executable.path) else {
            throw LaunchSessionError.runtimeExecutableMissing(executable.path)
        }

        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let safeVersion = version.replacingOccurrences(of: "/", with: "-")
        let archiveURL = outputDirectory.appendingPathComponent("\(descriptor.id)-\(safeVersion).zip")
        let manifestURL = outputDirectory.appendingPathComponent("\(descriptor.id)-\(safeVersion).manifest.json")

        if fileManager.fileExists(atPath: archiveURL.path) {
            try fileManager.removeItem(at: archiveURL)
        }
        if fileManager.fileExists(atPath: manifestURL.path) {
            try fileManager.removeItem(at: manifestURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent", runtimeRoot.path, archiveURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw RuntimePackageError.extractionFailed(process.terminationStatus)
        }

        let manifest = RuntimePackageManifest(
            runtimeIdentifier: descriptor.id,
            version: version,
            archiveSHA256: try FileDigest.sha256(of: archiveURL),
            rootSubdirectory: runtimeRoot.lastPathComponent
        )
        try manifest.validate()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)

        return RuntimePackageArtifacts(
            archiveURL: archiveURL,
            manifestURL: manifestURL,
            manifest: manifest
        )
    }
}
